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
        "CRITICAL: RESPOND EXCLUSIVELY IN THIS LANGUAGE: \(currentLanguage). If returning JSON, keep JSON keys in English, but translate ALL string values to \(currentLanguage)."
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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            isFood = try container.decode(Bool.self, forKey: .isFood)
            errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            weight = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .weight)
            calories = VertexAIManager.decodeFlexibleIntIfPresent(from: container, forKey: .calories)
            protein = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .protein)
            fats = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .fats)
            carbs = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .carbs)
        }
    }

    struct MenuRecommendation: Codable {
        let dishName: String
        let estimatedCalories: Int
        let protein: Double
        let fats: Double?
        let carbs: Double?
        let reasoning: String

        init(dishName: String, estimatedCalories: Int, protein: Double, fats: Double? = nil, carbs: Double? = nil, reasoning: String) {
            self.dishName = dishName
            self.estimatedCalories = estimatedCalories
            self.protein = protein
            self.fats = fats
            self.carbs = carbs
            self.reasoning = reasoning
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            dishName = try container.decode(String.self, forKey: .dishName)
            estimatedCalories = VertexAIManager.decodeFlexibleIntIfPresent(from: container, forKey: .estimatedCalories) ?? 0
            protein = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .protein) ?? 0
            fats = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .fats)
            carbs = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .carbs)
            reasoning = try container.decode(String.self, forKey: .reasoning)
        }
    }

    struct MenuAIResponse: Codable {
        let ideal: MenuRecommendation
        let caution: MenuRecommendation
        let avoid: MenuRecommendation
    }

    struct CookingStepEvaluation: Codable {
        let isGood: Bool
        let feedback: String
    }

    struct TransformationMetric: Codable, Identifiable, Equatable {
        var id: String { label }
        let label: String
        let value: String
        let detail: String
        let isPositive: Bool
    }

    struct TransformationAnalysisDTO: Codable {
        let metrics: [TransformationMetric]
        let feedback: String
    }

    private nonisolated static func decodeFlexibleDoubleIfPresent<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> Double? {
        if let val = try? container.decodeIfPresent(Double.self, forKey: key), val.isFinite {
            return val
        }
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: key) {
            return Double(intVal)
        }
        if let strVal = try? container.decodeIfPresent(String.self, forKey: key) {
            let cleaned = strVal.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
            if let parsed = Double(cleaned), parsed.isFinite {
                return parsed
            }
        }
        return nil
    }

    private nonisolated static func decodeFlexibleIntIfPresent<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> Int? {
        decodeFlexibleDoubleIfPresent(from: container, forKey: key).map { Int($0.rounded()) }
    }

    /// Downscales and normalizes image orientation at explicit 1x pixel scale to avoid 3x screen-scale memory blowup.
    nonisolated static func downsampledImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return image }

        let needsResize = longest > maxDimension
        let needsOrientationFix = image.imageOrientation != .up
        guard needsResize || needsOrientationFix else { return image }

        let targetSize: CGSize
        if needsResize {
            let scale = maxDimension / longest
            targetSize = CGSize(width: max(1, (size.width * scale).rounded()), height: max(1, (size.height * scale).rounded()))
        } else {
            targetSize = size
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    nonisolated static func encodedJPEG(_ image: UIImage, maxDimension: CGFloat = 1024, quality: CGFloat = 0.45) -> String? {
        let normalized = downsampledImage(image, maxDimension: maxDimension)
        return normalized.jpegData(compressionQuality: quality)?.base64EncodedString()
    }

    enum FoodImageAnalysisResult {
        case food(FoodItem)
        case notFood(String)
        case failed
    }

    func analyzeFoodImage(_ image: UIImage) async -> FoodItem? {
        switch await analyzeFoodImageDetailed(image) {
        case .food(let item):
            return item
        case .notFood, .failed:
            return nil
        }
    }

    func analyzeFoodImageDetailed(_ image: UIImage) async -> FoodImageAnalysisResult {
        guard let base64Image = await Task.detached(priority: .userInitiated, operation: {
            Self.encodedJPEG(image, maxDimension: 1024, quality: 0.45)
        }).value else {
            return .failed
        }

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

        do {
            let aiResponse = try await client.fetchJSONWithImage(
                prompt: prompt,
                base64Image: base64Image,
                responseType: AIFoodResponse.self
            )

            if !aiResponse.isFood {
                let reason = aiResponse.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallback = String(localized: "No food detected in this photo. Please point at a meal or drink.")
                return .notFood((reason?.isEmpty == false ? reason! : fallback))
            }

            let item = FoodItem(
                name: aiResponse.name ?? String(localized: "Unknown Meal"),
                weight: aiResponse.weight ?? 100.0,
                calories: aiResponse.calories ?? 0,
                protein: aiResponse.protein ?? 0,
                fats: aiResponse.fats ?? 0,
                carbs: aiResponse.carbs ?? 0
            )
            return .food(item)
        } catch {
            print("❌ Vertex AI Error: \(error)")
            return .failed
        }
    }

    func analyzeMenuImage(_ image: UIImage, remainingCalories: Int, targetProtein: Int) async -> MenuAIResponse? {
        guard let base64Image = await Task.detached(priority: .userInitiated, operation: {
            Self.encodedJPEG(image, maxDimension: 1024, quality: 0.45)
        }).value else { return nil }

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
        {
          "ideal": {"dishName": "Name", "estimatedCalories": 400, "protein": 30.0, "fats": 12.0, "carbs": 35.0, "reasoning": "Why"},
          "caution": {"dishName": "Name", "estimatedCalories": 580, "protein": 24.0, "fats": 28.0, "carbs": 52.0, "reasoning": "Modification tip"},
          "avoid": {"dishName": "Name", "estimatedCalories": 1150, "protein": 28.0, "fats": 62.0, "carbs": 95.0, "reasoning": "Why to skip"}
        }
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

    func evaluateCookingStep(image: UIImage, dishTitle: String, stepInstruction: String) async throws -> CookingStepEvaluation {
        guard let base64Image = await Task.detached(priority: .userInitiated, operation: {
            Self.encodedJPEG(image, maxDimension: 1024, quality: 0.45)
        }).value else {
            throw GeminiProxyError.invalidResponse
        }

        let prompt = """
        You are an expert Michelin-star chef assisting a home cook via live camera.
        Dish: "\(dishTitle)"
        Current Step: "\(stepInstruction)"

        Inspect the photo and evaluate how this step looks (sear/browning, seasoning, sauce consistency, doneness, prep readiness).
        If the image does NOT show food or cooking, set "isGood" to false and politely tell them what to aim the camera at.
        Keep "feedback" short, practical, and encouraging (1-2 sentences).

        \(languageInstruction)
        Respond ONLY with a raw JSON object (no Markdown):
        {"isGood": true, "feedback": "Short chef verdict"}
        """

        return try await client.fetchJSONWithImage(
            prompt: prompt,
            base64Image: base64Image,
            responseType: CookingStepEvaluation.self
        )
    }

    func analyzeBeforeAfterPhotos(before: UIImage, after: UIImage, goal: String? = nil) async throws -> TransformationAnalysisDTO {
        let encodedPair: (String, String)? = await Task.detached(priority: .userInitiated) {
            guard let b = Self.encodedJPEG(before, maxDimension: 960, quality: 0.45),
                  let a = Self.encodedJPEG(after, maxDimension: 960, quality: 0.45) else {
                return nil
            }
            return (b, a)
        }.value
        guard let (beforeB64, afterB64) = encodedPair else {
            throw GeminiProxyError.invalidResponse
        }

        let goalContext = goal.map { "User's fitness goal: \($0)." } ?? ""
        let prompt = """
        You are an encouraging, objective fitness & physique progress coach.
        Compare the FIRST image (Before) and SECOND image (After). \(goalContext)
        Give an honest visual comparison of posture, framing, visible muscle tone, and overall composition changes.
        IMPORTANT: Do NOT invent exact tape measurements like exact centimeters or exact percentages unless clearly caveated as visual cues; keep metric "value" labels qualitative or visual-trend oriented (e.g. "Leaner", "Improved", "Defined", "Balanced").
        Provide up to 4 metric cards and 2-3 sentences of constructive feedback (remind briefly that lighting/pose affect visual appearance).

        \(languageInstruction)
        Respond ONLY with a raw JSON object (no Markdown):
        {
          "metrics": [
            {"label": "Posture", "value": "Aligned", "detail": "Shoulder symmetry", "isPositive": true},
            {"label": "Midsection", "value": "Tighter", "detail": "Visual waist contour", "isPositive": true},
            {"label": "Upper Body", "value": "Fuller", "detail": "Shoulder & arm tone", "isPositive": true},
            {"label": "Overall Trend", "value": "Recomp", "detail": "Steadier conditioning", "isPositive": true}
          ],
          "feedback": "Constructive 2-3 sentence assessment."
        }
        """

        return try await client.fetchJSONWithImages(
            prompt: prompt,
            images: [(beforeB64, "image/jpeg"), (afterB64, "image/jpeg")],
            responseType: TransformationAnalysisDTO.self
        )
    }
}
