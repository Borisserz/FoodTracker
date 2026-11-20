import Foundation
import UIKit

enum AIErrorReason: Equatable, Sendable {
    case consentRequired
    case networkUnavailable
    case timedOut
    case rateLimited(retryAfter: String?)
    case decodingFailed
    case serverError(status: Int)
    case encodingFailed
    case other(String)
}

/// Vision-focused facade. All transport, auth, and low-level Gemini logic is now in GeminiProxyClient.
final class VertexAIManager {
    static let shared = VertexAIManager()

    // Delegate to the shared client (deduplication complete for this file).
    private let client: any GeminiProxyExecuting
    private let photoConsentProvider: (@MainActor () -> Bool)?
    private let errorLock = NSLock()
    private var _lastFailureReason: AIErrorReason?
    private var _lastUserFacingError: String?

    var lastFailureReason: AIErrorReason? {
        errorLock.withLock { _lastFailureReason }
    }

    var lastUserFacingError: String? {
        errorLock.withLock { _lastUserFacingError }
    }

    private func clearErrorState() {
        errorLock.withLock {
            _lastFailureReason = nil
            _lastUserFacingError = nil
        }
    }

    private func recordFailure(reason: AIErrorReason, userMessage: String) {
        errorLock.withLock {
            _lastFailureReason = reason
            _lastUserFacingError = userMessage
        }
    }

    private func recordFailure(for error: Error) {
        recordFailure(
            reason: Self.classifyError(error),
            userMessage: AINutritionService.userFacingErrorMessage(for: error)
        )
    }

