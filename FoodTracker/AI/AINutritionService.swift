import Foundation
import FirebaseAuth
import FirebaseAppCheck
struct DailyVerdictDTO: Codable {
    let title: String
    let message: String
    let mood: String
}

struct AIRecipeDTO: Codable {
    let name: String
    let info: String
    let calories: Int
    let protein: Double
    let fats: Double
    let carbs: Double
    let omega3: Double?
    let calcium: Double?
    let potassium: Double?
    let magnesium: Double?
    let iron: Double?
    let vitaminC: Double?
    let vitaminD: Double?
    let cookingTime: Int
}

struct AIFoodItemDTO: Codable {
    let name: String
    let calories: Int
    let protein: Double
    let fats: Double
    let carbs: Double
    let omega3: Double
    let calcium: Double
    let potassium: Double
    let magnesium: Double
    let iron: Double
    let vitaminC: Double
    let vitaminD: Double
}

struct AIWeeklyPlanItemDTO: Codable {
    let title: String?
    let type: String?
    let calories: Int?
    let protein: Int?
    let carbs: Int?
    let fat: Int?
    let omega3: Double?
    let calcium: Double?
    let potassium: Double?
    let magnesium: Double?
    let iron: Double?
    let vitaminC: Double?
    let vitaminD: Double?
    let ingredients: String?
    let instructions: String?
    let prepTimeMinutes: Int?
}

struct AIWeeklyPlanDayDTO: Codable {
    let dayIndex: Int?
    let totalCalories: Int?
    let totalProtein: Int?
    let totalCarbs: Int?
    let totalFat: Int?
    let meals: [AIWeeklyPlanItemDTO]?
}

struct AIWeeklyPlanDTO: Codable {
    let days: [AIWeeklyPlanDayDTO]
}

struct AIChefRecipeDTO: Codable {
    let title: String
    let calories: Int
    let protein: Int
    let cookTime: Int
    let difficulty: Int
    let history: String
    let ingredients: [String]
    let steps: [RecipeStepDTO]
    let platingTip: String
}

struct RecipeStepDTO: Codable {
    let instruction: String
    let aiTip: String?
}

struct MacroFixAdviceDTO: Codable, Identifiable {
    var id: UUID { UUID() }
    let title: String
    let explanation: String
    let suggestedSnacks: [SnackIdea]

    struct SnackIdea: Codable, Hashable {
        let name: String
        let calories: Int
        let protein: Int
    }
}

struct HydrationAdviceDTO: Codable, Identifiable {
    var id: UUID { UUID() }
    let title: String
    let message: String
    let nextGlassTimeMinutes: Int
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
        {"name": "String", "info": "String (a short 1-2 word tag like 'High Protein', 'Keto', or 'Healthy')", "calories": Int, "protein": Double, "fats": Double, "carbs": Double, "cookingTime": Int}
        """
        return await fetchFromGemini(prompt: prompt, responseType: AIRecipeDTO.self)
    }

    func generateCookingSteps(for mealName: String, ingredients: [String]) async -> AIChefRecipeDTO? {
        let ingredientsString = ingredients.joined(separator: ", ")
        let prompt = """
        You are a Michelin-star AI Chef. The user wants to cook a meal called "\(mealName)" using these exact ingredients: \(ingredientsString).
        Generate a highly structured, step-by-step recipe.
        Provide the response STRICTLY as a raw JSON object (no markdown formatting, no ```json tags).
        Use this exact schema:
        {
          "title": "String (a creative name for the dish)",
          "calories": Int (estimated total calories),
          "protein": Int (estimated total protein in grams),
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
        Provide the response STRICTLY as a raw JSON object (no markdown formatting, no ```json tags).
        Use this exact schema:
        {
          "name": "String (best name for the food in Russian or English)",
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
        
        if let dto = await fetchFromGemini(prompt: prompt, responseType: AIFoodItemDTO.self) {
            return FoodItem(
                name: dto.name,
                weight: 100.0,
                calories: dto.calories,
                protein: dto.protein,
                fats: dto.fats,
                carbs: dto.carbs,
                omega3: dto.omega3,
                calcium: dto.calcium,
                potassium: dto.potassium,
                magnesium: dto.magnesium,
                iron: dto.iron,
                vitaminC: dto.vitaminC,
                vitaminD: dto.vitaminD
            )
        }
        return nil
    }

