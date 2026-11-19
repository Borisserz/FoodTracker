import Foundation
import FirebaseAuth
import FirebaseAppCheck

class NetworkManager {
    static let shared = NetworkManager()

    var session: URLSession
    var appCheckTokenProvider: () async -> String? = {
        try? await AppCheck.appCheck().token(forcingRefresh: false).token
    }
    var authTokenProvider: () async -> String? = {
        let user: FirebaseAuth.User?
        if let current = Auth.auth().currentUser {
            user = current
        } else {
            user = try? await AnonymousAuthBootstrap.shared.ensureSignedIn()
        }
        return try? await user?.getIDToken()
    }
    var searchProxyURLProvider: (() async -> URL)?
    var refreshingProxyTokensProvider: ((_ forceRefresh: Bool) async -> (authToken: String?, appCheckToken: String?))?
    private var _lastBarcodeLookupError: String?
    var lastBarcodeLookupError: String? {
        cacheLock.withLock { _lastBarcodeLookupError }
    }

    private func setLastBarcodeLookupError(_ value: String?) {
        cacheLock.withLock { _lastBarcodeLookupError = value }
    }

    private struct CachedFoodSnapshot: Sendable {
        let name: String
        let weight: Double
        let calories: Int
        let protein: Double
        let fats: Double
        let carbs: Double

        init(from item: FoodItem) {
            self.name = item.name
            self.weight = item.weight
            self.calories = item.calories
            self.protein = item.protein
            self.fats = item.fats
            self.carbs = item.carbs
        }

        func toFoodItem() -> FoodItem {
            FoodItem(name: name, weight: weight, calories: calories, protein: protein, fats: fats, carbs: carbs)
        }
    }

    private struct CacheEntry<Value> {
        let value: Value
        let expiresAt: Date
    }

    private let cacheLock = NSLock()
    private var searchCache: [String: CacheEntry<[CachedFoodSnapshot]>] = [:]
    private var barcodeCache: [String: CacheEntry<CachedFoodSnapshot>] = [:]
    private let searchCacheTTL: TimeInterval = 300
    private let barcodeCacheTTL: TimeInterval = 1800
    private let maxCacheEntries = 100

    static func searchCacheKey(query: String, language: String, allowAIFallback: Bool) -> String {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lang = language.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(lang)|\(allowAIFallback ? "ai" : "noai")|\(normalized)"
    }

    private func pruneCache<Value>(_ cache: inout [String: CacheEntry<Value>], now: Date) {
        cache = cache.filter { $0.value.expiresAt > now }
        if cache.count >= maxCacheEntries,
           let oldestKey = cache.min(by: { $0.value.expiresAt < $1.value.expiresAt })?.key {
            cache.removeValue(forKey: oldestKey)
        }
    }

    func clearCacheForTesting() {
        cacheLock.withLock {
            searchCache.removeAll()
            barcodeCache.removeAll()
        }
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 25.0
        config.timeoutIntervalForResource = 35.0
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    private var currentLanguage: String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }

