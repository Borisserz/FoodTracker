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

    func analyzeFoodImage(_ image: UIImage) async -> FoodItem? {
        guard let imageData = image.jpegData(compressionQuality: 0.3) else { return nil }
        let base64Image = imageData.base64EncodedString()

        let prompt = """
        You are an elite AI nutritionist. Analyze the image.
        1. Check if the image contains food or a drink. If it DOES NOT, set "isFood" to false and write a funny "errorMessage" (e.g., "That's a keyboard, not a sandwich!").
        2. If it IS food, set "isFood" to true. Estimate the food name, total weight in grams, total calories, and macros (protein, fats, carbs in grams).
        3. Respond ONLY with a raw, valid JSON object. NO Markdown, NO ```json formatting, NO extra text.
        Format exactly like this:
        {"isFood": true, "errorMessage": null, "name": "Avocado Toast", "weight": 150.0, "calories": 220, "protein": 5.0, "fats": 12.0, "carbs": 20.0}
        """

        do {
            let aiResponse = try await client.fetchJSONWithImage(
                prompt: prompt,
                base64Image: base64Image,
                responseType: AIFoodResponse.self
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

        do {
            return try await client.fetchJSONWithImage(
                prompt: prompt,
                base64Image: base64Image,
                responseType: MenuAIResponse.self
            )
        } catch {
            print("❌ Menu AI Error: \(error)")
            return nil
        }
    }
}