    private func dietRules(for diet: String) -> String {
        switch diet {
        case "Keto":
            return "Keto diet: carbs MUST be under 50g per day total. High fat (60-75% of calories). Moderate protein (20-30%). Strictly avoid: bread, pasta, rice, potatoes, sugar, fruit (except berries in small amounts), legumes, grains."
        case "Vegan":
            return "Vegan diet: absolutely NO animal products. No meat, fish, eggs, dairy, honey. Protein sources: tofu, tempeh, lentils, chickpeas, black beans, edamame, quinoa, hemp seeds, nutritional yeast."
        case "Vegetarian":
            return "Vegetarian diet: NO meat or fish. Eggs and dairy are allowed. Protein sources: eggs, cheese, yogurt, tofu, legumes, paneer."
        case "Paleo":
            return "Paleo diet: only whole foods our ancestors ate. Allowed: meat, fish, eggs, vegetables, fruits, nuts, seeds, olive oil. Strictly avoid: grains, legumes, dairy, processed foods, refined sugar, seed oils."
        case "Pescatarian":
            return "Pescatarian diet: fish and seafood allowed, NO other meat (no chicken, beef, pork). Eggs and dairy are fine. Feature fish and seafood prominently in at least 2 meals per day."
        case "Mediterranean":
            return "Mediterranean diet: emphasize olive oil, vegetables, whole grains, legumes, fish (3+ times a week), moderate dairy, limited red meat (max once a week). Use herbs and spices generously."
        case "High Protein":
            return "High Protein diet: protein MUST be at least 40% of total calories. Every single meal must have a substantial protein source: chicken breast, turkey, lean beef, eggs, Greek yogurt, cottage cheese, fish, protein powder. Minimize processed carbs."
        case "Low Carb":
            return "Low Carb diet: total daily carbs must be under 100g. Prioritize protein and healthy fats. Avoid: bread, pasta, rice, potatoes, sugar, juice. Focus on: vegetables, meat, fish, eggs, nuts, cheese."
        default:
            return "Balanced diet: varied and nutritious meals with all macronutrients well-represented. No restrictions. Include a variety of proteins, complex carbs, healthy fats, and plenty of vegetables."
        }
    }
    
    private func complexityRules(for complexity: String) -> String {
        switch complexity {
        case "Fast (15m)":
            return "CRITICAL: Every single meal prep time MUST be 15 minutes or under. Only use quick-cook methods: raw, microwave, quick pan-fry, no-cook, canned/pre-cooked ingredients, salads, smoothies, overnight prep. prepTimeMinutes must be ≤ 15 for all meals."
        case "Chef (60m)":
            return "Meals can take up to 60 minutes. Include complex, gourmet dishes with multiple steps, marinating, slow cooking, roasting, multiple components, and restaurant-quality plating. prepTimeMinutes can be up to 60."
        default: // Medium (30m)
            return "Meals should take between 15-30 minutes to prepare. Use standard cooking methods: stir-fry, grilling, boiling, baking simple dishes. prepTimeMinutes must be between 15-30 for all meals."
        }
    }
    
