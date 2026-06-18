import Foundation
import SwiftData


class NetworkManager {
    static let shared = NetworkManager()
    
    // For testing purposes
    var session: URLSession = .shared
    
    private init() {}

    private var fatSecretAccessToken: String?

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

    func searchFoodByText(query: String, modelContext: ModelContext? = nil) async -> [FoodItem] {
        print("Log output removed for English localization")

        // ── Step 1: Local bundled JSON database (instant, zero network) ──────
        let localResults = LocalFoodDatabaseService.shared.search(query: query)
        print("Log output removed for English localization")

        // ── Step 2: User's previously scanned foods (SwiftData, zero network) ─
        var scannedResults: [FoodItem] = []
        if let ctx = modelContext {
            scannedResults = ScannedFoodRepository.shared.search(query: query, in: ctx)
            print("Log output removed for English localization")
        }

        // Merge local + scanned (deduped by lowercased name)
        var results: [FoodItem] = localResults
        for scanned in scannedResults {
            if !results.contains(where: { $0.name.lowercased() == scanned.name.lowercased() }) {
                results.insert(scanned, at: 0) // scanned foods appear first
            }
        }

        // If we already have good coverage, skip the network entirely
        if results.count >= 5 {
            print("Log output removed for English localization")
            return Array(results.prefix(20))
        }

        // ── Step 3: Global Community Database ──────────────
        let communityFoods = await BarcodeDatabaseService.shared.searchCommunityFoods(query: query)
        let blockedList = UserDefaults.standard.stringArray(forKey: "blockedCommunityFoods") ?? []
        print("Log output removed for English localization")
        for item in communityFoods {
            let cleanName = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if !blockedList.contains(cleanName) && !results.contains(where: { $0.name.lowercased() == item.name.lowercased() }) {
                results.append(item)
            }
        }
        
        let customBarcodeFoods = await BarcodeDatabaseService.shared.searchCustomBarcodesByText(query: query)
        print("Log output removed for English localization")
        for item in customBarcodeFoods {
            if !results.contains(where: { $0.name.lowercased() == item.name.lowercased() }) {
                results.append(item)
            }
        }
        
        // Return if we hit the threshold
        if results.count >= 5 {
            return Array(results.prefix(20))
        }

        // ── Step 4: OpenFoodFacts API ─────────────────────────────────────────
        let offResults = await searchFromOpenFoodFacts(query: query)
        print("Log output removed for English localization")
        for item in offResults {
            if !results.contains(where: { $0.name.lowercased() == item.name.lowercased() }) {
                results.append(item)
            }
        }

        // ── Step 4: FatSecret API (if still not enough) ──────────────────────
        if results.count < 10 {
            print("Log output removed for English localization")
            let fatSecretResults = await searchFromFatSecret(query: query)
            print("Log output removed for English localization")
            for fsItem in fatSecretResults {
                if !results.contains(where: { $0.name.lowercased() == fsItem.name.lowercased() }) {
                    results.append(fsItem)
                }
            }
        }

        // ── Step 5: AI generation as last resort ─────────────────────────────
        if results.isEmpty {
            print("Log output removed for English localization")
            TrackingManager.shared.track(.aiChefUsed(queryLength: query.count))
            if let aiFood = await AINutritionService.shared.generateFoodItem(for: query) {
                print("Log output removed for English localization")
                
                
                BarcodeDatabaseService.shared.saveCommunityFood(item: aiFood)
                
                results.append(aiFood)
            }
        }

        print("Log output removed for English localization")
        return Array(results.prefix(20))
    }


