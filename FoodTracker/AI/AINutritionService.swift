import Foundation
import FirebaseAuth
import FirebaseAppCheck

private func parseFlexibleDecimalString(_ raw: String) -> Double? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let clean: String
    if trimmed.range(of: #"^\d{1,3}(,\d{3})+(\.\d+)?$"#, options: .regularExpression) != nil {
        clean = trimmed.replacingOccurrences(of: ",", with: "")
    } else {
        clean = trimmed.replacingOccurrences(of: ",", with: ".")
    }
    guard let parsed = Double(clean), parsed.isFinite else { return nil }
    return parsed
}

private func safeClampedInt(from doubleVal: Double) -> Int {
    guard doubleVal.isFinite else { return 0 }
    let rounded = doubleVal.rounded()
    let maxBound = Double(Int.max / 2)
    let minBound = Double(Int.min / 2)
    if rounded >= maxBound { return Int.max / 2 }
    if rounded <= minBound { return Int.min / 2 }
    return Int(rounded)
}

private func clampCalories(_ value: Int) -> Int {
    min(max(0, value), 50_000)
}

private func clampMacro(_ value: Double) -> Double {
    guard value.isFinite else { return 0 }
    return min(max(0.0, value), 10_000.0)
}

private func clampMacroInt(_ value: Int) -> Int {
    min(max(0, value), 10_000)
}

@propertyWrapper
struct FlexibleInt: Codable, Hashable {
    var wrappedValue: Int

    init(wrappedValue: Int) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self.wrappedValue = intVal
        } else if let doubleVal = try? container.decode(Double.self), doubleVal.isFinite {
            self.wrappedValue = safeClampedInt(from: doubleVal)
        } else if let strVal = try? container.decode(String.self),
                  let doubleVal = parseFlexibleDecimalString(strVal) {
            self.wrappedValue = safeClampedInt(from: doubleVal)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected numeric value for FlexibleInt")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

@propertyWrapper
struct FlexibleDouble: Codable, Hashable {
    var wrappedValue: Double

    init(wrappedValue: Double) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let doubleVal = try? container.decode(Double.self), doubleVal.isFinite {
            self.wrappedValue = doubleVal
        } else if let intVal = try? container.decode(Int.self) {
            self.wrappedValue = Double(intVal)
        } else if let strVal = try? container.decode(String.self),
                  let parsed = parseFlexibleDecimalString(strVal) {
            self.wrappedValue = parsed
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected numeric value for FlexibleDouble")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

struct DailyVerdictDTO: Codable {
    let title: String
    let message: String
    let mood: String
}

struct AIRecipeDTO: Codable {
    let name: String
    let info: String
    @FlexibleInt var calories: Int
    @FlexibleDouble var protein: Double
    @FlexibleDouble var fats: Double
    @FlexibleDouble var carbs: Double
    @FlexibleInt var cookingTime: Int

    private enum CodingKeys: String, CodingKey {
        case name, info, calories, protein, fats, carbs, cookingTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        info = try container.decode(String.self, forKey: .info)
        let rawCals = try container.decode(FlexibleInt.self, forKey: .calories).wrappedValue
        let rawProt = try container.decode(FlexibleDouble.self, forKey: .protein).wrappedValue
        let rawFats = try container.decode(FlexibleDouble.self, forKey: .fats).wrappedValue
        let rawCarbs = try container.decode(FlexibleDouble.self, forKey: .carbs).wrappedValue
        let rawTime = try container.decode(FlexibleInt.self, forKey: .cookingTime).wrappedValue
        _calories = FlexibleInt(wrappedValue: clampCalories(rawCals))
        _protein = FlexibleDouble(wrappedValue: clampMacro(rawProt))
        _fats = FlexibleDouble(wrappedValue: clampMacro(rawFats))
        _carbs = FlexibleDouble(wrappedValue: clampMacro(rawCarbs))
        _cookingTime = FlexibleInt(wrappedValue: min(max(0, rawTime), 1440))
    }
}

struct AIFoodItemDTO: Codable {
    let name: String
    @FlexibleInt var calories: Int
    @FlexibleDouble var protein: Double
    @FlexibleDouble var fats: Double
    @FlexibleDouble var carbs: Double
    let omega3: Double?
    let calcium: Double?
    let potassium: Double?
    let magnesium: Double?
    let iron: Double?
    let vitaminC: Double?
    let vitaminD: Double?

    private enum CodingKeys: String, CodingKey {
        case name, calories, protein, fats, carbs
        case omega3, calcium, potassium, magnesium, iron, vitaminC, vitaminD
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        _calories = FlexibleInt(wrappedValue: clampCalories(try container.decode(FlexibleInt.self, forKey: .calories).wrappedValue))
        _protein = FlexibleDouble(wrappedValue: clampMacro(try container.decode(FlexibleDouble.self, forKey: .protein).wrappedValue))
        _fats = FlexibleDouble(wrappedValue: clampMacro(try container.decode(FlexibleDouble.self, forKey: .fats).wrappedValue))
        _carbs = FlexibleDouble(wrappedValue: clampMacro(try container.decode(FlexibleDouble.self, forKey: .carbs).wrappedValue))
        omega3 = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .omega3))?.wrappedValue.mapNonNegative(max: 1_000.0)
        calcium = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .calcium))?.wrappedValue.mapNonNegative(max: 10_000.0)
        potassium = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .potassium))?.wrappedValue.mapNonNegative(max: 20_000.0)
        magnesium = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .magnesium))?.wrappedValue.mapNonNegative(max: 10_000.0)
        iron = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .iron))?.wrappedValue.mapNonNegative(max: 1_000.0)
        vitaminC = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .vitaminC))?.wrappedValue.mapNonNegative(max: 10_000.0)
        vitaminD = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .vitaminD))?.wrappedValue.mapNonNegative(max: 1_000.0)
    }
}