    static func classifyError(_ error: Error) -> AIErrorReason {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return .networkUnavailable
            case .timedOut:
                return .timedOut
            default:
                return .other(urlError.localizedDescription)
            }
        }
        if let proxyError = error as? GeminiProxyError {
            switch proxyError {
            case .rateLimited(let retryAfter):
                return .rateLimited(retryAfter: retryAfter)
            case .serverError(let status, _):
                return .serverError(status: status)
            case .decodingFailed, .invalidResponse:
                return .decodingFailed
            case .invalidURL:
                return .other("invalidURL")
            }
        }
        if error is DecodingError {
            return .decodingFailed
        }
        return .other(error.localizedDescription)
    }

    init(
        proxy: any GeminiProxyExecuting = GeminiProxyClient.shared,
        photoConsentProvider: (@MainActor () -> Bool)? = nil
    ) {
        self.client = proxy
        self.photoConsentProvider = photoConsentProvider
    }

    private func hasPhotoConsent() async -> Bool {
        await MainActor.run {
            if let photoConsentProvider {
                return photoConsentProvider()
            }
            return AIPhotoConsentManager.shared.hasConsented
        }
    }

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
        let omega3: Double?
        let calcium: Double?
        let potassium: Double?
        let magnesium: Double?
        let iron: Double?
        let vitaminC: Double?
        let vitaminD: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            isFood = VertexAIManager.decodeFlexibleBoolIfPresent(from: container, forKey: .isFood) ?? false
            errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            weight = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .weight).map { min(max(0.0, $0), 50_000.0) }
            calories = VertexAIManager.decodeFlexibleIntIfPresent(from: container, forKey: .calories).map { min(max(0, $0), 50_000) }
            protein = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .protein).map { min(max(0.0, $0), 10_000.0) }
            fats = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .fats).map { min(max(0.0, $0), 10_000.0) }
            carbs = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .carbs).map { min(max(0.0, $0), 10_000.0) }
            omega3 = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .omega3).map { min(max(0.0, $0), 1_000.0) }
            calcium = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .calcium).map { min(max(0.0, $0), 10_000.0) }
            potassium = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .potassium).map { min(max(0.0, $0), 20_000.0) }
            magnesium = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .magnesium).map { min(max(0.0, $0), 10_000.0) }
            iron = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .iron).map { min(max(0.0, $0), 1_000.0) }
            vitaminC = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .vitaminC).map { min(max(0.0, $0), 10_000.0) }
            vitaminD = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .vitaminD).map { min(max(0.0, $0), 1_000.0) }
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
            self.estimatedCalories = min(max(0, estimatedCalories), 50_000)
            self.protein = protein.isFinite ? min(max(0.0, protein), 10_000.0) : 0.0
            self.fats = fats.flatMap { $0.isFinite ? min(max(0.0, $0), 10_000.0) : nil }
            self.carbs = carbs.flatMap { $0.isFinite ? min(max(0.0, $0), 10_000.0) : nil }
            self.reasoning = reasoning
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            dishName = try container.decode(String.self, forKey: .dishName)
            let rawCalories = VertexAIManager.decodeFlexibleIntIfPresent(from: container, forKey: .estimatedCalories) ?? 0
            estimatedCalories = min(max(0, rawCalories), 50_000)
            let rawProtein = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .protein) ?? 0
            protein = min(max(0.0, rawProtein), 10_000.0)
            fats = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .fats).map { min(max(0.0, $0), 10_000.0) }
            carbs = VertexAIManager.decodeFlexibleDoubleIfPresent(from: container, forKey: .carbs).map { min(max(0.0, $0), 10_000.0) }
            reasoning = try container.decode(String.self, forKey: .reasoning)
        }
    }

    struct MenuAIResponse: Codable {
        let ideal: MenuRecommendation?
        let caution: MenuRecommendation?
        let avoid: MenuRecommendation?

        init(ideal: MenuRecommendation?, caution: MenuRecommendation?, avoid: MenuRecommendation?) {
            self.ideal = ideal
            self.caution = caution
            self.avoid = avoid
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            ideal = try container.decodeIfPresent(MenuRecommendation.self, forKey: .ideal)
            caution = try container.decodeIfPresent(MenuRecommendation.self, forKey: .caution)
            avoid = try container.decodeIfPresent(MenuRecommendation.self, forKey: .avoid)
            guard ideal != nil || caution != nil || avoid != nil else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "MenuAIResponse requires at least one recommendation")
                )
            }
        }
    }

    struct CookingStepEvaluation: Codable {
        let isGood: Bool
        let feedback: String
    }

    struct TransformationMetric: Codable, Identifiable, Equatable {
        let id: UUID
        let label: String
        let value: String
        let detail: String
        let isPositive: Bool

        private enum CodingKeys: String, CodingKey {
            case label, value, detail, isPositive
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = UUID()
            label = try container.decode(String.self, forKey: .label)
            value = try container.decode(String.self, forKey: .value)
            detail = try container.decode(String.self, forKey: .detail)
            isPositive = VertexAIManager.decodeFlexibleBoolIfPresent(from: container, forKey: .isPositive) ?? true
        }
    }

    struct TransformationAnalysisDTO: Codable {
        let metrics: [TransformationMetric]
        let feedback: String
    }

    private nonisolated static func decodeFlexibleBoolIfPresent<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K
    ) -> Bool? {
        if let boolVal = try? container.decodeIfPresent(Bool.self, forKey: key) {
            return boolVal
        }
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: key) {
            return intVal != 0
        }
        if let strVal = try? container.decodeIfPresent(String.self, forKey: key) {
            switch strVal.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
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
            let trimmed = strVal.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned: String
            if trimmed.range(of: #"^[+-]?\d{1,3}(,\d{3})+(\.\d+)?$"#, options: .regularExpression) != nil {
                cleaned = trimmed.replacingOccurrences(of: ",", with: "")
            } else {
                cleaned = trimmed.replacingOccurrences(of: ",", with: ".")
            }
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
        decodeFlexibleDoubleIfPresent(from: container, forKey: key).map { doubleVal in
            let rounded = doubleVal.rounded()
            let maxBound = Double(Int.max / 2)
            let minBound = Double(Int.min / 2)
            if rounded >= maxBound { return Int.max / 2 }
            if rounded <= minBound { return Int.min / 2 }
            return Int(rounded)
        }
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

    private static let mealScanSchema = AIResponseSchema([
        "type": "OBJECT",
        "properties": [
            "isFood": ["type": "BOOLEAN"],
            "errorMessage": ["type": "STRING"],
            "name": ["type": "STRING"],
            "weight": ["type": "NUMBER"],
            "calories": ["type": "INTEGER"],
            "protein": ["type": "NUMBER"],
            "fats": ["type": "NUMBER"],
            "carbs": ["type": "NUMBER"],
            "omega3": ["type": "NUMBER"],
            "calcium": ["type": "NUMBER"],
            "potassium": ["type": "NUMBER"],
            "magnesium": ["type": "NUMBER"],
            "iron": ["type": "NUMBER"],
            "vitaminC": ["type": "NUMBER"],
            "vitaminD": ["type": "NUMBER"]
        ],
        "required": ["isFood"]
    ])

    private static let menuDishSchema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "dishName": ["type": "STRING"],
            "estimatedCalories": ["type": "INTEGER"],
            "protein": ["type": "NUMBER"],
            "fats": ["type": "NUMBER"],
            "carbs": ["type": "NUMBER"],
            "reasoning": ["type": "STRING"]
        ],
        "required": ["dishName", "estimatedCalories", "protein", "reasoning"]
    ]

    private static let menuScanSchema = AIResponseSchema([
        "type": "OBJECT",
        "properties": [
            "ideal": menuDishSchema,
            "caution": menuDishSchema,
            "avoid": menuDishSchema
        ],
        "required": ["ideal", "caution", "avoid"]
    ])

    func analyzeFoodImageDetailed(_ image: UIImage) async -> FoodImageAnalysisResult {
        clearErrorState()
        guard await hasPhotoConsent() else {
            recordFailure(reason: .consentRequired, userMessage: String(localized: "AI photo analysis requires your permission."))
            return .failed
        }
        guard let base64Image = await Task.detached(priority: .userInitiated, operation: {
            Self.encodedJPEG(image, maxDimension: 1024, quality: 0.45)
        }).value else {
            recordFailure(reason: .encodingFailed, userMessage: String(localized: "Could not prepare this photo for analysis."))
            return .failed
        }

        let prompt = """
        You are an elite AI nutritionist. Analyze the image with extreme precision.
        1. Check if the image contains food or a drink. If it DOES NOT, set "isFood" to false and write a funny "errorMessage" (e.g., "That's a keyboard, not a sandwich!").
        2. If it IS food, set "isFood" to true.
        3. Identify all visible ingredients. Estimate the physical portion size (in grams) by comparing it to typical plates or hands in the frame.
        4. Calculate total calories, macros (protein, fats, carbs in grams), and key micronutrients (omega3 in g, calcium/potassium/magnesium/iron/vitaminC in mg, vitaminD in mcg). Be conservative and realistic. Account for hidden oils, butter, and dressings often used in cooking.
        5. Respond ONLY with a raw, valid JSON object. NO Markdown, NO ```json formatting, NO extra text.
        \(languageInstruction)
        Format exactly like this:
        {"isFood": true, "errorMessage": null, "name": "Avocado Toast", "weight": 150.0, "calories": 220, "protein": 5.0, "fats": 12.0, "carbs": 20.0, "omega3": 0.15, "calcium": 45.0, "potassium": 420.0, "magnesium": 32.0, "iron": 1.6, "vitaminC": 8.0, "vitaminD": 0.0}
        """

        do {
            let aiResponse = try await client.fetchJSONWithImage(
                prompt: prompt,
                base64Image: base64Image,
                mimeType: "image/jpeg",
                responseType: AIFoodResponse.self,
                responseSchema: Self.mealScanSchema
            )

            if !aiResponse.isFood {
                let reason = aiResponse.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallback = String(localized: "No food detected in this photo. Please point at a meal or drink.")
                return .notFood((reason?.isEmpty == false ? reason! : fallback))
            }

            let safeWeight = (aiResponse.weight ?? 0) > 0 ? aiResponse.weight! : 100.0
            let trimmedName = aiResponse.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName = trimmedName?.isEmpty == false ? trimmedName! : String(localized: "Unknown Meal")
            let safeCalories = max(0, aiResponse.calories ?? 0)
            let safeProtein = max(0, aiResponse.protein ?? 0)
            let safeFats = max(0, aiResponse.fats ?? 0)
            let safeCarbs = max(0, aiResponse.carbs ?? 0)

            let hasMicros = (aiResponse.omega3 ?? 0) > 0 || (aiResponse.calcium ?? 0) > 0 || (aiResponse.potassium ?? 0) > 0 || (aiResponse.magnesium ?? 0) > 0 || (aiResponse.iron ?? 0) > 0 || (aiResponse.vitaminC ?? 0) > 0 || (aiResponse.vitaminD ?? 0) > 0
            let fallbackMicros = hasMicros
                ? MicronutrientProfile.zero
                : MicronutrientEstimator.estimate(
                    name: resolvedName,
                    calories: safeCalories,
                    protein: safeProtein,
                    fat: safeFats,
                    carbs: safeCarbs,
                    weight: safeWeight
                )

            let item = FoodItem(
                name: resolvedName,
                weight: safeWeight,
                calories: safeCalories,
                protein: safeProtein,
                fats: safeFats,
                carbs: safeCarbs,
                omega3: hasMicros ? (aiResponse.omega3 ?? 0) : fallbackMicros.omega3,
                calcium: hasMicros ? (aiResponse.calcium ?? 0) : fallbackMicros.calcium,
                potassium: hasMicros ? (aiResponse.potassium ?? 0) : fallbackMicros.potassium,
                magnesium: hasMicros ? (aiResponse.magnesium ?? 0) : fallbackMicros.magnesium,
                iron: hasMicros ? (aiResponse.iron ?? 0) : fallbackMicros.iron,
                vitaminC: hasMicros ? (aiResponse.vitaminC ?? 0) : fallbackMicros.vitaminC,
                vitaminD: hasMicros ? (aiResponse.vitaminD ?? 0) : fallbackMicros.vitaminD
            )
            return .food(item)
        } catch {
            print("❌ Vertex AI Error: \(error)")
            recordFailure(for: error)
            return .failed
        }
    }

    func analyzeMenuImage(_ image: UIImage, remainingCalories: Int, targetProtein: Int) async -> MenuAIResponse? {
        clearErrorState()
        guard await hasPhotoConsent() else {
            recordFailure(reason: .consentRequired, userMessage: String(localized: "AI menu analysis requires your permission."))
            return nil
        }
        guard let base64Image = await Task.detached(priority: .userInitiated, operation: {
            Self.encodedJPEG(image, maxDimension: 1024, quality: 0.45)
        }).value else {
            recordFailure(reason: .encodingFailed, userMessage: String(localized: "Could not prepare this photo for analysis."))
            return nil
        }

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
                mimeType: "image/jpeg",
                responseType: MenuAIResponse.self,
                responseSchema: Self.menuScanSchema
            )
        } catch {
            print("❌ Menu AI Error: \(error)")
            recordFailure(for: error)
            return nil
        }
    }

    func evaluateCookingStep(image: UIImage, dishTitle: String, stepInstruction: String) async throws -> CookingStepEvaluation {
        guard await hasPhotoConsent() else {
            throw GeminiProxyError.invalidResponse
        }
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
        guard await hasPhotoConsent() else {
            throw GeminiProxyError.invalidResponse
        }
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