    func generateWeeklyPlan(targetCalories: Int, diet: String, complexity: String) async -> WeeklyMealPlan? {
        let dietInstruction = dietRules(for: diet)
        let complexityInstruction = complexityRules(for: complexity)
        let proteinTarget = Int(Double(targetCalories) * 0.25 / 4)
        let carbTarget: Int
        let fatTarget: Int
        
        switch diet {
        case "Keto":
            carbTarget = 40
            fatTarget = Int(Double(targetCalories) * 0.70 / 9)
        case "High Protein":
            carbTarget = Int(Double(targetCalories) * 0.30 / 4)
            fatTarget = Int(Double(targetCalories) * 0.30 / 9)
        case "Low Carb":
            carbTarget = 80
            fatTarget = Int(Double(targetCalories) * 0.40 / 9)
        default:
            carbTarget = Int(Double(targetCalories) * 0.45 / 4)
            fatTarget = Int(Double(targetCalories) * 0.30 / 9)
        }
        
        let prompt = """
        You are an elite nutritionist. Generate a 7-day meal plan following these STRICT constraints:
        
        === CALORIE TARGET ===
        Daily calories: exactly \(targetCalories) kcal per day (±50 kcal tolerance)
        Daily macro targets: ~\(proteinTarget)g protein, ~\(carbTarget)g carbs, ~\(fatTarget)g fat
        
        === DIET RULES (STRICTLY FOLLOW) ===
        \(dietInstruction)
        
        === COOKING TIME (STRICTLY FOLLOW) ===
        \(complexityInstruction)
        
        === STRUCTURE ===
        Generate exactly 4 meals per day: Breakfast, Lunch, Dinner, Snack.
        Use EXACTLY these type values: "Breakfast", "Lunch", "Dinner", "Snack"
        Each day MUST sum to \(targetCalories) kcal.
        Make meals VARIED — no repeated dishes across the 7 days.
        
        Provide the response STRICTLY as a raw JSON object. No markdown. No backticks.
        Schema:
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
                    "title": "String (creative descriptive name)",
                    "type": "String (Breakfast/Lunch/Dinner/Snack)",
                    "calories": Int,
                    "protein": Int,
                    "carbs": Int,
                    "fat": Int,
                    "ingredients": "String (MUST include quantity for EVERY ingredient, comma-separated, e.g.: '200g chicken breast, 1 cup quinoa, 2 tbsp olive oil, 100g baby spinach, 3 cloves garlic')",
                    "instructions": "String (2-3 clear step instructions)",
                    "prepTimeMinutes": Int
                  }
               ]
             }
          ]
        }
        """

        
        if let dto = await fetchFromGemini(prompt: prompt, responseType: AIWeeklyPlanDTO.self, temperature: 0.2) {
            let plan = WeeklyMealPlan(targetCalories: targetCalories, dietType: diet)
            
            for dayDTO in dto.days {
                let day = MealPlanDay(
                    dayIndex: dayDTO.dayIndex ?? 0,
                    totalCalories: dayDTO.totalCalories ?? 0,
                    totalProtein: dayDTO.totalProtein ?? 0,
                    totalCarbs: dayDTO.totalCarbs ?? 0,
                    totalFat: dayDTO.totalFat ?? 0
                )
                
                for mealDTO in dayDTO.meals ?? [] {
                    let meal = MealPlanItem(
                        title: mealDTO.title ?? "Tasty Meal",
                        type: mealDTO.type ?? "Snack",
                        calories: mealDTO.calories ?? 0,
                        protein: mealDTO.protein ?? 0,
                        carbs: mealDTO.carbs ?? 0,
                        fat: mealDTO.fat ?? 0,
                        omega3: mealDTO.omega3 ?? 0.0,
                        calcium: mealDTO.calcium ?? 0.0,
                        potassium: mealDTO.potassium ?? 0.0,
                        magnesium: mealDTO.magnesium ?? 0.0,
                        iron: mealDTO.iron ?? 0.0,
                        vitaminC: mealDTO.vitaminC ?? 0.0,
                        vitaminD: mealDTO.vitaminD ?? 0.0,
                        ingredients: mealDTO.ingredients ?? "",
                        instructions: mealDTO.instructions ?? "",
                        prepTimeMinutes: mealDTO.prepTimeMinutes ?? 15,
                        imageUrl: self.imageUrlForDish(title: mealDTO.title ?? "")
                    )
                    day.meals = (day.meals ?? []) + [meal]
                }
                
                plan.days = (plan.days ?? []) + [day]
            }
            
            return plan
        }
        return nil
    }

    /// Pre-fetches all meal images sequentially with rate-limit protection.
    /// Call this BEFORE showing the plan so images are already cached when the user sees them.
    func prefetchAllImages(for plan: WeeklyMealPlan) async {
        let allMeals = (plan.days ?? []).flatMap { $0.meals ?? [] }
        for meal in allMeals {
            guard let url = URL(string: meal.imageUrl) else { continue }
            _ = try? await PollinationsImageLoader.shared.fetchImage(url: url)
        }
    }

    /// Public wrapper – use this from views to get a remote Unsplash URL for any dish name.
    func imageUrl(forMealTitle title: String) -> String {
        imageUrlForDish(title: title)
    }