private extension Double {
    func mapNonNegative(max upper: Double) -> Double {
        guard isFinite else { return 0 }
        return Swift.min(Swift.max(0.0, self), upper)
    }
}

struct AIWeeklyPlanItemDTO: Codable {
    let title: String
    let type: String
    @FlexibleInt var calories: Int
    @FlexibleInt var protein: Int
    @FlexibleInt var carbs: Int
    @FlexibleInt var fat: Int
    let ingredients: String
    let instructions: String
    @FlexibleInt var prepTimeMinutes: Int

    private enum CodingKeys: String, CodingKey {
        case title, type, calories, protein, carbs, fat, ingredients, instructions, prepTimeMinutes
    }

    init(
        title: String,
        type: String,
        calories: Int,
        protein: Int,
        carbs: Int,
        fat: Int,
        ingredients: String,
        instructions: String,
        prepTimeMinutes: Int
    ) {
        self.title = title
        self.type = type
        self._calories = FlexibleInt(wrappedValue: clampCalories(calories))
        self._protein = FlexibleInt(wrappedValue: clampMacroInt(protein))
        self._carbs = FlexibleInt(wrappedValue: clampMacroInt(carbs))
        self._fat = FlexibleInt(wrappedValue: clampMacroInt(fat))
        self.ingredients = ingredients
        self.instructions = instructions
        self._prepTimeMinutes = FlexibleInt(wrappedValue: min(max(0, prepTimeMinutes), 1440))
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        type = try container.decode(String.self, forKey: .type)
        _calories = FlexibleInt(wrappedValue: clampCalories(try container.decode(FlexibleInt.self, forKey: .calories).wrappedValue))
        _protein = FlexibleInt(wrappedValue: clampMacroInt(try container.decode(FlexibleInt.self, forKey: .protein).wrappedValue))
        _carbs = FlexibleInt(wrappedValue: clampMacroInt(try container.decode(FlexibleInt.self, forKey: .carbs).wrappedValue))
        _fat = FlexibleInt(wrappedValue: clampMacroInt(try container.decode(FlexibleInt.self, forKey: .fat).wrappedValue))
        ingredients = try container.decode(String.self, forKey: .ingredients)
        instructions = try container.decode(String.self, forKey: .instructions)
        _prepTimeMinutes = FlexibleInt(wrappedValue: min(max(0, try container.decode(FlexibleInt.self, forKey: .prepTimeMinutes).wrappedValue), 1440))
    }
}

