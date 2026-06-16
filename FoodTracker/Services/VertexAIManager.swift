import Foundation
import UIKit

/// Vision-focused facade. All transport, auth, and low-level Gemini logic is now in GeminiProxyClient.
final class VertexAIManager {
    static let shared = VertexAIManager()
    private init() {}

    // Delegate to the shared client (deduplication complete for this file).
    private let client = GeminiProxyClient.shared

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
        You are an elite AI nutritionist. Analyze the image.
        1. Check if the image contains food, a drink, a nutrition label, or food packaging. If it DOES NOT, set "isFood" to false and write a funny "errorMessage" in the language code: '\(language)' (e.g., "That's a keyboard, not a sandwich!").
        2. If it is a nutrition label, extract the exact macros from the text. If it is a food package or wrapper (like a chocolate bar, snack, etc.) but the exact nutrition label is NOT visible, DO NOT reject it. Instead, read the product name from the package and estimate the calories and macronutrients per 100 grams based on your knowledge of this specific product or product type.
        3. If it IS a meal, food item, or food packaging, set "isFood" to true and provide the food name in language code '\(language)', total weight or serving size in grams (default to 100 if unknown), total calories, and macros.
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
                name: aiResponse.name ?? "Unknown Meal",
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
        You are an elite AI nutritionist. Read the restaurant menu in the image.
        The user has \(remainingCalories) kcal left for today and needs around \(targetProtein)g more protein.

        Pick exactly 3 dishes from the menu and write their names and reasoning in language code '\(language)':
        1. "ideal" - The best fit for their remaining calories and high protein.
        2. "caution" - A dish that is okay, but they should be careful (e.g., ask for dressing on the side).
        3. "avoid" - A calorie-bomb or unhealthy dish they must avoid today to stay on track.
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
