// FILE: FoodTracker/Managers/AINutritionService.swift

import Foundation

struct DailyVerdictDTO: Codable {
    let title: String
    let message: String
    let mood: String // "perfect", "warning", "danger"
}

struct AIRecipeDTO: Codable {
    let name: String
    let info: String
    let calories: Int
    let protein: Double
    let fats: Double
    let carbs: Double
    let cookingTime: Int
}

class AINutritionService {
    static let shared = AINutritionService()
    private init() {}
    
    private let location = "us-central1"
    
    func generateDailyVerdict(consumed: Int, goal: Int, protein: Double, targetProtein: Double) async -> DailyVerdictDTO? {
        let prompt = """
        You are a witty, elite AI Nutrition Coach.
        The user's daily calorie goal is \(goal) kcal. They have consumed \(consumed) kcal so far.
        Their daily protein target is \(Int(targetProtein))g. They have consumed \(Int(protein))g so far.
        
        Analyze this data. Write a short, punchy 2-sentence verdict.
        - If they are doing great, mood is "perfect".
        - If they need to eat more/less to hit goals, mood is "warning".
        - If they heavily ruined their diet (huge surplus), mood is "danger".
        
        Return ONLY a raw JSON object. No Markdown. Format:
        {"title": "String", "message": "String", "mood": "String"}
        """
        return await fetchFromGemini(prompt: prompt, responseType: DailyVerdictDTO.self)
    }
    
    func generateFridgeRecipe(ingredients: String, missingCalories: Int, missingProtein: Int) async -> AIRecipeDTO? {
        let prompt = """
        You are an elite Chef and AI Nutritionist.
        The user wants to cook something using these ingredients: "\(ingredients)".
        They need a meal that is roughly around \(missingCalories) kcal and contains around \(missingProtein)g of protein to hit their daily goals perfectly.
        
        Invent a creative, tasty recipe using primarily these ingredients.
        Return ONLY a raw JSON object. No Markdown. Format:
        {"name": "String", "info": "Short description of how to cook it", "calories": Int, "protein": Double, "fats": Double, "carbs": Double, "cookingTime": Int}
        """
        return await fetchFromGemini(prompt: prompt, responseType: AIRecipeDTO.self)
    }
    // 3. ОТВЕТ В ЧАТЕ
       func sendChatMessage(prompt: String, userContext: String) async -> String? {
           let systemPrompt = """
           You are a friendly, elite AI Nutritionist.
           Context about the user today: \(userContext)
           USER SAYS: "\(prompt)"
           
           Respond conversationally, warmly, and concisely. Keep answers under 4 sentences. 
           If they ask if they can eat something, check their remaining calories from the context and give advice.
           """
           
           return await fetchRawTextFromGemini(prompt: systemPrompt)
       }
       
       // 4. ГЕНЕРАТОР НАЗВАНИЙ ДЛЯ ЧАТА
       func generateChatTitle(for userMessage: String) async -> String {
           let systemPrompt = "Create a very short title (max 2-3 words) for a nutrition chat based on this first message: '\(userMessage)'. Return ONLY the text without quotes."
           return await fetchRawTextFromGemini(prompt: systemPrompt) ?? "Diet Chat"
       }

       // БАЗОВЫЙ МЕТОД ДЛЯ ПОЛУЧЕНИЯ ТЕКСТА
       private func fetchRawTextFromGemini(prompt: String) async -> String? {
           do {
               let token = try await VertexAuthenticator.shared.getValidAccessToken()
               let projectId = try await VertexAuthenticator.shared.getProjectId()
               
               let model = "gemini-2.5-flash"
               let urlString = "https://\(location)-aiplatform.googleapis.com/v1/projects/\(projectId)/locations/\(location)/publishers/google/models/\(model):generateContent"
               guard let url = URL(string: urlString) else { return nil }
               
               let requestBody: [String: Any] = [
                   "contents": [ ["role": "user", "parts": [ ["text": prompt] ]] ],
                   "generationConfig": ["temperature": 0.7]
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
                       return finalString
                   }
               }
           } catch {
               print("❌ AI Chat Error: \(error.localizedDescription)")
           }
           return nil
       }
    private func fetchFromGemini<T: Codable>(prompt: String, responseType: T.Type) async -> T? {
            do {
                let token = try await VertexAuthenticator.shared.getValidAccessToken()
                let projectId = try await VertexAuthenticator.shared.getProjectId()
                
                // 👇 ИСПРАВЛЕНИЕ ЗДЕСЬ: Меняем 1.5 на 2.5
                let model = "gemini-2.5-flash"
                
                let urlString = "https://\(location)-aiplatform.googleapis.com/v1/projects/\(projectId)/locations/\(location)/publishers/google/models/\(model):generateContent"
                guard let url = URL(string: urlString) else { return nil }
            
            let requestBody: [String: Any] = [
                "contents": [ ["role": "user", "parts": [ ["text": prompt] ]] ],
                "generationConfig": ["responseMimeType": "application/json"]
            ]
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                print("❌ AI Service Error: HTTP \(httpResponse.statusCode)")
                return nil
            }
            
            if let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = jsonResult["candidates"] as? [[String: Any]],
               let textResponse = (candidates.first?["content"] as? [String: Any])?["parts"] as? [[String: Any]],
               let finalString = textResponse.first?["text"] as? String {
                
                guard let jsonData = finalString.data(using: .utf8) else { return nil }
                return try JSONDecoder().decode(T.self, from: jsonData)
            }
        } catch {
            print("❌ AI Service Exception: \(error.localizedDescription)")
        }
        return nil
    }
}