    private func imageUrlForDish(title: String) -> String {
        // ──────────────────────────────────────────────────────────────────────
        // Strategy: pollinations.ai is blocked on some mobile ISPs (error 50).
        // We use loremflickr with generic food tags to ensure instant, reliable
        // loading without network errors, and without falling back to cats.
        // ──────────────────────────────────────────────────────────────────────
        let sig = abs(title.lowercased().hashValue % 9999) + 1
        return "https://loremflickr.com/800/500/food,meal,dish?lock=\(sig)"
    }

    /// Extracts up to 4 food-relevant nouns from a dish title for image search.
    ///
    /// Rules:
    ///  1. Only look at the *primary* part of the title (before " with ") — this
    ///     stops "Garlic Bread" from overriding "Vegetable Barley Stew".
    ///  2. Skip culinary stopwords (prepositions, articles, vague adjectives).
    ///  3. Map common synonyms/abbreviations to more image-search-friendly terms.
    ///  4. Deduplicate while preserving order.
    private func extractFoodKeywords(from title: String) -> [String] {
        // ── 1. Primary part only ─────────────────────────────────────────────
        // "Vegetable Barley Stew with Garlic Bread" → "Vegetable Barley Stew"
        let primary = title
            .components(separatedBy: " with ").first?
            .components(separatedBy: ", with ").first ?? title

        // ── 2. Stopwords to ignore ───────────────────────────────────────────
        let stopWords: Set<String> = [
            "with", "and", "the", "for", "pan", "easy", "classic", "healthy",
            "fresh", "style", "sliced", "slices", "pieces", "mixed", "recipe",
            "homemade", "quick", "roasted", "grilled", "baked", "fried",
            "steamed", "boiled", "sauteed", "sautéed", "slow", "cooked",
            "crispy", "spicy", "sweet", "savory", "savoury", "mini", "baby",
            "simple", "light", "low", "high", "whole", "half", "large", "small",
            "stuffed", "filled", "topped", "served", "seasoned", "herb",
            "herbed", "creamy", "crunchy", "tangy", "smoky"
        ]

        // ── 3. Synonym / search-term improvements ────────────────────────────
        let synonyms: [String: String] = [
            "stew": "stew soup",
            "porridge": "oatmeal porridge",
            "oat": "oatmeal",
            "oats": "oatmeal",
            "frittata": "egg frittata",
            "scramble": "scrambled eggs",
            "omelet": "omelette egg",
            "omelette": "omelette egg",
            "risotto": "risotto rice",
            "burger": "hamburger burger",
            "taco": "taco mexican",
            "sushi": "sushi japanese",
            "ramen": "ramen noodle soup",
            "lasagna": "lasagna pasta",
            "fettuccine": "pasta fettuccine",
            "couscous": "couscous grain",
            "quinoa": "quinoa salad",
            "burrito": "burrito mexican",
            "wrap": "wrap sandwich",
            "parfait": "yogurt parfait",
            "smoothie": "smoothie drink",
            "brownie": "chocolate brownie",
            "muffin": "muffin baked"
        ]

        // ── 4. Tokenise, filter, map synonyms, deduplicate ───────────────────
        var seen = Set<String>()
        var result: [String] = []

        let tokens = primary
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !stopWords.contains($0) }

        for token in tokens {
            if seen.contains(token) { continue }
            seen.insert(token)

            if let mapped = synonyms[token] {
                // A synonym can be multiple space-separated words; add them all.
                for part in mapped.components(separatedBy: " ") {
                    if !seen.contains(part) {
                        seen.insert(part)
                        result.append(part)
                    }
                }
            } else {
                result.append(token)
            }

            if result.count >= 4 { break }
        }