struct AIWeeklyPlanDayDTO: Codable {
    @FlexibleInt var dayIndex: Int
    @FlexibleInt var totalCalories: Int
    @FlexibleInt var totalProtein: Int
    @FlexibleInt var totalCarbs: Int
    @FlexibleInt var totalFat: Int
    let meals: [AIWeeklyPlanItemDTO]

    private enum CodingKeys: String, CodingKey {
        case dayIndex, totalCalories, totalProtein, totalCarbs, totalFat, meals
    }

    init(
        dayIndex: Int,
        totalCalories: Int,
        totalProtein: Int,
        totalCarbs: Int,
        totalFat: Int,
        meals: [AIWeeklyPlanItemDTO]
    ) {
        self._dayIndex = FlexibleInt(wrappedValue: dayIndex)
        self._totalCalories = FlexibleInt(wrappedValue: clampCalories(totalCalories))
        self._totalProtein = FlexibleInt(wrappedValue: clampMacroInt(totalProtein))
        self._totalCarbs = FlexibleInt(wrappedValue: clampMacroInt(totalCarbs))
        self._totalFat = FlexibleInt(wrappedValue: clampMacroInt(totalFat))
        self.meals = meals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _dayIndex = try container.decode(FlexibleInt.self, forKey: .dayIndex)
        _totalCalories = FlexibleInt(wrappedValue: clampCalories(try container.decode(FlexibleInt.self, forKey: .totalCalories).wrappedValue))
        _totalProtein = FlexibleInt(wrappedValue: clampMacroInt(try container.decode(FlexibleInt.self, forKey: .totalProtein).wrappedValue))
        _totalCarbs = FlexibleInt(wrappedValue: clampMacroInt(try container.decode(FlexibleInt.self, forKey: .totalCarbs).wrappedValue))
        _totalFat = FlexibleInt(wrappedValue: clampMacroInt(try container.decode(FlexibleInt.self, forKey: .totalFat).wrappedValue))
        meals = try container.decode([AIWeeklyPlanItemDTO].self, forKey: .meals)
    }
}

struct AIWeeklyPlanDTO: Codable {
    let days: [AIWeeklyPlanDayDTO]
}

struct AIChefRecipeDTO: Codable {
    let title: String
    @FlexibleInt var calories: Int
    @FlexibleInt var protein: Int
    @FlexibleInt var fat: Int
    @FlexibleInt var carbs: Int
    @FlexibleInt var cookTime: Int
    @FlexibleInt var difficulty: Int
    let history: String
    let ingredients: [String]
    let steps: [RecipeStepDTO]
    let platingTip: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        _calories = FlexibleInt(wrappedValue: clampCalories(try container.decode(FlexibleInt.self, forKey: .calories).wrappedValue))
        _protein = FlexibleInt(wrappedValue: clampMacroInt(try container.decode(FlexibleInt.self, forKey: .protein).wrappedValue))
        _fat = FlexibleInt(wrappedValue: clampMacroInt((try? container.decodeIfPresent(FlexibleInt.self, forKey: .fat))?.wrappedValue ?? 0))
        _carbs = FlexibleInt(wrappedValue: clampMacroInt((try? container.decodeIfPresent(FlexibleInt.self, forKey: .carbs))?.wrappedValue ?? 0))
        _cookTime = FlexibleInt(wrappedValue: min(max(0, try container.decode(FlexibleInt.self, forKey: .cookTime).wrappedValue), 1440))
        _difficulty = FlexibleInt(wrappedValue: min(max(1, try container.decode(FlexibleInt.self, forKey: .difficulty).wrappedValue), 5))
        history = try container.decode(String.self, forKey: .history)
        ingredients = try container.decode([String].self, forKey: .ingredients)
        steps = try container.decode([RecipeStepDTO].self, forKey: .steps)
        platingTip = try container.decode(String.self, forKey: .platingTip)
    }
}