    private func parseDouble(_ value: Any?) -> Double {
        guard let value = value else { return 0.0 }
        if let d = value as? Double {
            return (d.isFinite && d >= 0) ? d : 0.0
        }
        if let i = value as? Int {
            return i >= 0 ? Double(i) : 0.0
        }
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return 0.0 }
            let cleanString: String
            if trimmed.range(of: #"^\d{1,3}(,\d{3})+(\.\d+)?$"#, options: .regularExpression) != nil {
                cleanString = trimmed.replacingOccurrences(of: ",", with: "")
            } else {
                cleanString = trimmed.replacingOccurrences(of: ",", with: ".")
            }
            if let parsed = Double(cleanString), parsed.isFinite, parsed >= 0 {
                return parsed
            }
        }
        return 0.0
    }

    private func parseServingWeight(_ value: Any?) -> Double {
        let direct = parseDouble(value)
        if direct > 0 { return direct }
        guard let str = value as? String else { return 0.0 }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)

        // Prefer explicit parenthetical metric/oz weight like "1 oz (28 g)" or "2 tbsp (30g)" first.
        if let grams = Self.extractWeight(from: trimmed, pattern: #"\(\s*([0-9]+(?:[.,][0-9]+)?)\s*(fl\s+oz|oz|g|gram|grams|gr|ml|г|мл)\b"#) {
            return grams
        }
        // Otherwise require an explicit weight/volume unit so leading serving counts ("1 bar") don't parse as 1g.
        return Self.extractWeight(from: trimmed, pattern: #"^([0-9]+(?:[.,][0-9]+)?)\s*(fl\s+oz|oz|g|gram|grams|gr|ml|г|мл)\b"#) ?? 0.0
    }

    private static func extractWeight(from text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let numRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text) else {
            return nil
        }
        let numStr = String(text[numRange]).replacingOccurrences(of: ",", with: ".")
        guard let raw = Double(numStr), raw.isFinite, raw > 0 else { return nil }
        let unit = String(text[unitRange]).lowercased().replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if unit == "fl oz" {
            return (raw * 29.5735 * 10.0).rounded() / 10.0
        }
        if unit == "oz" {
            return (raw * 28.3495 * 10.0).rounded() / 10.0
        }
        return raw
    }

    func searchFoodByText(query: String, allowAIFallback: Bool = true) async -> [FoodItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }
        let cacheKey = Self.searchCacheKey(
            query: normalizedQuery,
            language: currentLanguage,
            allowAIFallback: allowAIFallback
        )
        if let cached = cacheLock.withLock({ () -> [FoodItem]? in
            guard let entry = searchCache[cacheKey], entry.expiresAt > Date() else {
                searchCache.removeValue(forKey: cacheKey)
                return nil
            }
            return entry.value.map { $0.toFoodItem() }
        }) {
            return cached
        }

        print("🔍 Ищем '\(query)' (Язык: \(currentLanguage))")

        var results = await searchFromOpenFoodFacts(query: query)
        print("🍏 В Open Food Facts найдено: \(results.count)")

        var fatSecretFailed = false
        if results.count < 10 {
            print("⚠️ В OFF мало результатов. Подключаем FatSecret...")
            let outcome = await searchFromFatSecretOutcome(query: query)
            let fatSecretResults = outcome.items
            fatSecretFailed = outcome.failed
            print("🍔 В FatSecret найдено: \(fatSecretResults.count)")

            for fsItem in fatSecretResults {
                if !results.contains(where: { $0.name.lowercased() == fsItem.name.lowercased() }) {
                    results.append(fsItem)
                }
            }
        }

        if results.isEmpty && allowAIFallback {
            print("⚠️ Оба API ничего не нашли. Подключаем ИИ-генерацию для '\(query)'...")
            TrackingManager.shared.track(.aiChefUsed(queryLength: query.count))
            if let aiFood = await AINutritionService.shared.generateFoodItem(for: query) {
                print("✨ ИИ сгенерировал продукт: \(aiFood.name)")
                results.append(aiFood)
            }
        }

        let capped = Array(results.prefix(20))
        if !capped.isEmpty && !fatSecretFailed {
            let snapshots = capped.map { CachedFoodSnapshot(from: $0) }
            let now = Date()
            let expiry = now.addingTimeInterval(searchCacheTTL)
            cacheLock.withLock {
                pruneCache(&searchCache, now: now)
                searchCache[cacheKey] = CacheEntry(value: snapshots, expiresAt: expiry)
            }
        }
        print("✅ Итого найдено: \(capped.count) результатов.")
        return capped
    }

    func fetchProduct(barcode: String) async -> FoodItem? {
        setLastBarcodeLookupError(nil)
        let cacheKey = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cacheKey.isEmpty,
           let cached = cacheLock.withLock({ () -> FoodItem? in
               guard let entry = barcodeCache[cacheKey], entry.expiresAt > Date() else {
                   barcodeCache.removeValue(forKey: cacheKey)
                   return nil
               }
               return entry.value.toFoodItem()
           }) {
            return cached
        }

        print("🔍 Ищем штрихкод \(barcode)...")
        var hadNetworkFailure = false

        switch await fetchBarcodeFromOFF(barcode: barcode) {
        case .found(let offProduct):
            print("✅ Нашли в Open Food Facts: \(offProduct.name)")
            if !cacheKey.isEmpty {
                let snapshot = CachedFoodSnapshot(from: offProduct)
                let now = Date()
                let expiry = now.addingTimeInterval(barcodeCacheTTL)
                cacheLock.withLock {
                    pruneCache(&barcodeCache, now: now)
                    barcodeCache[cacheKey] = CacheEntry(value: snapshot, expiresAt: expiry)
                }
            }
            return offProduct
        case .notFound:
            break
        case .failed(let message):
            hadNetworkFailure = true
            setLastBarcodeLookupError(message)
        }

        switch await fetchBarcodeFromFatSecretBarcode(barcode: barcode) {
        case .found(let fatSecretProduct):
            print("✅ Нашли в FatSecret: \(fatSecretProduct.name)")
            setLastBarcodeLookupError(nil)
            if !cacheKey.isEmpty {
                let snapshot = CachedFoodSnapshot(from: fatSecretProduct)
                let now = Date()
                let expiry = now.addingTimeInterval(barcodeCacheTTL)
                cacheLock.withLock {
                    pruneCache(&barcodeCache, now: now)
                    barcodeCache[cacheKey] = CacheEntry(value: snapshot, expiresAt: expiry)
                }
            }
            return fatSecretProduct
        case .notFound:
            if !hadNetworkFailure {
                setLastBarcodeLookupError(nil)
            }
        case .failed(let message):
            setLastBarcodeLookupError(message)
        }

        print("❌ Продукт по штрихкоду не найден.")
        return nil
    }

    private func searchFromOpenFoodFacts(query: String) async -> [FoodItem] {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "15")
        ]
        guard let url = components?.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("FoodTrackerApp - iOS - Version 1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let products = json["products"] as? [[String: Any]] else { return [] }

            var items: [FoodItem] = []
            for p in products {
                guard let name = p["product_name"] as? String ?? p["product_name_ru"] as? String ?? p["product_name_en"] as? String, !name.isEmpty else { continue }

                let nuts = p["nutriments"] as? [String: Any] ?? [:]

                var cals = parseDouble(nuts["energy-kcal_100g"])
                if cals == 0 { cals = parseDouble(nuts["energy_100g"]) / 4.184 }

                let protein = parseDouble(nuts["proteins_100g"])
                let fat = parseDouble(nuts["fat_100g"])
                let carbs = parseDouble(nuts["carbohydrates_100g"])

                if cals > 0 || protein > 0 || fat > 0 || carbs > 0 {
                    items.append(FoodItem(name: name, weight: 100.0, calories: Int(cals.rounded()), protein: protein, fats: fat, carbs: carbs))
                }
            }
            return items
        } catch { return [] }
    }

    private enum BarcodeLookupOutcome {
        case found(FoodItem)
        case notFound
        case failed(String)
    }

    private func fetchBarcodeFromOFF(barcode: String) async -> BarcodeLookupOutcome {
        guard let encodedBarcode = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return .notFound
        }
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(encodedBarcode).json"
        guard let url = URL(string: urlString) else { return .notFound }

        var request = URLRequest(url: url)
        request.setValue("FoodTrackerApp/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failed(String(localized: "Network error while checking barcode database."))
            }
            if http.statusCode == 404 {
                return .notFound
            }
            guard http.statusCode == 200 else {
                return .failed(String(localized: "Barcode database temporarily unavailable (HTTP \(http.statusCode))."))
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Int, status == 1,
                  let p = json["product"] as? [String: Any],
                  let name = p["product_name"] as? String ?? p["product_name_ru"] as? String ?? p["product_name_en"] as? String, !name.isEmpty else {
                return .notFound
            }

            let nuts = p["nutriments"] as? [String: Any] ?? [:]
            var cals = parseDouble(nuts["energy-kcal_100g"])
            if cals == 0 { cals = parseDouble(nuts["energy_100g"]) / 4.184 }
            var protein = parseDouble(nuts["proteins_100g"])
            var fat = parseDouble(nuts["fat_100g"])
            var carbs = parseDouble(nuts["carbohydrates_100g"])
            var weight = 100.0

            // US UPC entries on Open Food Facts often populate *_serving without *_100g.
            if cals <= 0 && protein <= 0 && fat <= 0 && carbs <= 0 {
                var servingCals = parseDouble(nuts["energy-kcal_serving"])
                if servingCals == 0 { servingCals = parseDouble(nuts["energy_serving"]) / 4.184 }
                let servingProtein = parseDouble(nuts["proteins_serving"])
                let servingFat = parseDouble(nuts["fat_serving"])
                let servingCarbs = parseDouble(nuts["carbohydrates_serving"])
                if servingCals > 0 || servingProtein > 0 || servingFat > 0 || servingCarbs > 0 {
                    cals = servingCals
                    protein = servingProtein
                    fat = servingFat
                    carbs = servingCarbs
                    let qty = parseServingWeight(p["serving_quantity"])
                    if qty > 0 {
                        weight = qty
                    } else {
                        let sizeQty = parseServingWeight(p["serving_size"])
                        if sizeQty > 0 { weight = sizeQty }
                    }
                } else {
                    // Do not return an all-zero product before FatSecret gets a chance.
                    return .notFound
                }
            }

            return .found(FoodItem(name: name, weight: weight, calories: Int(cals.rounded()), protein: protein, fats: fat, carbs: carbs))
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Server-Proxied FatSecret (secrets live in Firebase Secret Manager)

    private struct ProxyFoodItemDTO: Decodable {
        let name: String
        let weight: Double
        let calories: Int
        let protein: Double
        let fats: Double
        let carbs: Double

        func toFoodItem() -> FoodItem {
            FoodItem(name: name, weight: weight, calories: calories, protein: protein, fats: fats, carbs: carbs)
        }
    }

    private struct ProxySearchResponse: Decodable {
        let items: [ProxyFoodItemDTO]
    }

    private struct ProxyBarcodeResponse: Decodable {
        let item: ProxyFoodItemDTO?
    }

    private func resolveSearchProxyURL() async -> URL {
        if let provider = searchProxyURLProvider {
            return await provider()
        }
        let configured = await RemoteConfigManager.shared.getString(forKey: AIProxyEndpoint.searchRemoteConfigKey)
        return AIProxyEndpoint.resolve(configured: configured, fallback: AIProxyEndpoint.searchFallbackURL)
    }

    private func resolveProxyTokens(forceRefresh: Bool) async -> (authToken: String?, appCheckToken: String?) {
        if let provider = refreshingProxyTokensProvider {
            return await provider(forceRefresh)
        }
        if !forceRefresh {
            async let appCheck = appCheckTokenProvider()
            async let auth = authTokenProvider()
            return (await auth, await appCheck)
        }
        let freshAppCheck = try? await AppCheck.appCheck().token(forcingRefresh: true).token
        let currentUser: FirebaseAuth.User?
        if let existing = Auth.auth().currentUser {
            currentUser = existing
        } else {
            currentUser = try? await AnonymousAuthBootstrap.shared.ensureSignedIn()
        }
        let freshAuth = try? await currentUser?.getIDTokenResult(forcingRefresh: true).token
        return (freshAuth, freshAppCheck)
    }

    private enum ProxyRequestResult<T: Decodable> {
        case success(T)
        case failed(String?)
    }

    private func performSearchProxyRequest<T: Decodable>(payload: [String: Any], as type: T.Type) async -> ProxyRequestResult<T> {
        let url = await resolveSearchProxyURL()
        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            return .failed(nil)
        }

        for forceRefresh in [false, true] {
            let tokens = await resolveProxyTokens(forceRefresh: forceRefresh)
            guard let appCheckToken = tokens.appCheckToken, !appCheckToken.isEmpty else {
                if !forceRefresh { continue }
                print("⚠️ foodSearchProxy skipped: missing App Check token")
                return .failed(String(localized: "Unable to verify app security token. Please try again."))
            }
            guard let authToken = tokens.authToken, !authToken.isEmpty else {
                if !forceRefresh { continue }
                print("⚠️ foodSearchProxy skipped: missing Firebase ID token")
                return .failed(String(localized: "Unable to verify session. Please check your connection."))
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
            request.setValue(DeviceInstallIdentifier.current, forHTTPHeaderField: "X-Device-Install-ID")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    return .failed(String(localized: "Network error while checking barcode database."))
                }
                if http.statusCode == 401 && !forceRefresh {
                    continue
                }
                if http.statusCode == 429 {
                    return .failed(String(localized: "Search limit reached. Please try again shortly."))
                }
                guard http.statusCode == 200 else {
                    return .failed(String(localized: "Barcode database temporarily unavailable (HTTP \(http.statusCode))."))
                }
                let decoded = try JSONDecoder().decode(T.self, from: data)
                return .success(decoded)
            } catch {
                return .failed(error.localizedDescription)
            }
        }
        return .failed(String(localized: "Authorization expired. Please try again."))
    }

    private func searchFromFatSecretOutcome(query: String) async -> (items: [FoodItem], failed: Bool) {
        let payload: [String: Any] = ["mode": "search", "query": query, "maxResults": 15]
        switch await performSearchProxyRequest(payload: payload, as: ProxySearchResponse.self) {
        case .success(let response):
            return (response.items.map { $0.toFoodItem() }, false)
        case .failed:
            return ([], true)
        }
    }

    private func fetchBarcodeFromFatSecretBarcode(barcode: String) async -> BarcodeLookupOutcome {
        let payload: [String: Any] = ["mode": "barcode", "barcode": barcode]
        switch await performSearchProxyRequest(payload: payload, as: ProxyBarcodeResponse.self) {
        case .success(let response):
            if let item = response.item?.toFoodItem() {
                return .found(item)
            }
            return .notFound
        case .failed(let message):
            return .failed(message ?? String(localized: "Barcode lookup failed."))
        }
    }
}
