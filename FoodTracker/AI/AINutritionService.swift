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
            self.wrappedValue = Int(doubleVal.rounded())
        } else if let strVal = try? container.decode(String.self),
                  let doubleVal = parseFlexibleDecimalString(strVal) {
            self.wrappedValue = Int(doubleVal.rounded())
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
}

struct AIFoodItemDTO: Codable {
    let name: String
    @FlexibleInt var calories: Int
    @FlexibleDouble var protein: Double
    @FlexibleDouble var fats: Double
    @FlexibleDouble var carbs: Double
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
}

struct AIWeeklyPlanDayDTO: Codable {
    @FlexibleInt var dayIndex: Int
    @FlexibleInt var totalCalories: Int
    @FlexibleInt var totalProtein: Int
    @FlexibleInt var totalCarbs: Int
    @FlexibleInt var totalFat: Int
    let meals: [AIWeeklyPlanItemDTO]
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
        _calories = try container.decode(FlexibleInt.self, forKey: .calories)
        _protein = try container.decode(FlexibleInt.self, forKey: .protein)
        _fat = (try? container.decodeIfPresent(FlexibleInt.self, forKey: .fat)) ?? FlexibleInt(wrappedValue: 0)
        _carbs = (try? container.decodeIfPresent(FlexibleInt.self, forKey: .carbs)) ?? FlexibleInt(wrappedValue: 0)
        _cookTime = try container.decode(FlexibleInt.self, forKey: .cookTime)
        _difficulty = try container.decode(FlexibleInt.self, forKey: .difficulty)
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
            calories = (try? container.decodeIfPresent(FlexibleInt.self, forKey: .calories))?.wrappedValue ?? 0
            protein = (try? container.decodeIfPresent(FlexibleInt.self, forKey: .protein))?.wrappedValue ?? 0
            let parsedFats = (try? container.decodeIfPresent(FlexibleInt.self, forKey: .fats))?.wrappedValue
                ?? (try? container.decodeIfPresent(FlexibleInt.self, forKey: .fat))?.wrappedValue
                ?? 0
            fats = parsedFats
            carbs = (try? container.decodeIfPresent(FlexibleInt.self, forKey: .carbs))?.wrappedValue ?? 0
            let parsedWeight = (try? container.decodeIfPresent(FlexibleDouble.self, forKey: .weight))?.wrappedValue ?? 100.0
            weight = parsedWeight > 0 ? parsedWeight : 100.0
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
    private init() {}

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
          "carbs": Double
        }
        """
        
        if let dto = await fetchFromGemini(prompt: prompt, responseType: AIFoodItemDTO.self, suppressRateLimitAlert: true) {
            return FoodItem(
                name: dto.name,
                weight: 100.0,
                calories: max(0, dto.calories),
                protein: max(0, dto.protein),
                fats: max(0, dto.fats),
                carbs: max(0, dto.carbs)
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
                    "ingredients": "String",
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
        
        if let dto = await fetchFromGemini(prompt: prompt, responseType: AIWeeklyPlanDTO.self) {
            let normalizedDays = Self.normalizedPlanDays(dto.days)
            guard !normalizedDays.isEmpty else { return nil }
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

    func getMacroFixAdvice(missingCals: Int, missingProtein: Int, missingFats: Int, missingCarbs: Int) async -> MacroFixAdviceDTO? {
        let prompt = """
        You are an elite AI Nutritionist. The user has \(missingCals) kcal left today.
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
    private let client = GeminiProxyClient.shared

    private func fetchRawTextFromGemini(prompt: String, suppressRateLimitAlert: Bool = false) async -> String? {
        do {
            return try await client.fetchText(prompt: prompt, suppressRateLimitAlert: suppressRateLimitAlert)
        } catch {
            print("❌ AI Chat Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchFromGemini<T: Codable>(prompt: String, responseType: T.Type, suppressRateLimitAlert: Bool = false) async -> T? {
        do {
            return try await client.fetchJSON(prompt: prompt, responseType: responseType, suppressRateLimitAlert: suppressRateLimitAlert)
        } catch {
            // The client already logs detailed decode/raw info on failure.
            print("❌ AI Service Exception: \(error.localizedDescription)")
            return nil
        }
    }
}