struct RecipeStepDTO: Codable {
    let instruction: String
    let aiTip: String?
}

struct MacroFixAdviceDTO: Codable, Identifiable {
    let id = UUID()
    let title: String
    let explanation: String
    let suggestedSnacks: [SnackIdea]

    private enum CodingKeys: String, CodingKey {
        case title, explanation, suggestedSnacks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        explanation = try container.decode(String.self, forKey: .explanation)
        suggestedSnacks = (try? container.decodeIfPresent([SnackIdea].self, forKey: .suggestedSnacks)) ?? []
    }

    struct SnackIdea: Codable, Hashable {
        let name: String
        let calories: Int
        let protein: Int
        let fats: Int
        let carbs: Int
        let weight: Double

        private enum CodingKeys: String, CodingKey {
            case name, calories, protein, fats, fat, carbs, weight
        }

        init(name: String, calories: Int, protein: Int, fats: Int = 0, carbs: Int = 0, weight: Double = 100.0) {
            self.name = name
            self.calories = calories
            self.protein = protein
            self.fats = fats
            self.carbs = carbs
            self.weight = weight
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            calories = clampCalories((try? container.decodeIfPresent(FlexibleInt.self, forKey: .calories))?.wrappedValue ?? 0)
            protein = clampMacroInt((try? container.decodeIfPresent(FlexibleInt.self, forKey: .protein))?.wrappedValue ?? 0)
            let parsedFats = (try? container.decodeIfPresent(FlexibleInt.self, forKey: .fats))?.wrappedValue
                ?? (try? container.decodeIfPresent(FlexibleInt.self, forKey: .fat))?.wrappedValue
                ?? 0
            fats = clampMacroInt(parsedFats)
            carbs = clampMacroInt((try? container.decodeIfPresent(FlexibleInt.self, forKey: .carbs))?.wrappedValue ?? 0)
            let parsedWeight = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .weight))?.wrappedValue ?? 100.0
            weight = parsedWeight > 0 ? min(parsedWeight, 50_000.0) : 100.0
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encode(calories, forKey: .calories)
            try container.encode(protein, forKey: .protein)
            try container.encode(fats, forKey: .fats)
            try container.encode(carbs, forKey: .carbs)
            try container.encode(weight, forKey: .weight)
        }
    }
}

struct HydrationAdviceDTO: Codable, Identifiable {
    let id = UUID()
    let title: String
    let message: String
    @FlexibleInt var nextGlassTimeMinutes: Int

    private enum CodingKeys: String, CodingKey {
        case title, message, nextGlassTimeMinutes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        let decodedMinutes = (try? container.decodeIfPresent(FlexibleInt.self, forKey: .nextGlassTimeMinutes))?.wrappedValue
        self._nextGlassTimeMinutes = FlexibleInt(wrappedValue: decodedMinutes ?? 30)
    }
}

struct MoodAdviceDTO: Codable {
    let title: String
    let message: String
}

class AINutritionService {
    static let shared = AINutritionService()

