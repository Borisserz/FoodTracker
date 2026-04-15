import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    private init() {}

    private let fatSecretClientId = "b6be4805aa7e4b95bed4354d677d0b89"
        private let fatSecretClientSecret = "fa2b8559e5764541bde8594140ca29db"
    
    private var fatSecretAccessToken: String?

    // MARK: - ГЛАВНАЯ ФУНКЦИЯ (Двойной водопад)
    func fetchProduct(barcode: String) async -> FoodItem? {
        
        // 1. Сначала пробуем Open Food Facts (Быстрее всего)
        print("🔍 Ищем в Open Food Facts...")
        if let offProduct = await fetchFromOpenFoodFacts(barcode: barcode) {
            print("✅ Нашли в Open Food Facts: \(offProduct.name)")
            return offProduct
        }
        
        // 2. Если нет, идем в FatSecret (Лучшая база для СНГ)
        print("🔍 В OFF нет, ищем в FatSecret...")
        if let fatSecretProduct = await fetchFromFatSecret(barcode: barcode) {
            print("✅ Нашли в FatSecret: \(fatSecretProduct.name)")
            return fatSecretProduct
        }
        
        print("❌ Продукт не найден")
        return nil
    }

    // ---------------------------------------------------------
    // 1. OPEN FOOD FACTS
    // ---------------------------------------------------------
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

    // ---------------------------------------------------------
    // 2. FATSECRET
    // ---------------------------------------------------------
    private func fetchFromFatSecret(barcode: String) async -> FoodItem? {
        guard fatSecretClientId != "ВСТАВЬ_CLIENT_ID" else { return nil }
        
        if fatSecretAccessToken == nil {
            fatSecretAccessToken = await getFatSecretToken()
        }
        guard let token = fatSecretAccessToken else { return nil }
        
        // Запрос на поиск по штрихкоду
        let urlString = "https://platform.fatsecret.com/rest/server.api?method=barcode.find&barcode=\(barcode)&format=json"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(FSBarcodeResponse.self, from: data)
            
            guard let food = response.food else { return nil }
            
            // Ищем порцию 100г для точности
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
            fatSecretAccessToken = nil // Сбрасываем токен при ошибке
            return nil
        }
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

// MARK: - МОДЕЛИ (DTO)
struct OFFResponse: Codable { let status: Int; let product: OFFProduct? }
struct OFFProduct: Codable { let product_name: String?; let nutriments: OFFNutriments? }
struct OFFNutriments: Codable {
    let energy_kcal_100g: Double?; let proteins_100g: Double?; let fat_100g: Double?; let carbohydrates_100g: Double?
    enum CodingKeys: String, CodingKey { case energy_kcal_100g = "energy-kcal_100g"; case proteins_100g, fat_100g, carbohydrates_100g }
}

struct FSTokenResponse: Codable { let access_token: String }
struct FSBarcodeResponse: Codable { let food: FSFood? }
struct FSFood: Codable { let food_name: String; let servings: FSServings }
struct FSServings: Codable { let serving: [FSServing] }
struct FSServing: Codable {
    let metric_serving_amount: String?; let calories: String?; let carbohydrate: String?; let protein: String?; let fat: String?
}