        // Fallback: if we got nothing useful, use "meal dish" as generic tags.
        return result.isEmpty ? ["meal", "dish"] : result
    }

    func fallbackLocalImage(for title: String) -> String {
        return "diet_bg_any"
    }

    func sendChatMessage(prompt: String, userContext: String, activeDiet: String) async -> String? {
          let systemPrompt = """
          You are a friendly, elite AI Nutritionist.
          Context about the user today: \(userContext)
          CRITICAL: The user is currently strictly following the "\(activeDiet)" diet.
          Tailor all your advice, food suggestions, and judgments based on the rules of the \(activeDiet) diet.

          USER SAYS: "\(prompt)"

          Respond conversationally, warmly, and concisely. Keep answers under 4 sentences.
          If they ask if they can eat something, check their remaining calories from the context and give advice based on their \(activeDiet) diet.
          """
          return await fetchRawTextFromGemini(prompt: systemPrompt)
      }

    func generateChatTitle(for userMessage: String) async -> String {
        let systemPrompt = "Create a very short title (max 2-3 words) for a nutrition chat based on this first message: '\(userMessage)'. Return ONLY the text without quotes."
        return await fetchRawTextFromGemini(prompt: systemPrompt) ?? "Diet Chat"
    }

    func getMacroFixAdvice(missingCals: Int, missingProtein: Int, missingFats: Int, missingCarbs: Int) async -> MacroFixAdviceDTO? {
        let prompt = """
        You are an elite AI Nutritionist. The user has \(missingCals) kcal left today.
        They need roughly \(missingProtein)g protein, \(missingFats)g fats, and \(missingCarbs)g carbs to hit their goal perfectly.

        If missingCals is negative, they overate. Tell them gently how to recover.
        If missingCals is positive, suggest exactly 3 quick, realistic snacks/meals to hit these remaining macros perfectly.

        Respond ONLY with a raw, valid JSON object. No Markdown. Format exactly:
        {
          "title": "Short punchy title",
          "explanation": "1 short sentence explaining what to focus on",
          "suggestedSnacks": [
            {"name": "Greek Yogurt with Almonds", "calories": 200, "protein": 15}
          ]
        }
        """
        return await fetchFromGemini(prompt: prompt, responseType: MacroFixAdviceDTO.self)
    }

    func getHydrationAdvice(drankLiters: Double, goalLiters: Double) async -> HydrationAdviceDTO? {
        let prompt = """
        You are a Hydration AI Coach. The user drank \(drankLiters)L out of their \(goalLiters)L goal today.

        Write a short, motivating message. If they reached the goal, praise them. If not, tell them exactly how much is left and when to drink next.

        Respond ONLY with a raw, valid JSON object. No Markdown. Format exactly:
        {
          "title": "Stay Hydrated / Great Job",
          "message": "Short motivating advice",
          "nextGlassTimeMinutes": 30
        }
        """
        return await fetchFromGemini(prompt: prompt, responseType: HydrationAdviceDTO.self)
    }

    // All transport, auth, and parsing now lives in the shared client.
    // This removes massive duplication with VertexAIManager.
    private let client = GeminiProxyClient.shared

    private func fetchRawTextFromGemini(prompt: String) async -> String? {
        do {
            return try await client.fetchText(prompt: prompt)
        } catch {
            print("❌ AI Chat Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchFromGemini<T: Codable>(prompt: String, responseType: T.Type, schema: [String: Any]? = nil, temperature: Double? = nil) async -> T? {
        do {
            return try await client.fetchJSON(prompt: prompt, responseType: responseType, schema: schema, temperature: temperature)
        } catch {
            // The client already logs detailed decode/raw info on failure.
            print("❌ AI Service Exception: \(error.localizedDescription)")
            return nil
        }
    }
}

import UIKit

actor PollinationsImageLoader {
    static let shared = PollinationsImageLoader()
    
    private var lastRequestTime: Date = Date.distantPast
    private let minimumDelay: TimeInterval = 0.0
    
    private let cache = NSCache<NSString, UIImage>()
    
    func fetchImage(url: URL) async throws -> UIImage {
        let cacheKey = url.absoluteString as NSString
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        var attempt = 0
        while attempt < 3 {
            let now = Date()
            let timeSinceLast = now.timeIntervalSince(lastRequestTime)
            if timeSinceLast < minimumDelay {
                let delay = minimumDelay - timeSinceLast
                lastRequestTime = now.addingTimeInterval(delay)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            } else {
                lastRequestTime = now
            }
            
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                attempt += 1
                try await Task.sleep(nanoseconds: UInt64(attempt * 2) * 1_000_000_000)
                continue
            }
            
            if let image = UIImage(data: data) {
                cache.setObject(image, forKey: cacheKey)
                return image
            } else {
                throw URLError(.cannotDecodeRawData)
            }
        }
        throw URLError(.badServerResponse)
    }
}
