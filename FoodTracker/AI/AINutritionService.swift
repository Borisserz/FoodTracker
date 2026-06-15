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
    let omega3: Double
    let calcium: Double
    let potassium: Double
    let magnesium: Double
    let iron: Double
    let vitaminC: Double
    let vitaminD: Double
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
        {"name": "String", "info": "Short description of how to cook it", "calories": Int, "protein": Double, "fats": Double, "carbs": Double, "cookingTime": Int}
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

    func generateWeeklyPlan(targetCalories: Int, diet: String, complexity: String) async -> WeeklyMealPlan? {
        let prompt = """
        You are an elite nutritionist. Generate a 7-day meal plan (0 to 6) following these constraints:
        - Target Calories per day: exactly \(targetCalories) kcal
        - Diet Type: \(diet)
        - Cooking Complexity: \(complexity)
        
        Generate exactly 4 meals per day: Breakfast, Lunch, Dinner, Snack.
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
                    "type": "String",
                    "calories": Int,
                    "protein": Int,
                    "carbs": Int,
                    "fat": Int,
                    "omega3": Double,
                    "calcium": Double,
                    "potassium": Double,
                    "magnesium": Double,
                    "iron": Double,
                    "vitaminC": Double,
                    "vitaminD": Double,
                    "ingredients": "String",
                    "instructions": "String",
                    "prepTimeMinutes": Int
                  }
               ]
             }
          ]
        }
        Do not include markdown tags. Only output the raw JSON. Ensure all arrays have 7 items for days, and 4 items for meals.
        """
        
        if let dto = await fetchFromGemini(prompt: prompt, responseType: AIWeeklyPlanDTO.self) {
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
                    day.meals.append(meal)
                }
                
                plan.days.append(day)
            }
            return plan
        }
        return nil
    }

    private func imageUrlForDish(title: String) -> String {
        let t = title.lowercased()
        if t.contains("oat") || t.contains("porridge") {
            return "https://images.unsplash.com/photo-1517881917430-e70dfb3610aa?w=600&auto=format&fit=crop"
        } else if t.contains("egg") || t.contains("omelet") || t.contains("scramble") {
            return "https://images.unsplash.com/photo-1525351484163-7529414344d8?w=600&auto=format&fit=crop"
        } else if t.contains("pancake") || t.contains("waffle") || t.contains("crepe") {
            return "https://images.unsplash.com/photo-1567620905732-2d1ec7ab7445?w=600&auto=format&fit=crop"
        } else if t.contains("toast") || t.contains("sandwich") || t.contains("bread") {
            return "https://images.unsplash.com/photo-1525351484163-7529414344d8?w=600&auto=format&fit=crop"
        } else if t.contains("salad") || t.contains("green") || t.contains("caesar") {
            return "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=600&auto=format&fit=crop"
        } else if t.contains("chicken") || t.contains("turkey") || t.contains("poultry") {
            return "https://images.unsplash.com/photo-1532550907401-a500c9a57435?w=600&auto=format&fit=crop"
        } else if t.contains("salmon") || t.contains("tuna") || t.contains("fish") || t.contains("shrimp") || t.contains("seafood") {
            return "https://images.unsplash.com/photo-1485921325814-a5341aff6148?w=600&auto=format&fit=crop"
        } else if t.contains("steak") || t.contains("beef") || t.contains("meat") || t.contains("pork") || t.contains("lamb") {
            return "https://images.unsplash.com/photo-1544025162-d76694265947?w=600&auto=format&fit=crop"
        } else if t.contains("pasta") || t.contains("spaghetti") || t.contains("lasagna") || t.contains("noodle") {
            return "https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=600&auto=format&fit=crop"
        } else if t.contains("soup") || t.contains("broth") || t.contains("stew") {
            return "https://images.unsplash.com/photo-1547592165-e1d17fed6005?w=600&auto=format&fit=crop"
        } else if t.contains("smoothie") || t.contains("shake") || t.contains("juice") {
            return "https://images.unsplash.com/photo-1553530666-ba11a7da3888?w=600&auto=format&fit=crop"
        } else if t.contains("yogurt") || t.contains("curd") || t.contains("parfait") {
            return "https://images.unsplash.com/photo-1488477181946-6428a0291777?w=600&auto=format&fit=crop"
        } else if t.contains("sushi") || t.contains("roll") {
            return "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=600&auto=format&fit=crop"
        } else if t.contains("wrap") || t.contains("burrito") || t.contains("taco") || t.contains("quesadilla") {
            return "https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=600&auto=format&fit=crop"
        } else if t.contains("rice") || t.contains("quinoa") || t.contains("grain") {
            return "https://images.unsplash.com/photo-1512058564366-18510be2db19?w=600&auto=format&fit=crop"
        } else if t.contains("fruit") || t.contains("apple") || t.contains("banana") || t.contains("berry") || t.contains("berries") {
            return "https://images.unsplash.com/photo-1490818384979-93b26b26a5b4?w=600&auto=format&fit=crop"
        } else if t.contains("nut") || t.contains("almond") || t.contains("peanut") || t.contains("cashew") {
            return "https://images.unsplash.com/photo-1511066929037-9d698502c44d?w=600&auto=format&fit=crop"
        } else {
            return "https://images.unsplash.com/photo-1498837167922-ddd27525d352?w=600&auto=format&fit=crop"
        }
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

    private func fetchFromGemini<T: Codable>(prompt: String, responseType: T.Type) async -> T? {
        do {
            return try await client.fetchJSON(prompt: prompt, responseType: responseType)
        } catch {
            // The client already logs detailed decode/raw info on failure.
            print("❌ AI Service Exception: \(error.localizedDescription)")
            return nil
        }
    }
}
