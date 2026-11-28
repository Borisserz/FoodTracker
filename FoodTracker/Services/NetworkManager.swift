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
    var aiFallbackConsentProvider: (@MainActor () -> Bool)?
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
        let fiber: Double
        let sugar: Double
        let omega3: Double
        let calcium: Double
        let potassium: Double
        let magnesium: Double
        let iron: Double
        let vitaminC: Double
        let vitaminD: Double

        init(from item: FoodItem) {
            self.name = item.name
            self.weight = item.weight
            self.calories = item.calories
            self.protein = item.protein
            self.fats = item.fats
            self.carbs = item.carbs
            self.fiber = item.fiber
            self.sugar = item.sugar
            self.omega3 = item.omega3
            self.calcium = item.calcium
            self.potassium = item.potassium
            self.magnesium = item.magnesium
            self.iron = item.iron
            self.vitaminC = item.vitaminC
            self.vitaminD = item.vitaminD
        }

        func toFoodItem() -> FoodItem {
            FoodItem(
                name: name,
                weight: weight,
                calories: calories,
                protein: protein,
                fats: fats,
                carbs: carbs,
                fiber: fiber,
                sugar: sugar,
                omega3: omega3,
                calcium: calcium,
                potassium: potassium,
                magnesium: magnesium,
                iron: iron,
                vitaminC: vitaminC,
                vitaminD: vitaminD
            )
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

    private func parseOptionalDouble(_ value: Any?) -> Double? {
        guard let value = value else { return nil }
        if let d = value as? Double {
            return (d.isFinite && d >= 0) ? d : nil
        }
        if let i = value as? Int {
            return i >= 0 ? Double(i) : nil
        }
        if let s = value as? String {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
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
        return nil
    }

    private func parseDouble(_ value: Any?) -> Double {
        parseOptionalDouble(value) ?? 0.0
    }

    private func parseServingWeight(_ value: Any?) -> Double {
        let direct = parseDouble(value)
        if direct > 0 { return direct }
        guard let str = value as? String else { return 0.0 }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)

        // Prefer explicit parenthetical metric/oz weight like "1 oz (28 g)" or "1 bottle (1 L)" first.
        if let grams = Self.extractWeight(from: trimmed, pattern: #"\(\s*([0-9]+(?:[.,][0-9]+)?)\s*(fl\s+oz|oz|kg|кг|g|gram|grams|gr|ml|liters|liter|l|г|мл|л)\b"#) {
            return grams
        }
        // Otherwise require an explicit weight/volume unit so leading serving counts ("1 bar") don't parse as 1g.
        return Self.extractWeight(from: trimmed, pattern: #"^([0-9]+(?:[.,][0-9]+)?)\s*(fl\s+oz|oz|kg|кг|g|gram|grams|gr|ml|liters|liter|l|г|мл|л)\b"#) ?? 0.0
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
        if unit == "kg" || unit == "кг" || unit == "l" || unit == "liter" || unit == "liters" || unit == "л" {
            return (raw * 1000.0 * 10.0).rounded() / 10.0
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

        #if DEBUG
        print("🔍 Ищем '\(normalizedQuery)' (Язык: \(currentLanguage))")
        #endif

        var results = await searchFromOpenFoodFacts(query: normalizedQuery)
        #if DEBUG
        print("🍏 В Open Food Facts найдено: \(results.count)")
        #endif

        var fatSecretFailed = false
        if results.count < 10 {
            #if DEBUG
            print("⚠️ В OFF мало результатов. Подключаем FatSecret...")
            #endif
            let outcome = await searchFromFatSecretOutcome(query: normalizedQuery)
            let fatSecretResults = outcome.items
            fatSecretFailed = outcome.failed
            #if DEBUG
            print("🍔 В FatSecret найдено: \(fatSecretResults.count)")
            #endif

            for fsItem in fatSecretResults {
                if !results.contains(where: { $0.name.lowercased() == fsItem.name.lowercased() }) {
                    results.append(fsItem)
                }
            }
        }

        let aiFallbackAllowed = await MainActor.run {
            aiFallbackConsentProvider?() ?? AIPhotoConsentManager.shared.hasConsented
        }
        var usedAIFallback = false
        if results.isEmpty && allowAIFallback && aiFallbackAllowed {
            #if DEBUG
            print("⚠️ Оба API ничего не нашли. Подключаем ИИ-генерацию для '\(normalizedQuery)'...")
            #endif
            TrackingManager.shared.track(.aiChefUsed(queryLength: normalizedQuery.count))
            if let aiFood = await AINutritionService.shared.generateFoodItem(for: normalizedQuery) {
                #if DEBUG
                print("✨ ИИ сгенерировал продукт: \(aiFood.name)")
                #endif
                results.append(aiFood)
                usedAIFallback = true
            }
        }

        let capped = Array(results.prefix(20))
        if !capped.isEmpty && (!fatSecretFailed || usedAIFallback) {
            let snapshots = capped.map { CachedFoodSnapshot(from: $0) }
            let now = Date()
            let expiry = now.addingTimeInterval(searchCacheTTL)
            cacheLock.withLock {
                pruneCache(&searchCache, now: now)
                searchCache[cacheKey] = CacheEntry(value: snapshots, expiresAt: expiry)
            }
        }
        #if DEBUG
        print("✅ Итого найдено: \(capped.count) результатов.")
        #endif
        return capped
    }

    enum BarcodeFetchOutcome {
        case found(FoodItem)
        case notFound
        case failed(String)
    }

    private static let validBarcodeCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
    )

    static func isValidBarcode(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...32).contains(trimmed.count) else { return false }
        return trimmed.unicodeScalars.allSatisfy { validBarcodeCharacters.contains($0) }
    }

    func fetchProduct(barcode: String) async -> FoodItem? {
        guard Self.isValidBarcode(barcode) else { return nil }
        switch await fetchProductOutcome(barcode: barcode) {
        case .found(let item):
            return item
        case .notFound, .failed:
            return nil
        }
    }

    static func normalizedBarcode(for raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 8, trimmed.allSatisfy(\.isNumber),
              let first = trimmed.first, (first == "0" || first == "1") else {
            return trimmed
        }
        if first == "1", isValidEAN8(trimmed) {
            return trimmed
        }
        return expandUPCEtoUPCA(trimmed) ?? trimmed
    }

    private static func isValidEAN8(_ digits: String) -> Bool {
        let vals = digits.compactMap(\.wholeNumberValue)
        guard vals.count == 8 else { return false }
        let sum = vals[0] * 3 + vals[1] + vals[2] * 3 + vals[3] + vals[4] * 3 + vals[5] + vals[6] * 3
        let check = (10 - (sum % 10)) % 10
        return check == vals[7]
    }

    private static func isValidUPCACheckDigit(_ upca: String) -> Bool {
        let vals = upca.compactMap(\.wholeNumberValue)
        guard vals.count == 12 else { return false }
        var oddSum = 0
        var evenSum = 0
        for i in 0..<11 {
            if i % 2 == 0 { oddSum += vals[i] } else { evenSum += vals[i] }
        }
        let check = (10 - ((oddSum * 3 + evenSum) % 10)) % 10
        return check == vals[11]
    }

    private static func expandUPCEtoUPCA(_ upce: String) -> String? {
        let c = Array(upce)
        guard c.count == 8, c.allSatisfy(\.isNumber), (c[0] == "0" || c[0] == "1") else { return nil }
        let n = String(c[0])
        let d1 = String(c[1]), d2 = String(c[2]), d3 = String(c[3]), d4 = String(c[4]), d5 = String(c[5]), d6 = c[6], check = String(c[7])
        let expanded: String
        switch d6 {
        case "0", "1", "2":
            expanded = "\(n)\(d1)\(d2)\(d6)0000\(d3)\(d4)\(d5)\(check)"
        case "3":
            expanded = "\(n)\(d1)\(d2)\(d3)00000\(d4)\(d5)\(check)"
        case "4":
            expanded = "\(n)\(d1)\(d2)\(d3)\(d4)00000\(d5)\(check)"
        default:
            expanded = "\(n)\(d1)\(d2)\(d3)\(d4)\(d5)0000\(d6)\(check)"
        }
        guard isValidUPCACheckDigit(expanded) else { return nil }
        return expanded
    }

    func fetchProductOutcome(barcode: String) async -> BarcodeFetchOutcome {
        setLastBarcodeLookupError(nil)
        let cacheKey = Self.normalizedBarcode(for: barcode)
        guard Self.isValidBarcode(cacheKey) else { return .notFound }

        if let cached = cacheLock.withLock({ () -> FoodItem? in
            guard let entry = barcodeCache[cacheKey], entry.expiresAt > Date() else {
                barcodeCache.removeValue(forKey: cacheKey)
                return nil
            }
            return entry.value.toFoodItem()
        }) {
            return .found(cached)
        }

        #if DEBUG
        print("🔍 Ищем штрихкод \(cacheKey)...")
        #endif
        var failureMessage: String?

        switch await fetchBarcodeFromOFF(barcode: cacheKey) {
        case .found(let offProduct):
            #if DEBUG
            print("✅ Нашли в Open Food Facts: \(offProduct.name)")
            #endif
            let snapshot = CachedFoodSnapshot(from: offProduct)
            let now = Date()
            let expiry = now.addingTimeInterval(barcodeCacheTTL)
            cacheLock.withLock {
                pruneCache(&barcodeCache, now: now)
                barcodeCache[cacheKey] = CacheEntry(value: snapshot, expiresAt: expiry)
            }
            return .found(offProduct)
        case .notFound:
            break
        case .failed(let message):
            failureMessage = message
            setLastBarcodeLookupError(message)
        }

        switch await fetchBarcodeFromFatSecretBarcode(barcode: cacheKey) {
        case .found(let fatSecretProduct):
            #if DEBUG
            print("✅ Нашли в FatSecret: \(fatSecretProduct.name)")
            #endif
            setLastBarcodeLookupError(nil)
            let snapshot = CachedFoodSnapshot(from: fatSecretProduct)
            let now = Date()
            let expiry = now.addingTimeInterval(barcodeCacheTTL)
            cacheLock.withLock {
                pruneCache(&barcodeCache, now: now)
                barcodeCache[cacheKey] = CacheEntry(value: snapshot, expiresAt: expiry)
            }
            return .found(fatSecretProduct)
        case .notFound:
            if let failureMessage {
                setLastBarcodeLookupError(failureMessage)
                return .failed(failureMessage)
            }
            setLastBarcodeLookupError(nil)
        case .failed(let message):
            if let failureMessage {
                setLastBarcodeLookupError(failureMessage)
                return .failed(failureMessage)
            }
            // OpenFoodFacts already succeeded with .notFound; do not mask it with a secondary FatSecret proxy error.
            setLastBarcodeLookupError(nil)
            return .notFound
        }

        #if DEBUG
        print("❌ Продукт по штрихкоду не найден.")
        #endif
        return .notFound
    }

    private func extractOpenFoodFactsProductName(from product: [String: Any]) -> String? {
        let lang = Locale.current.language.languageCode?.identifier.lowercased() ?? "en"
        let candidateKeys = [
            "product_name",
            "product_name_\(lang)",
            "product_name_en",
            "product_name_ru",
            "product_name_de",
            "product_name_es",
            "product_name_fr",
            "product_name_it",
            "product_name_pt",
            "generic_name"
        ]
        for key in candidateKeys {
            if let raw = product[key] as? String {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func isPercentOFFUnit(_ rawUnit: Any?) -> Bool {
        guard let unit = (rawUnit as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return false
        }
        return unit.contains("%")
    }

    private func extractOFFMicronutrientMg(
        from nuts: [String: Any],
        baseKey: String,
        suffix: String
    ) -> Double? {
        guard !Self.isPercentOFFUnit(nuts["\(baseKey)_unit"]),
              let raw = parseOptionalDouble(nuts["\(baseKey)_\(suffix)"]),
              raw >= 0 else { return nil }
        // OpenFoodFacts `*_100g` and `*_serving` keys are always normalized to grams regardless of label `*_unit`.
        return raw * 1000.0
    }

    private func extractOFFMicronutrientMcg(
        from nuts: [String: Any],
        baseKey: String,
        suffix: String
    ) -> Double? {
        guard !Self.isPercentOFFUnit(nuts["\(baseKey)_unit"]),
              let raw = parseOptionalDouble(nuts["\(baseKey)_\(suffix)"]),
              raw >= 0 else { return nil }
        // OpenFoodFacts `*_100g` and `*_serving` keys are always normalized to grams regardless of label `*_unit`.
        return raw * 1_000_000.0
    }

    private func extractOFFGramField(
        from nuts: [String: Any],
        baseKey: String,
        suffix: String
    ) -> Double {
        guard !Self.isPercentOFFUnit(nuts["\(baseKey)_unit"]),
              let raw = parseOptionalDouble(nuts["\(baseKey)_\(suffix)"]),
              raw >= 0 else { return 0 }
        return raw
    }

    private func extractOFFOmega3Grams(
        from nuts: [String: Any],
        suffix: String
    ) -> Double? {
        guard !Self.isPercentOFFUnit(nuts["omega-3-fat_unit"]),
              let raw = parseOptionalDouble(nuts["omega-3-fat_\(suffix)"]),
              raw >= 0 else { return nil }
        return raw
    }

    private func resolvedServingWeight(from product: [String: Any]) -> Double? {
        let qty = parseServingWeight(product["serving_quantity"])
        if qty > 0 { return qty }
        let sizeQty = parseServingWeight(product["serving_size"])
        return sizeQty > 0 ? sizeQty : nil
    }

    private func extractOpenFoodFactsItem(from product: [String: Any]) -> FoodItem? {
        guard let name = extractOpenFoodFactsProductName(from: product) else { return nil }
        let nuts = product["nutriments"] as? [String: Any] ?? [:]
        let energyUnit = (nuts["energy_unit"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        let energyIsKcal = energyUnit == "kcal"

        let kcal100 = parseOptionalDouble(nuts["energy-kcal_100g"])
        let rawEnergy100 = parseOptionalDouble(nuts["energy_100g"])
        let cals100 = kcal100 ?? rawEnergy100.map { energyIsKcal ? $0 : ($0 / 4.184) }
        let protein100 = parseOptionalDouble(nuts["proteins_100g"])
        let fat100 = parseOptionalDouble(nuts["fat_100g"])
        let carbs100 = parseOptionalDouble(nuts["carbohydrates_100g"])

        let kcalServing = parseOptionalDouble(nuts["energy-kcal_serving"])
        let rawEnergyServing = parseOptionalDouble(nuts["energy_serving"])
        let calsServing = kcalServing ?? rawEnergyServing.map { energyIsKcal ? $0 : ($0 / 4.184) }
        let proteinServing = parseOptionalDouble(nuts["proteins_serving"])
        let fatServing = parseOptionalDouble(nuts["fat_serving"])
        let carbsServing = parseOptionalDouble(nuts["carbohydrates_serving"])

        let hasAny100gField = cals100 != nil || protein100 != nil || fat100 != nil || carbs100 != nil
        let hasAnyServingField = calsServing != nil || proteinServing != nil || fatServing != nil || carbsServing != nil
        guard hasAny100gField || hasAnyServingField else {
            return nil
        }

        let hasPositive100g = (cals100 ?? 0) > 0 || (protein100 ?? 0) > 0 || (fat100 ?? 0) > 0 || (carbs100 ?? 0) > 0
        let missing100gCalories = (cals100 ?? 0) <= 0
        let hasPositiveServingCalories = (calsServing ?? 0) > 0
        let hasPositiveServing = hasPositiveServingCalories || (proteinServing ?? 0) > 0 || (fatServing ?? 0) > 0 || (carbsServing ?? 0) > 0

        let useServing = (!hasPositive100g && hasPositiveServing)
            || (missing100gCalories && hasPositiveServingCalories)
            || (!hasAny100gField && hasAnyServingField)

        let cals: Double
        let protein: Double
        let fat: Double
        let carbs: Double
        let weight: Double
        let microSuffix: String

        if useServing {
            cals = calsServing ?? 0
            protein = proteinServing ?? 0
            fat = fatServing ?? 0
            carbs = carbsServing ?? 0
            weight = resolvedServingWeight(from: product) ?? 0.0
            microSuffix = "serving"
        } else {
            cals = cals100 ?? 0
            protein = protein100 ?? 0
            fat = fat100 ?? 0
            carbs = carbs100 ?? 0
            weight = 100.0
            microSuffix = "100g"
        }

        let fiber = extractOFFGramField(from: nuts, baseKey: "fiber", suffix: microSuffix)
        let sugar = extractOFFGramField(from: nuts, baseKey: "sugars", suffix: microSuffix)
        let omega3 = extractOFFOmega3Grams(from: nuts, suffix: microSuffix)
        let calcium = extractOFFMicronutrientMg(from: nuts, baseKey: "calcium", suffix: microSuffix)
        let potassium = extractOFFMicronutrientMg(from: nuts, baseKey: "potassium", suffix: microSuffix)
        let magnesium = extractOFFMicronutrientMg(from: nuts, baseKey: "magnesium", suffix: microSuffix)
        let iron = extractOFFMicronutrientMg(from: nuts, baseKey: "iron", suffix: microSuffix)
        let vitaminC = extractOFFMicronutrientMg(from: nuts, baseKey: "vitamin-c", suffix: microSuffix)
        let vitaminD = extractOFFMicronutrientMcg(from: nuts, baseKey: "vitamin-d", suffix: microSuffix)

        let roundedCals = max(0, Int(cals.rounded()))
        let safeProtein = max(0, protein)
        let safeFat = max(0, fat)
        let safeCarbs = max(0, carbs)

        let fallbackMicros = MicronutrientEstimator.estimate(
            name: name,
            calories: roundedCals,
            protein: safeProtein,
            fat: safeFat,
            carbs: safeCarbs,
            weight: weight > 0 ? weight : 100.0
        )
        let resolvedMicros = MicronutrientProfile.resolvingOmitted(
            omega3: omega3,
            calcium: calcium,
            potassium: potassium,
            magnesium: magnesium,
            iron: iron,
            vitaminC: vitaminC,
            vitaminD: vitaminD,
            fallback: fallbackMicros
        )

        return FoodItem(
            name: name,
            weight: weight,
            calories: roundedCals,
            protein: safeProtein,
            fats: safeFat,
            carbs: safeCarbs,
            fiber: fiber,
            sugar: sugar,
            omega3: resolvedMicros.omega3,
            calcium: resolvedMicros.calcium,
            potassium: resolvedMicros.potassium,
            magnesium: resolvedMicros.magnesium,
            iron: resolvedMicros.iron,
            vitaminC: resolvedMicros.vitaminC,
            vitaminD: resolvedMicros.vitaminD
        )
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

            return products.compactMap { extractOpenFoodFactsItem(from: $0) }
        } catch { return [] }
    }

    private enum BarcodeLookupOutcome {
        case found(FoodItem)
        case notFound
        case failed(String)
    }

    private func fetchBarcodeFromOFF(barcode: String) async -> BarcodeLookupOutcome {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidBarcode(trimmed),
              let encodedBarcode = trimmed.addingPercentEncoding(withAllowedCharacters: Self.validBarcodeCharacters) else {
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
                  let item = extractOpenFoodFactsItem(from: p) else {
                return .notFound
            }

            return .found(item)
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
        let omega3: Double?
        let calcium: Double?
        let potassium: Double?
        let magnesium: Double?
        let iron: Double?
        let vitaminC: Double?
        let vitaminD: Double?

        func toFoodItem() -> FoodItem {
            let safeCalories = max(0, calories)
            let safeProtein = max(0, protein)
            let safeFats = max(0, fats)
            let safeCarbs = max(0, carbs)
            let fallback = MicronutrientEstimator.estimate(
                name: name,
                calories: safeCalories,
                protein: safeProtein,
                fat: safeFats,
                carbs: safeCarbs,
                weight: weight > 0 ? weight : 100.0
            )
            let resolved = MicronutrientProfile.resolvingOmitted(
                omega3: omega3.map { max(0, $0) },
                calcium: calcium.map { max(0, $0) },
                potassium: potassium.map { max(0, $0) },
                magnesium: magnesium.map { max(0, $0) },
                iron: iron.map { max(0, $0) },
                vitaminC: vitaminC.map { max(0, $0) },
                vitaminD: vitaminD.map { max(0, $0) },
                fallback: fallback
            )

            return FoodItem(
                name: name,
                weight: weight,
                calories: safeCalories,
                protein: safeProtein,
                fats: safeFats,
                carbs: safeCarbs,
                omega3: resolved.omega3,
                calcium: resolved.calcium,
                potassium: resolved.potassium,
                magnesium: resolved.magnesium,
                iron: resolved.iron,
                vitaminC: resolved.vitaminC,
                vitaminD: resolved.vitaminD
            )
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
        var freshAuth: String?
        if let currentUser {
            do {
                freshAuth = try await currentUser.getIDTokenResult(forcingRefresh: true).token
            } catch {
                if AuthManager.isPermanentTokenInvalidationError(error) {
                    let wasAnonymous = currentUser.isAnonymous
                    try? Auth.auth().signOut()
                    if wasAnonymous, let newAnon = try? await AnonymousAuthBootstrap.shared.ensureSignedIn() {
                        freshAuth = try? await newAnon.getIDTokenResult(forcingRefresh: false).token
                    }
                }
            }
        }
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
                #if DEBUG
                print("⚠️ foodSearchProxy skipped: missing App Check token")
                #endif
                return .failed(String(localized: "Unable to verify app security token. Please try again."))
            }
            guard let authToken = tokens.authToken, !authToken.isEmpty else {
                if !forceRefresh { continue }
                #if DEBUG
                print("⚠️ foodSearchProxy skipped: missing Firebase ID token")
                #endif
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
                    let retryAfter = GeminiProxyClient.extractRetryAfter(httpResponse: http, data: data)
                    return .failed(AIResponseParsing.rateLimitMessage(retryAfter: retryAfter))
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
