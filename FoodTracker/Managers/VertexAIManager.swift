import Foundation
import UIKit

class VertexAIManager {
    static let shared = VertexAIManager()
    private init() {}
    
    private let location = "us-central1" // Локация твоего проекта
    
    struct AIFoodResponse: Codable {
        let isFood: Bool
        let errorMessage: String? // Если это не еда, ИИ напишет шуточную причину
        let name: String?
        let weight: Double?
        let calories: Int?
        let protein: Double?
        let fats: Double?
        let carbs: Double?
    }
    
    // MARK: - МОДЕЛИ ДЛЯ МЕНЮ РЕСТОРАНА
    struct MenuRecommendation: Codable {
        let dishName: String
        let estimatedCalories: Int
        let protein: Double
        let reasoning: String
    }
    
    struct MenuAIResponse: Codable {
        let ideal: MenuRecommendation
        let caution: MenuRecommendation
        let avoid: MenuRecommendation
    }
    
    func analyzeFoodImage(_ image: UIImage) async -> FoodItem? {
        guard let imageData = image.jpegData(compressionQuality: 0.3) else { return nil }
        let base64Image = imageData.base64EncodedString()
        
        do {
            let token = try await VertexAuthenticator.shared.getValidAccessToken()
            let projectId = try await VertexAuthenticator.shared.getProjectId()
            
            let model = "gemini-1.5-flash"
            let urlString = "https://\(location)-aiplatform.googleapis.com/v1/projects/\(projectId)/locations/\(location)/publishers/google/models/\(model):generateContent"
            guard let url = URL(string: urlString) else { return nil }
            
            // 🔥 КРУТОЙ И ЖЕСТКИЙ СИСТЕМНЫЙ ПРОМПТ
            let prompt = """
            You are an elite AI nutritionist. Analyze the image.
            1. Check if the image contains food or a drink. If it DOES NOT, set "isFood" to false and write a funny "errorMessage" (e.g., "That's a keyboard, not a sandwich!").
            2. If it IS food, set "isFood" to true. Estimate the food name, total weight in grams, total calories, and macros (protein, fats, carbs in grams).
            3. Respond ONLY with a raw, valid JSON object. NO Markdown, NO ```json formatting, NO extra text.
            Format exactly like this:
            {"isFood": true, "errorMessage": null, "name": "Avocado Toast", "weight": 150.0, "calories": 220, "protein": 5.0, "fats": 12.0, "carbs": 20.0}
            """
            
            let partsArray: [[String: Any]] = [
                ["text": prompt],
                ["inlineData": ["mimeType": "image/jpeg", "data": base64Image]]
            ]
            let contentsArray: [[String: Any]] = [
                [
                    "role": "user",
                    "parts": partsArray
                ]
            ]
            let requestBody: [String: Any] = [
                "contents": contentsArray,
                "generationConfig": ["responseMimeType": "application/json"]
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = jsonResult["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let textResponse = (content["parts"] as? [[String: Any]])?.first?["text"] as? String {
                
                // ✅ ДОБАВЛЕНО: Очистка от Markdown (Убираем ```json и ```)
                var cleanString = textResponse.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanString.hasPrefix("```json") { cleanString = String(cleanString.dropFirst(7)) }
                if cleanString.hasPrefix("```") { cleanString = String(cleanString.dropFirst(3)) }
                if cleanString.hasSuffix("```") { cleanString = String(cleanString.dropLast(3)) }
                cleanString = cleanString.trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard let jsonData = cleanString.data(using: .utf8) else { return nil }
                let aiResponse = try JSONDecoder().decode(AIFoodResponse.self, from: jsonData)
                
                if !aiResponse.isFood {
                    print("❌ AI Says: \(aiResponse.errorMessage ?? "Not food")")
                    return nil
                }
                
                return FoodItem(
                    name: aiResponse.name ?? "Unknown Meal",
                    weight: aiResponse.weight ?? 100.0,
                    calories: aiResponse.calories ?? 0,
                    protein: aiResponse.protein ?? 0,
                    fats: aiResponse.fats ?? 0,
                    carbs: aiResponse.carbs ?? 0
                )
            }
        // 👇 Вот эти скобки и catch блок были случайно удалены в прошлом шаге!
        } catch {
            print("❌ Vertex AI Error: \(error)")
        }
        return nil
    }

    // MARK: - АНАЛИЗ МЕНЮ РЕСТОРАНА
    func analyzeMenuImage(_ image: UIImage, remainingCalories: Int, targetProtein: Int) async -> MenuAIResponse? {
        guard let imageData = image.jpegData(compressionQuality: 0.3) else { return nil }
        let base64Image = imageData.base64EncodedString()
        
        do {
            let token = try await VertexAuthenticator.shared.getValidAccessToken()
            let projectId = try await VertexAuthenticator.shared.getProjectId()
            
            let model = "gemini-2.5-flash"
            let urlString = "https://\(location)-aiplatform.googleapis.com/v1/projects/\(projectId)/locations/\(location)/publishers/google/models/\(model):generateContent"
            guard let url = URL(string: urlString) else { return nil }
            
            let prompt = """
            You are an elite AI nutritionist. Read the restaurant menu in the image.
            The user has \(remainingCalories) kcal left for today and needs around \(targetProtein)g more protein.
            
            Pick exactly 3 dishes from the menu:
            1. "ideal" - The best fit for their remaining calories and high protein.
            2. "caution" - A dish that is okay, but they should be careful (e.g., ask for dressing on the side).
            3. "avoid" - A calorie-bomb or unhealthy dish they must avoid today to stay on track.
            
            Respond ONLY with a raw, valid JSON object. No Markdown. Format exactly:
            {"ideal": {"dishName": "Name", "estimatedCalories": 400, "protein": 30.0, "reasoning": "Why"}, "caution": {...}, "avoid": {...}}
            """
            
            let partsArray: [[String: Any]] = [
                ["text": prompt],
                ["inlineData": ["mimeType": "image/jpeg", "data": base64Image]]
            ]
            let contentsArray: [[String: Any]] = [
                [
                    "role": "user",
                    "parts": partsArray
                ]
            ]
            let requestBody: [String: Any] = [
                "contents": contentsArray,
                "generationConfig": ["responseMimeType": "application/json"]
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = jsonResult["candidates"] as? [[String: Any]],
                   let textResponse = (candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]],
                   let finalString = textResponse.first?["text"] as? String {
                    
                    var cleanString = finalString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if cleanString.hasPrefix("```json") { cleanString = String(cleanString.dropFirst(7)) }
                    if cleanString.hasSuffix("```") { cleanString = String(cleanString.dropLast(3)) }
                    
                    guard let jsonData = cleanString.data(using: .utf8) else { return nil }
                    return try JSONDecoder().decode(MenuAIResponse.self, from: jsonData)
                }
            }
        } catch { print("❌ Menu AI Error: \(error)") }
        return nil
    }
}
