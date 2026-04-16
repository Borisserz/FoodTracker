//
//  NetworkManager.swift
//  FoodTracker
//

import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}

    // Твои ключи от FatSecret
    private let fatSecretClientId = "b6be4805aa7e4b95bed4354d677d0b89"
    private let fatSecretClientSecret = "fa2b8559e5764541bde8594140ca29db"
    
    private var fatSecretAccessToken: String?

    // Безопасное получение языка
    private var currentLanguage: String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }

    // MARK: - 1. ТЕКСТОВЫЙ ПОИСК
    func searchFoodByText(query: String) async -> [FoodItem] {
        print("🔍 Ищем '\(query)' (Язык: \(currentLanguage))")
        
        // ШАГ 1: Open Food Facts (Бесплатная база)
        var results = await searchFromOpenFoodFacts(query: query)
        
        // ШАГ 2: FatSecret (Если мало результатов)
        if results.count < 5 {
            print("⚠️ В OFF найдено мало. Подключаем FatSecret...")
            let fatSecretResults = await searchFromFatSecretV5(query: query)
            
            for fsItem in fatSecretResults {
                if !results.contains(where: { $0.name.lowercased() == fsItem.name.lowercased() }) {
                    results.append(fsItem)
                }
            }
        }
        
        print("✅ Итого найдено: \(results.count) результатов.")
        return Array(results.prefix(20))
    }
    private func fetchBarcodeFromOFF(barcode: String) async -> FoodItem? {
            let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
            guard let url = URL(string: urlString) else { return nil }
            
            var request = URLRequest(url: url)
            request.setValue("FoodTrackerApp/1.0", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let status = json["status"] as? Int, status == 1,
                      let p = json["product"] as? [String: Any],
                      let name = p["product_name"] as? String, !name.isEmpty else { return nil }
                
                let nuts = p["nutriments"] as? [String: Any] ?? [:]
                let cals = Double("\(nuts["energy-kcal_100g"] ?? nuts["energy_100g"] ?? 0)") ?? 0
                let protein = Double("\(nuts["proteins_100g"] ?? 0)") ?? 0
                let fat = Double("\(nuts["fat_100g"] ?? 0)") ?? 0
                let carbs = Double("\(nuts["carbohydrates_100g"] ?? 0)") ?? 0
                
                return FoodItem(name: name, weight: 100.0, calories: Int(cals), protein: protein, fats: fat, carbs: carbs)
            } catch {
                return nil
            }
        }
    // MARK: - 2. ПОИСК ПО ШТРИХКОДУ
    func fetchProduct(barcode: String) async -> FoodItem? {
        print("🔍 Ищем штрихкод \(barcode)...")
        if let offProduct = await fetchBarcodeFromOFF(barcode: barcode) {
            print("✅ Нашли в Open Food Facts: \(offProduct.name)")
            return offProduct
        }
        
        if let fatSecretProduct = await fetchBarcodeFromFatSecretV2(barcode: barcode) {
            print("✅ Нашли в FatSecret: \(fatSecretProduct.name)")
            return fatSecretProduct
        }
        
        print("❌ Продукт по штрихкоду не найден.")
        return nil
    }

    // =========================================================================
    // MARK: - Реализация Open Food Facts (Ручной парсинг)
    // =========================================================================

    private func searchFromOpenFoodFacts(query: String) async -> [FoodItem] {
            guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
            
            let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1&page_size=15"
            guard let url = URL(string: urlString) else { return [] }
            
            var request = URLRequest(url: url)
            // 🔥 Обязательно указываем подробный User-Agent, иначе база OFF банит запросы и отдает пустоту
            request.setValue("FoodTrackerApp - iOS - Version 1.0", forHTTPHeaderField: "User-Agent")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return [] }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let products = json["products"] as? [[String: Any]] else { return [] }
                
                var items: [FoodItem] = []
                for p in products {
                    guard let name = p["product_name"] as? String ?? p["product_name_ru"] as? String ?? p["product_name_en"] as? String, !name.isEmpty else { continue }
                    
                    let nuts = p["nutriments"] as? [String: Any] ?? [:]
                    let cals = Double("\(nuts["energy-kcal_100g"] ?? nuts["energy_100g"] ?? 0)") ?? 0
                    let protein = Double("\(nuts["proteins_100g"] ?? 0)") ?? 0
                    let fat = Double("\(nuts["fat_100g"] ?? 0)") ?? 0
                    let carbs = Double("\(nuts["carbohydrates_100g"] ?? 0)") ?? 0
                    
                    if cals > 0 || protein > 0 || fat > 0 || carbs > 0 {
                        items.append(FoodItem(name: name, weight: 100.0, calories: Int(cals), protein: protein, fats: fat, carbs: carbs))
                    }
                }
                return items
            } catch {
                return []
            }
        }

        private func searchFromFatSecretV5(query: String) async -> [FoodItem] {
            guard let token = await ensureToken(),
                  let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
            
            // 🔥 ИСПРАВЛЕНИЕ: Меняем v5 на v1 (Именно v1 — это актуальная версия поиска FatSecret)
            let urlString = "https://platform.fatsecret.com/rest/foods/search/v1?search_expression=\(encodedQuery)&format=json&max_results=15"
            
            guard let url = URL(string: urlString) else { return [] }
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Проверка на ошибку от FatSecret
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    print("❌ FatSecret Search Ошибка \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                    return []
                }
                
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
                    
                    let weight = Double("\(s["metric_serving_amount"] ?? "100")") ?? 100.0
                    let cals = Double("\(s["calories"] ?? "0")") ?? 0
                    let protein = Double("\(s["protein"] ?? "0")") ?? 0
                    let fat = Double("\(s["fat"] ?? "0")") ?? 0
                    let carbs = Double("\(s["carbohydrate"] ?? "0")") ?? 0
                    
                    items.append(FoodItem(name: name, weight: weight, calories: Int(cals), protein: protein, fats: fat, carbs: carbs))
                }
                return items
            } catch { return [] }
        }
    // =========================================================================
    // MARK: - Реализация FatSecret (Ручной парсинг)
    // =========================================================================

    private func ensureToken() async -> String? {
        if let token = fatSecretAccessToken { return token }
        
        let urlString = "https://oauth.fatsecret.com/connect/token"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let auth = "\(fatSecretClientId):\(fatSecretClientSecret)".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials&scope=basic".data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("❌ FatSecret Токен Ошибка \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
                return nil
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String else { return nil }
            
            self.fatSecretAccessToken = token
            return token
        } catch {
            print("❌ Ошибка сети FatSecret: \(error.localizedDescription)")
            return nil
        }
    }

   
    private func fetchBarcodeFromFatSecretV2(barcode: String) async -> FoodItem? {
        guard let token = await ensureToken() else { return nil }
        
        let urlString = "https://platform.fatsecret.com/rest/food/barcode/find-by-id/v2?barcode=\(barcode)&format=json&language=\(currentLanguage)"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let food = json["food"] as? [String: Any],
                  let name = food["food_name"] as? String,
                  let servings = food["servings"] as? [String: Any],
                  let servingData = servings["serving"] else { return nil }
            
            var srv: [String: Any]? = nil
            if let srvArr = servingData as? [[String: Any]] { srv = srvArr.first }
            else if let srvDict = servingData as? [String: Any] { srv = srvDict }
            
            guard let s = srv else { return nil }
            
            let weight = Double("\(s["metric_serving_amount"] ?? "100")") ?? 100.0
            let cals = Double("\(s["calories"] ?? "0")") ?? 0
            let protein = Double("\(s["protein"] ?? "0")") ?? 0
            let fat = Double("\(s["fat"] ?? "0")") ?? 0
            let carbs = Double("\(s["carbohydrate"] ?? "0")") ?? 0
            
            return FoodItem(name: name, weight: weight, calories: Int(cals), protein: protein, fats: fat, carbs: carbs)
        } catch { return nil }
    }
}