    func fetchProduct(barcode: String) async -> FoodItem? {
        print("Log output removed for English localization")
        if let customProduct = await BarcodeDatabaseService.shared.fetchCustomBarcode(barcode: barcode) {
            print("Log output removed for English localization")
            return customProduct
        }

        if let offProduct = await fetchBarcodeFromOFF(barcode: barcode) {
            print("Log output removed for English localization")
            return offProduct
        }

        if let fatSecretProduct = await fetchBarcodeFromFatSecretBarcode(barcode: barcode) {
            print("Log output removed for English localization")
            return fatSecretProduct
        }

        print("Log output removed for English localization")
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

    private func ensureToken() async -> String? {
            if let token = fatSecretAccessToken { return token }

            
            let clientId = await RemoteConfigManager.shared.getString(forKey: "fatsecret_client_id")
            let clientSecret = await RemoteConfigManager.shared.getString(forKey: "fatsecret_secret")

            let urlString = "https://oauth.fatsecret.com/connect/token"
            guard let url = URL(string: urlString) else { return nil }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            
            let auth = "\(clientId):\(clientSecret)".data(using: .utf8)!.base64EncodedString()
            request.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
            
        request.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials&scope=basic".data(using: .utf8)

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String else { return nil }

            self.fatSecretAccessToken = token
            return token
        } catch { return nil }
    }

    private func searchFromFatSecret(query: String) async -> [FoodItem] {
        guard let token = await ensureToken(),
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }

        let urlString = "https://platform.fatsecret.com/rest/foods/search/v1?search_expression=\(encodedQuery)&format=json&max_results=15"
        guard let url = URL(string: urlString) else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 { return [] }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let foodsSearch = json["foods_search"] as? [String: Any],
                  let results = foodsSearch["results"] as? [String: Any],
                  let foodData = results["food"] else { return [] }

            var foodsArray: [[String: Any]] = []
            if let arr = foodData as? [[String: Any]] { foodsArray = arr }
            else if let dict = foodData as? [String: Any] { foodsArray = [dict] }

            var items: [FoodItem] = []
            for f in foodsArray {
                guard let name = f["food_name"] as? String,
                      let servings = f["servings"] as? [String: Any],
                      let servingData = servings["serving"] else { continue }

                var srv: [String: Any]? = nil
                if let srvArr = servingData as? [[String: Any]] { srv = srvArr.first }
                else if let srvDict = servingData as? [String: Any] { srv = srvDict }

                guard let s = srv else { continue }

                let weightRaw = parseDouble(s["metric_serving_amount"])
                let weight = weightRaw > 0 ? weightRaw : 100.0

                let cals = parseDouble(s["calories"])
                let protein = parseDouble(s["protein"])
                let fat = parseDouble(s["fat"])
                let carbs = parseDouble(s["carbohydrate"])

                items.append(FoodItem(name: name, weight: weight, calories: Int(cals), protein: protein, fats: fat, carbs: carbs))
            }
            return items
        } catch { return [] }
    }

    private func fetchBarcodeFromFatSecretBarcode(barcode: String) async -> FoodItem? {
        guard let token = await ensureToken() else { return nil }

        let urlString = "https://platform.fatsecret.com/rest/food/barcode/find-by-id/v2?barcode=\(barcode)&format=json"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await session.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let food = json["food"] as? [String: Any],
                  let name = food["food_name"] as? String,
                  let servings = food["servings"] as? [String: Any],
                  let servingData = servings["serving"] else { return nil }

            var srv: [String: Any]? = nil
            if let srvArr = servingData as? [[String: Any]] { srv = srvArr.first }
            else if let srvDict = servingData as? [String: Any] { srv = srvDict }

            guard let s = srv else { return nil }

            let weightRaw = parseDouble(s["metric_serving_amount"])
            let weight = weightRaw > 0 ? weightRaw : 100.0

            let cals = parseDouble(s["calories"])
            let protein = parseDouble(s["protein"])
            let fat = parseDouble(s["fat"])
            let carbs = parseDouble(s["carbohydrate"])

            return FoodItem(name: name, weight: weight, calories: Int(cals), protein: protein, fats: fat, carbs: carbs)
        } catch { return nil }
    }
}
