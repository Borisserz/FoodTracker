//
//  NetworkManager.swift
//  FoodTracker
//

import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}

    private let fatSecretClientId = "b6be4805aa7e4b95bed4354d677d0b89"
    private let fatSecretClientSecret = "fa2b8559e5764541bde8594140ca29db"
    
    private var fatSecretAccessToken: String?

    // MARK: - 1. ПОИСК ПО ШТРИХКОДУ (Двойной водопад)
    func fetchProduct(barcode: String) async -> FoodItem? {
        print("🔍 Ищем штрихкод в Open Food Facts...")
        if let offProduct = await fetchFromOpenFoodFacts(barcode: barcode) {
            print("✅ Нашли в Open Food Facts: \(offProduct.name)")
            return offProduct
        }
        
        print("🔍 В OFF нет, ищем в FatSecret...")
        if let fatSecretProduct = await fetchFromFatSecret(barcode: barcode) {
            print("✅ Нашли в FatSecret: \(fatSecretProduct.name)")
            return fatSecretProduct
        }
        
        print("❌ Продукт не найден")
        return nil
    }

    private func fetchFromOpenFoodFacts(barcode: String) async -> FoodItem? {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OFFResponse.self, from: data)
            
            guard response.status == 1, let p = response.product else { return nil }
            
            return FoodItem(
                name: p.product_name ?? "Unknown OFF Product",
                weight: 100.0,
                calories: Int(p.nutriments?.energy_kcal_100g ?? 0),
                protein: p.nutriments?.proteins_100g ?? 0.0,
                fats: p.nutriments?.fat_100g ?? 0.0,
                carbs: p.nutriments?.carbohydrates_100g ?? 0.0
            )
        } catch { return nil }
    }

    private func fetchFromFatSecret(barcode: String) async -> FoodItem? {
        guard fatSecretClientId != "ВСТАВЬ_CLIENT_ID" else { return nil }
        
        if fatSecretAccessToken == nil {
            fatSecretAccessToken = await getFatSecretToken()
        }
        guard let token = fatSecretAccessToken else { return nil }
        
        let urlString = "https://platform.fatsecret.com/rest/server.api?method=barcode.find&barcode=\(barcode)&format=json"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(FSBarcodeResponse.self, from: data)
            
            guard let food = response.food else { return nil }
            let s = food.servings.serving
            let serving = s.first(where: { $0.metric_serving_amount == "100.000" }) ?? s.first
            
            guard let srv = serving else { return nil }
            
            return FoodItem(
                name: food.food_name,
                weight: Double(srv.metric_serving_amount ?? "100") ?? 100.0,
                calories: Int(Double(srv.calories ?? "0") ?? 0),
                protein: Double(srv.protein ?? "0") ?? 0.0,
                fats: Double(srv.fat ?? "0") ?? 0.0,
                carbs: Double(srv.carbohydrate ?? "0") ?? 0.0
            )
        } catch {
            fatSecretAccessToken = nil
            return nil
        }
    }

    // MARK: - 2. ТЕКСТОВЫЙ ПОИСК (Умный водопад для API)
    func searchFoodByText(query: String) async -> [FoodItem] {
        print("🔍 Ищем текст '\(query)' в Open Food Facts...")
        let offResults = await searchFromOpenFoodFacts(query: query)
        
        // Если бесплатный OFF нашел достаточно данных, отдаем их
        if offResults.count >= 3 {
            print("✅ OFF нашел \(offResults.count) результатов")
            return offResults
        }
        
        // Если пусто или мало, подключаем лимитированный FatSecret
        print("⚠️ В OFF мало данных. Подключаем FatSecret...")
        let fatSecretResults = await searchFromFatSecret(query: query)
        
        let combined = (offResults + fatSecretResults)
        return Array(combined.prefix(15))
    }

    private func searchFromOpenFoodFacts(query: String) async -> [FoodItem] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(encodedQuery)&search_simple=1&action=process&json=1&page_size=15"
        guard let url = URL(string: urlString) else { return [] }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
            
            guard let products = response.products else { return [] }
            
            var results: [FoodItem] = []
            for p in products {
                guard let name = p.product_name, !name.isEmpty else { continue }
                
                let item = FoodItem(
                    name: name,
                    weight: 100.0,
                    calories: Int(p.nutriments?.energy_kcal_100g ?? 0),
                    protein: p.nutriments?.proteins_100g ?? 0.0,
                    fats: p.nutriments?.fat_100g ?? 0.0,
                    carbs: p.nutriments?.carbohydrates_100g ?? 0.0
                )
                
                if item.calories > 0 || name.lowercased().contains("water") {
                    results.append(item)
                }
            }
            return results
        } catch {
            print("❌ OFF Text Search Error: \(error)")
            return []
        }
    }

    private func searchFromFatSecret(query: String) async -> [FoodItem] {
        guard fatSecretClientId != "ВСТАВЬ_CLIENT_ID" else { return [] }
        
        if fatSecretAccessToken == nil {
            fatSecretAccessToken = await getFatSecretToken()
        }
        guard let token = fatSecretAccessToken else { return [] }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        
        let urlString = "https://platform.fatsecret.com/rest/server.api?method=foods.search&search_expression=\(encodedQuery)&format=json&max_results=10"
        guard let url = URL(string: urlString) else { return [] }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(FSTextSearchResponse.self, from: data)
            
            guard let foodsArray = response.foods?.food else { return [] }
            
            var results: [FoodItem] = []
            for f in foodsArray {
                let macros = parseFatSecretDescription(f.food_description)
                let item = FoodItem(
                    name: f.food_name,
                    weight: 100.0,
                    calories: macros.cals,
                    protein: macros.p,
                    fats: macros.f,
                    carbs: macros.c
                )
                results.append(item)
            }
            return results
        } catch { return [] }
    }

    // Парсим кривую строку от FatSecret
    private func parseFatSecretDescription(_ desc: String) -> (cals: Int, f: Double, c: Double, p: Double) {
        var cals = 0; var f = 0.0; var c = 0.0; var p = 0.0
        let components = desc.components(separatedBy: "|")
        for comp in components {
            let clean = comp.trimmingCharacters(in: .whitespacesAndNewlines)
            if clean.contains("Calories:") { cals = Int(clean.components(separatedBy: "Calories:").last?.replacingOccurrences(of: "kcal", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0 }
            else if clean.contains("Fat:") { f = Double(clean.components(separatedBy: "Fat:").last?.replacingOccurrences(of: "g", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0.0 }
            else if clean.contains("Carbs:") { c = Double(clean.components(separatedBy: "Carbs:").last?.replacingOccurrences(of: "g", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0.0 }
            else if clean.contains("Protein:") { p = Double(clean.components(separatedBy: "Protein:").last?.replacingOccurrences(of: "g", with: "").trimmingCharacters(in: .whitespaces) ?? "0") ?? 0.0 }
        }
        return (cals, f, c, p)
    }

    private func getFatSecretToken() async -> String? {
        guard let url = URL(string: "https://oauth.fatsecret.com/connect/token") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let auth = "\(fatSecretClientId):\(fatSecretClientSecret)".data(using: .utf8)!.base64EncodedString()
        request.setValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = "grant_type=client_credentials&scope=barcode.api".data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let tokenResponse = try JSONDecoder().decode(FSTokenResponse.self, from: data)
            return tokenResponse.access_token
        } catch { return nil }
    }
}

// MARK: - DTOs
struct OFFResponse: Codable { let status: Int; let product: OFFProduct? }
struct OFFProduct: Codable { let product_name: String?; let nutriments: OFFNutriments? }
struct OFFNutriments: Codable {
    let energy_kcal_100g: Double?; let proteins_100g: Double?; let fat_100g: Double?; let carbohydrates_100g: Double?
    enum CodingKeys: String, CodingKey { case energy_kcal_100g = "energy-kcal_100g"; case proteins_100g, fat_100g, carbohydrates_100g }
}

struct OFFSearchResponse: Codable { let products: [OFFProduct]? }

struct FSTokenResponse: Codable { let access_token: String }
struct FSBarcodeResponse: Codable { let food: FSFood? }
struct FSFood: Codable { let food_name: String; let servings: FSServings }
struct FSServings: Codable { let serving: [FSServing] }
struct FSServing: Codable {
    let metric_serving_amount: String?; let calories: String?; let carbohydrate: String?; let protein: String?; let fat: String?
}

struct FSTextSearchResponse: Codable { let foods: FSFoodsList? }
struct FSFoodsList: Codable { let food: [FSSearchFoodItem] }
struct FSSearchFoodItem: Codable { let food_name: String; let food_description: String }
