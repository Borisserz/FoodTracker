import Foundation
import UIKit

/// Vision-focused facade. All transport, auth, and low-level Gemini logic is now in GeminiProxyClient.
final class VertexAIManager {
    static let shared = VertexAIManager()
    private init() {}

    // Delegate to the shared client (deduplication complete for this file).
    private let client = GeminiProxyClient.shared

    private var currentLanguage: String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        switch code {
        case "ru": return "Russian"
        case "es": return "Spanish"
        case "fr": return "French"
        case "de": return "German"
        case "it": return "Italian"
        case "pt": return "Portuguese"
        default: return "English"
        }
    }

    private var languageInstruction: String {
        "CRITICAL: RESPOND EXCLUSIVELY IN THIS LANGUAGE: \\(currentLanguage). If returning JSON, keep JSON keys in English, but translate ALL string values to \\(currentLanguage)."
    }

    struct AIFoodResponse: Codable {
        let isFood: Bool
        let errorMessage: String?
        let name: String?
        let weight: Double?
        let calories: Int?
        let protein: Double?
        let fats: Double?
        let carbs: Double?
    }

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

    /// AI verdict for chef cooking step evaluation
    struct ChefVerdictResponse: Codable {
        let score: Int           // 0–100, how well the step is being done
        let verdict: String      // "perfect" | "good" | "needs_work"
        let feedback: String     // Main evaluation message
        let tip: String          // One specific pro chef tip
    }

    func analyzeFoodImage(_ image: UIImage) async -> FoodItem? {
        guard let imageData = image.jpegData(compressionQuality: 0.3) else { return nil }
        let base64Image = imageData.base64EncodedString()

        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let prompt = """
        You are an elite AI nutritionist. Analyze the image with extreme precision.
        1. Check if the image contains food or a drink. If it DOES NOT, set "isFood" to false and write a funny "errorMessage" (e.g., "That's a keyboard, not a sandwich!").
        2. If it IS food, set "isFood" to true.
        3. Identify all visible ingredients. Estimate the physical portion size (in grams) by comparing it to typical plates or hands in the frame.
        4. Calculate total calories and macros (protein, fats, carbs in grams). Be conservative and realistic. Account for hidden oils, butter, and dressings often used in cooking.
        5. Respond ONLY with a raw, valid JSON object. NO Markdown, NO ```json formatting, NO extra text.
        \(languageInstruction)
        Format exactly like this:
        {"isFood": true, "errorMessage": null, "name": "Avocado Toast", "weight": 150.0, "calories": 220, "protein": 5.0, "fats": 12.0, "carbs": 20.0}
        """

        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "isFood": ["type": "BOOLEAN"],
                "errorMessage": ["type": "STRING", "nullable": true],
                "name": ["type": "STRING", "nullable": true],
                "weight": ["type": "NUMBER", "nullable": true],
                "calories": ["type": "INTEGER", "nullable": true],
                "protein": ["type": "NUMBER", "nullable": true],
                "fats": ["type": "NUMBER", "nullable": true],
                "carbs": ["type": "NUMBER", "nullable": true]
            ],
            "required": ["isFood"]
        ]

        do {
            let aiResponse = try await client.fetchJSONWithImage(
                prompt: prompt,
                base64Image: base64Image,
                responseType: AIFoodResponse.self,
                schema: schema
            )

            if !aiResponse.isFood {
                print("❌ AI Says: \(aiResponse.errorMessage ?? "Not food")")
                return nil
            }

            return FoodItem(
                name: aiResponse.name ?? String(localized: "Unknown Meal"),
                weight: aiResponse.weight ?? 100.0,
                calories: aiResponse.calories ?? 0,
                protein: aiResponse.protein ?? 0,
                fats: aiResponse.fats ?? 0,
                carbs: aiResponse.carbs ?? 0
            )
        } catch {
            print("❌ Vertex AI Error: \(error)")
            return nil
        }
    }

    func analyzeMenuImage(_ image: UIImage, remainingCalories: Int, targetProtein: Int) async -> MenuAIResponse? {
        guard let imageData = image.jpegData(compressionQuality: 0.3) else { return nil }
        let base64Image = imageData.base64EncodedString()

        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let prompt = """
        You are an elite AI nutritionist and menu analyst. Read the restaurant menu in the image.
        The user has \(remainingCalories) kcal left for today and needs around \(targetProtein)g more protein.
        
        Analyze the dishes, estimating hidden calories from restaurant cooking methods (oils, heavy creams, large portions).
        Pick exactly 3 dishes from the menu:
        1. "ideal" - The best fit for their remaining calories and high protein. Prioritize lean proteins and veggies.
        2. "caution" - A dish that is okay but risky. Provide advice on how to modify it (e.g., "ask for dressing on the side", "no cheese").
        3. "avoid" - A massive calorie-bomb or highly processed dish they must avoid today.

        \(languageInstruction)
        Respond ONLY with a raw, valid JSON object. No Markdown. Format exactly:
        {"ideal": {"dishName": "Name", "estimatedCalories": 400, "protein": 30.0, "reasoning": "Why"}, "caution": {...}, "avoid": {...}}
        """

        let recommendationSchema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "dishName": ["type": "STRING"],
                "estimatedCalories": ["type": "INTEGER"],
                "protein": ["type": "NUMBER"],
                "reasoning": ["type": "STRING"]
            ],
            "required": ["dishName", "estimatedCalories", "protein", "reasoning"]
        ]
        
        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "ideal": recommendationSchema,
                "caution": recommendationSchema,
                "avoid": recommendationSchema
            ],
            "required": ["ideal", "caution", "avoid"]
        ]

        do {
            return try await client.fetchJSONWithImage(
                prompt: prompt,
                base64Image: base64Image,
                responseType: MenuAIResponse.self,
                schema: schema
            )
        } catch {
            print("❌ Menu AI Error: \(error)")
            return nil
        }
    }

    /// Evaluates how well the user is executing a specific cooking step using real AI vision.
    func analyzeChefCookingStep(image: UIImage, stepInstruction: String) async -> ChefVerdictResponse? {
        guard let imageData = image.jpegData(compressionQuality: 0.4) else { return nil }
        let base64Image = imageData.base64EncodedString()

        let language = Locale.current.language.languageCode?.identifier ?? "en"
        let prompt = """
        You are a Michelin-star AI Chef conducting a live cooking evaluation.
        The cooking step being evaluated is: "\(stepInstruction)"

        Look at the image carefully and evaluate how well this cooking step is being executed.
        Please provide the feedback and tip in language code '\(language)'.

        Scoring guide:
        - 85-100: Perfect execution → verdict = "perfect"
        - 60-84: Good, minor improvements possible → verdict = "good"
        - 0-59: Needs attention → verdict = "needs_work"
        """

        let schema: [String: Any] = [
            "type": "OBJECT",
            "properties": [
                "score": ["type": "INTEGER"],
                "verdict": ["type": "STRING", "enum": ["perfect", "good", "needs_work"]],
                "feedback": ["type": "STRING"],
                "tip": ["type": "STRING"]
            ],
            "required": ["score", "verdict", "feedback", "tip"]
        ]

        do {
            return try await client.fetchJSONWithImage(
                prompt: prompt,
                base64Image: base64Image,
                responseType: ChefVerdictResponse.self,
                schema: schema
            )
        } catch {
            print("❌ Chef Step AI Error: \(error)")
            return nil
        }
    }
}