    init(
        proxy: any GeminiProxyExecuting = GeminiProxyClient.shared,
        consentProvider: @escaping @Sendable () async -> Bool = {
            await MainActor.run { AIPhotoConsentManager.shared.hasConsented }
        }
    ) {
        self.client = proxy
        self.consentProvider = consentProvider
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

    private let consentProvider: @Sendable () async -> Bool

    func generateDailyVerdict(consumed: Int, goal: Int, protein: Double, targetProtein: Double) async -> DailyVerdictDTO? {
        let prompt = """
        You are a witty, elite AI Nutrition Coach.
        The user's daily calorie goal is \(goal) kcal. They have consumed \(consumed) kcal so far.
        Their daily protein target is \(Int(targetProtein))g. They have consumed \(Int(protein))g so far.

        Analyze this data. Write a short, punchy 2-sentence verdict.
        - If they are doing great, mood is "perfect".
        - If they need to eat more/less to hit goals, mood is "warning".
        - If they heavily ruined their diet (huge surplus), mood is "danger".

        - Keep ALL JSON keys AND the "mood" field value strictly in English ("perfect", "warning", or "danger"), while writing "title" and "message" exclusively in \(currentLanguage).
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
        \(languageInstruction)
        Return ONLY a raw JSON object. No Markdown. Format:
        {"name": "String", "info": "Short description of how to cook it", "calories": Int, "protein": Double, "fats": Double, "carbs": Double, "cookingTime": Int}
        """
        return await fetchFromGemini(prompt: prompt, responseType: AIRecipeDTO.self)
    }

    func generateCookingSteps(for mealName: String, ingredients: [String]) async -> AIChefRecipeDTO? {
        let ingredientsString = ingredients.joined(separator: ", ")
        let prompt = """
        You are a Michelin-star AI Chef. The user wants to cook a meal called "\(mealName)" using these exact ingredients: \(ingredientsString).
        Generate a highly structured, step-by-step recipe.
        \(languageInstruction)
        Provide the response STRICTLY as a raw JSON object (no markdown formatting, no ```json tags).
        Use this exact schema:
        {
          "title": "String (a creative name for the dish)",
          "calories": Int (estimated total calories per serving),
          "protein": Int (estimated protein in grams per serving),
          "fat": Int (estimated fat in grams per serving),
          "carbs": Int (estimated carbs in grams per serving),
          "cookTime": Int (estimated cooking time in minutes),
          "difficulty": Int (1 to 5),
          "history": "String (a short fun fact or history about this dish or ingredients)",
          "ingredients": ["String"],
          "steps": [
            {
              "instruction": "String (clear cooking instruction)",
              "aiTip": "String (optional pro-tip for this step, can be null)"
            }
          ],
          "platingTip": "String (how to beautifully plate it)"
        }
        """
        
        return await fetchFromGemini(prompt: prompt, responseType: AIChefRecipeDTO.self)
    }

    func generateFoodItem(for query: String) async -> FoodItem? {
        let prompt = """
        You are an expert nutritionist database. The user searched for "\(query)" but it wasn't found in our API.
        Estimate the macronutrients for exactly 100 grams of this food.
        \(languageInstruction)
        Provide the response STRICTLY as a raw JSON object (no markdown formatting, no ```json tags).
        Use this exact schema:
        {
          "name": "String (concise localized food name)",
          "calories": Int,
          "protein": Double,
          "fats": Double,
          "carbs": Double,
          "omega3": Double,
          "calcium": Double,
          "potassium": Double,
          "magnesium": Double,
          "iron": Double,
          "vitaminC": Double,
          "vitaminD": Double
        }
        """
        
        if let dto = await fetchFromGemini(prompt: prompt, responseType: AIFoodItemDTO.self, suppressRateLimitAlert: true) {
            let safeCalories = max(0, dto.calories)
            let safeProtein = max(0, dto.protein)
            let safeFats = max(0, dto.fats)
            let safeCarbs = max(0, dto.carbs)
            let o3 = max(0, dto.omega3 ?? 0)
            let ca = max(0, dto.calcium ?? 0)
            let k = max(0, dto.potassium ?? 0)
            let mg = max(0, dto.magnesium ?? 0)
            let fe = max(0, dto.iron ?? 0)
            let vitC = max(0, dto.vitaminC ?? 0)
            let vitD = max(0, dto.vitaminD ?? 0)
            let fallback = MicronutrientEstimator.estimate(
                name: dto.name,
                calories: safeCalories,
                protein: safeProtein,
                fat: safeFats,
                carbs: safeCarbs,
                weight: 100.0
            )
            return FoodItem(
                name: dto.name,
                weight: 100.0,
                calories: safeCalories,
                protein: safeProtein,
                fats: safeFats,
                carbs: safeCarbs,
                omega3: o3 > 0 ? o3 : fallback.omega3,
                calcium: ca > 0 ? ca : fallback.calcium,
                potassium: k > 0 ? k : fallback.potassium,
                magnesium: mg > 0 ? mg : fallback.magnesium,
                iron: fe > 0 ? fe : fallback.iron,
                vitaminC: vitC > 0 ? vitC : fallback.vitaminC,
                vitaminD: vitD > 0 ? vitD : fallback.vitaminD
            )
        }
        return nil
    }

    func generateWeeklyPlan(targetCalories: Int, diet: String, complexity: String) async -> WeeklyMealPlan? {
        let prompt = """
        You are an elite nutritionist. Generate a 7-day meal plan (0 to 6) following these constraints:
        - Target Calories per day: exactly \(targetCalories) kcal
        - Diet Type: \(diet)
        - Cooking Complexity: \(complexity)
        
        Generate exactly 4 meals per day: Breakfast, Lunch, Dinner, Snack.
        \(languageInstruction)
        Provide the response STRICTLY as a raw JSON object matching this schema:
        {
          "days": [
             {
               "dayIndex": Int (0-6),
               "totalCalories": Int,
               "totalProtein": Int,
               "totalCarbs": Int,
               "totalFat": Int,
               "meals": [
                  {
                    "title": "String",
                    "type": "Breakfast | Lunch | Dinner | Snack",
                    "calories": Int,
                    "protein": Int,
                    "carbs": Int,
                    "fat": Int,
                    "ingredients": "Comma-separated String (e.g. \"2 eggs, 50g spinach, 1 tbsp olive oil\")",
                    "instructions": "String",
                    "prepTimeMinutes": Int
                  }
               ]
             }
          ]
        }
        CRITICAL: Keep JSON keys and "type" values strictly in English ("Breakfast", "Lunch", "Dinner", "Snack"). Translate ONLY "title", "ingredients", and "instructions".
        Do not include markdown tags. Only output the raw JSON. Ensure all arrays have 7 items for days, and 4 items for meals.
        """
        
        if let dto = await fetchFromGemini(prompt: prompt, responseType: AIWeeklyPlanDTO.self, maxOutputTokens: 8192) {
            let normalizedDays = Self.normalizedPlanDays(dto.days)
            guard Self.isCompleteWeeklyPlan(normalizedDays) else { return nil }
            let plan = WeeklyMealPlan(targetCalories: targetCalories, dietType: diet)

            for dayDTO in normalizedDays {
                let day = MealPlanDay(
                    dayIndex: dayDTO.dayIndex,
                    totalCalories: dayDTO.totalCalories,
                    totalProtein: dayDTO.totalProtein,
                    totalCarbs: dayDTO.totalCarbs,
                    totalFat: dayDTO.totalFat
                )
                
                for mealDTO in dayDTO.meals {
                    let meal = MealPlanItem(
                        title: mealDTO.title,
                        type: mealDTO.type,
                        calories: mealDTO.calories,
                        protein: mealDTO.protein,
                        carbs: mealDTO.carbs,
                        fat: mealDTO.fat,
                        ingredients: mealDTO.ingredients,
                        instructions: mealDTO.instructions,
                        prepTimeMinutes: mealDTO.prepTimeMinutes
                    )
                    day.addMeal(meal)
                }
                
                plan.addDay(day)
            }
            return plan
        }
        return nil
    }

    /// Normalizes LLM-emitted day indices (e.g. 1...7, duplicate, or unsorted days) to sequential 0...6 order.
    static func normalizedPlanDays(_ days: [AIWeeklyPlanDayDTO]) -> [AIWeeklyPlanDayDTO] {
        let isOneBased = !days.isEmpty
            && !days.contains(where: { $0.dayIndex == 0 })
            && days.contains(where: { $0.dayIndex == 7 })
            && days.allSatisfy { (1...7).contains($0.dayIndex) }

        let remapped = days.compactMap { dto -> AIWeeklyPlanDayDTO? in
            let normalizedIndex = isOneBased ? (dto.dayIndex - 1) : dto.dayIndex
            guard (0..<7).contains(normalizedIndex) else { return nil }
            return AIWeeklyPlanDayDTO(
                dayIndex: normalizedIndex,
                totalCalories: dto.totalCalories,
                totalProtein: dto.totalProtein,
                totalCarbs: dto.totalCarbs,
                totalFat: dto.totalFat,
                meals: dto.meals
            )
        }

        var seenIndices: Set<Int> = []
        return remapped
            .sorted { $0.dayIndex < $1.dayIndex }
            .filter { seenIndices.insert($0.dayIndex).inserted }
    }

    static func isCompleteWeeklyPlan(_ days: [AIWeeklyPlanDayDTO]) -> Bool {
        let normalized = normalizedPlanDays(days)
        guard normalized.count == 7 else { return false }
        let expectedIndices = Set(0..<7)
        guard Set(normalized.map(\.dayIndex)) == expectedIndices else { return false }
        return normalized.allSatisfy { !$0.meals.isEmpty }
    }

    func sendChatMessage(prompt: String, userContext: String, activeDiet: String, history: [AIChatMessage] = []) async -> String? {
          let recentHistory = history.suffix(8).map { msg in
              "\(msg.isUser ? "USER" : "COACH"): \(msg.text)"
          }.joined(separator: "\n")
          let historyBlock = recentHistory.isEmpty ? "" : "\nRecent conversation:\n\(recentHistory)\n"
          let systemPrompt = """
          You are a friendly, elite AI Nutritionist.
          Context about the user today: \(userContext)
          CRITICAL: The user is currently strictly following the "\(activeDiet)" diet.
          Tailor all your advice, food suggestions, and judgments based on the rules of the \(activeDiet) diet.
          \(historyBlock)
          USER SAYS: "\(prompt)"

          Respond conversationally, warmly, and concisely. Keep answers under 4 sentences.
          If they ask if they can eat something, check their remaining calories from the context and give advice based on their \(activeDiet) diet.
          \(languageInstruction)
          """
          return await fetchRawTextFromGemini(prompt: systemPrompt)
      }

    func generateChatTitle(for userMessage: String) async -> String {
        let systemPrompt = "Create a very short title (max 2-3 words) for a nutrition chat based on this first message: '\(userMessage)'. Return ONLY the text without quotes. \(languageInstruction)"
        return await fetchRawTextFromGemini(prompt: systemPrompt, suppressRateLimitAlert: true) ?? String(localized: "Diet Chat")
    }

    func getMacroFixAdvice(
        missingCals: Int,
        missingProtein: Int,
        missingFats: Int,
        missingCarbs: Int,
        activeDiet: String = "Balanced"
    ) async -> MacroFixAdviceDTO? {
        let prompt = """
        You are an elite AI Nutritionist. Active diet: \(activeDiet). The user has \(missingCals) kcal left today.
        They need roughly \(missingProtein)g protein, \(missingFats)g fats, and \(missingCarbs)g carbs to hit their goal perfectly.

        If missingCals is negative, they overate. Tell them gently how to recover.
        If missingCals is positive, suggest exactly 3 quick, realistic snacks/meals to hit these remaining macros perfectly.

        \(languageInstruction)
        Respond ONLY with a raw, valid JSON object. No Markdown. Format exactly:
        {
          "title": "Short punchy title",
          "explanation": "1 short sentence explaining what to focus on",
          "suggestedSnacks": [
            {"name": "Greek Yogurt with Almonds", "calories": 200, "protein": 15, "fats": 8, "carbs": 14, "weight": 200}
          ]
        }
        """
        return await fetchFromGemini(prompt: prompt, responseType: MacroFixAdviceDTO.self)
    }

    func getHydrationAdvice(drankLiters: Double, goalLiters: Double) async -> HydrationAdviceDTO? {
        let prompt = """
        You are a Hydration AI Coach. The user drank \(drankLiters)L out of their \(goalLiters)L goal today.

        Write a short, motivating message. If they reached the goal, praise them. If not, tell them exactly how much is left and when to drink next.

        \(languageInstruction)
        Respond ONLY with a raw, valid JSON object. No Markdown. Format exactly:
        {
          "title": "Stay Hydrated / Great Job",
          "message": "Short motivating advice",
          "nextGlassTimeMinutes": 30
        }
        """
        return await fetchFromGemini(prompt: prompt, responseType: HydrationAdviceDTO.self)
    }

    func getMoodAdvice(
        moodEmoji: String,
        moodName: String,
        note: String,
        consumedCalories: Int,
        goalCalories: Int,
        waterLiters: Double,
        activeDiet: String
    ) async -> MoodAdviceDTO? {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteLine = trimmedNote.isEmpty ? "" : "Journal note: \"\(trimmedNote)\"."
        let prompt = """
        You are an empathetic, smart AI Nutrition & Wellness Coach.
        User's selected mood: \(moodName) \(moodEmoji).
        Today's nutrition: \(consumedCalories) / \(goalCalories) kcal consumed, \(String(format: "%.1f", waterLiters))L water, diet: \(activeDiet).
        \(noteLine)

        Write a warm, practical title (2-4 words) and concise 2-sentence advice tailored to their mood and nutrition status. No guilt-tripping on cheat/binge days; offer calm, actionable next steps.
        \(languageInstruction)
        Respond ONLY with a raw JSON object. No Markdown:
        {"title": "Short encouraging title", "message": "2 concise, helpful sentences."}
        """
        return await fetchFromGemini(prompt: prompt, responseType: MoodAdviceDTO.self, suppressRateLimitAlert: true)
    }

    func generateChefRecipe(dishQuery: String, remainingCalories: Int, activeDiet: String) async -> AIChefRecipe? {
        let prompt = """
        You are a Michelin-star AI Chef and nutritionist.
        The user wants to cook: "\(dishQuery)".
        Remaining calories today: \(remainingCalories) kcal. Active diet: \(activeDiet).
        Create a tailored, step-by-step recipe with accurate macros per serving.
        \(languageInstruction)
        Respond ONLY with a raw JSON object matching this exact schema (no Markdown):
        {
          "title": "String",
          "calories": Int,
          "protein": Int,
          "fat": Int,
          "carbs": Int,
          "cookTime": Int,
          "difficulty": Int (1 to 5),
          "history": "String (1-2 intriguing culinary sentences)",
          "ingredients": ["String (ingredient with exact gram/ml amount)"],
          "steps": [
            {"instruction": "String", "aiTip": "String or null"}
          ],
          "platingTip": "String"
        }
        """

        guard let dto = await fetchFromGemini(prompt: prompt, responseType: AIChefRecipeDTO.self) else {
            return nil
        }
        let stepIcons = ["hand.draw.fill", "sparkles", "flame.fill", "drop.fill", "clock.fill"]
        let steps = dto.steps.enumerated().map { idx, stepDTO in
            RecipeStep(instruction: stepDTO.instruction, imageName: stepIcons[idx % stepIcons.count], aiTip: stepDTO.aiTip)
        }
        return AIChefRecipe(
            title: dto.title,
            calories: dto.calories,
            protein: dto.protein,
            fat: dto.fat,
            carbs: dto.carbs,
            heroImage: "fork.knife",
            cookTime: dto.cookTime,
            difficulty: dto.difficulty,
            history: dto.history,
            ingredients: dto.ingredients,
            steps: steps,
            platingTip: dto.platingTip
        )
    }

    // All transport, auth, and parsing now lives in the shared client.
    // This removes massive duplication with VertexAIManager.
    private let client: any GeminiProxyExecuting

    private func fetchRawTextFromGemini(prompt: String, suppressRateLimitAlert: Bool = false) async -> String? {
        guard await consentProvider() else { return nil }
        do {
            return try await client.fetchText(prompt: prompt, suppressRateLimitAlert: suppressRateLimitAlert)
        } catch {
            print("❌ AI Chat Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchFromGemini<T: Codable>(
        prompt: String,
        responseType: T.Type,
        maxOutputTokens: Int? = nil,
        suppressRateLimitAlert: Bool = false
    ) async -> T? {
        guard await consentProvider() else { return nil }
        do {
            return try await client.fetchJSON(
                prompt: prompt,
                responseType: responseType,
                maxOutputTokens: maxOutputTokens,
                suppressRateLimitAlert: suppressRateLimitAlert
            )
        } catch {
            // The client already logs detailed decode/raw info on failure.
            print("❌ AI Service Exception: \(error.localizedDescription)")
            return nil
        }
    }
}
