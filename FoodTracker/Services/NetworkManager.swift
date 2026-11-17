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

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        self.session = URLSession(configuration: config)
    }

    private var currentLanguage: String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }

    private func parseDouble(_ value: Any?) -> Double {
        guard let value = value else { return 0.0 }
        if let d = value as? Double { return d }
        if let i = value as? Int { return Double(i) }
        if let s = value as? String {
            let cleanString = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
            return Double(cleanString) ?? 0.0
        }
        return 0.0
    }

    func searchFoodByText(query: String) async -> [FoodItem] {
        print("🔍 Ищем '\(query)' (Язык: \(currentLanguage))")

        var results = await searchFromOpenFoodFacts(query: query)
        print("🍏 В Open Food Facts найдено: \(results.count)")

        if results.count < 10 {
            print("⚠️ В OFF мало результатов. Подключаем FatSecret...")
            let fatSecretResults = await searchFromFatSecret(query: query)
            print("🍔 В FatSecret найдено: \(fatSecretResults.count)")

            for fsItem in fatSecretResults {
                if !results.contains(where: { $0.name.lowercased() == fsItem.name.lowercased() }) {
                    results.append(fsItem)
                }
            }
        }

        if results.isEmpty {
            print("⚠️ Оба API ничего не нашли. Подключаем ИИ-генерацию для '\(query)'...")
            TrackingManager.shared.track(.aiChefUsed(queryLength: query.count))
            if let aiFood = await AINutritionService.shared.generateFoodItem(for: query) {
                print("✨ ИИ сгенерировал продукт: \(aiFood.name)")
                results.append(aiFood)
            }
        }

        print("✅ Итого найдено: \(results.count) результатов.")
        return Array(results.prefix(20))
    }

    func fetchProduct(barcode: String) async -> FoodItem? {
        print("🔍 Ищем штрихкод \(barcode)...")
        if let offProduct = await fetchBarcodeFromOFF(barcode: barcode) {
            print("✅ Нашли в Open Food Facts: \(offProduct.name)")
            return offProduct
        }

        if let fatSecretProduct = await fetchBarcodeFromFatSecretBarcode(barcode: barcode) {
            print("✅ Нашли в FatSecret: \(fatSecretProduct.name)")
            return fatSecretProduct
        }

        print("❌ Продукт по штрихкоду не найден.")
        return nil
    }

    private func searchFromOpenFoodFacts(query: String) async -> [FoodItem] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }

        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1&page_size=15"
        guard let url = URL(string: urlString) else { return [] }

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
                    items.append(FoodItem(name: name, weight: 100.0, calories: Int(cals), protein: protein, fats: fat, carbs: carbs))
                }
            }
            return items
        } catch { return [] }
    }

    private func fetchBarcodeFromOFF(barcode: String) async -> FoodItem? {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("FoodTrackerApp/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = json["status"] as? Int, status == 1,
                  let p = json["product"] as? [String: Any],
                  let name = p["product_name"] as? String ?? p["product_name_ru"] as? String ?? p["product_name_en"] as? String, !name.isEmpty else { return nil }

            let nuts = p["nutriments"] as? [String: Any] ?? [:]
            var cals = parseDouble(nuts["energy-kcal_100g"])
            if cals == 0 { cals = parseDouble(nuts["energy_100g"]) / 4.184 }

            let protein = parseDouble(nuts["proteins_100g"])
            let fat = parseDouble(nuts["fat_100g"])
            let carbs = parseDouble(nuts["carbohydrates_100g"])

            return FoodItem(name: name, weight: 100.0, calories: Int(cals), protein: protein, fats: fat, carbs: carbs)
        } catch { return nil }
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

    private func performSearchProxyRequest<T: Decodable>(payload: [String: Any], as type: T.Type) async -> T? {
        guard let appCheckToken = await appCheckTokenProvider(), !appCheckToken.isEmpty else {
            print("⚠️ foodSearchProxy skipped: missing App Check token")
            return nil
        }
        guard let authToken = await authTokenProvider(), !authToken.isEmpty else {
            print("⚠️ foodSearchProxy skipped: missing Firebase ID token")
            return nil
        }
        let url = await resolveSearchProxyURL()
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    private func searchFromFatSecret(query: String) async -> [FoodItem] {
        let payload: [String: Any] = ["mode": "search", "query": query, "maxResults": 15]
        let response = await performSearchProxyRequest(payload: payload, as: ProxySearchResponse.self)
        return response?.items.map { $0.toFoodItem() } ?? []
    }

    private func fetchBarcodeFromFatSecretBarcode(barcode: String) async -> FoodItem? {
        let payload: [String: Any] = ["mode": "barcode", "barcode": barcode]
        let response = await performSearchProxyRequest(payload: payload, as: ProxyBarcodeResponse.self)
        return response?.item?.toFoodItem()
    }
}
