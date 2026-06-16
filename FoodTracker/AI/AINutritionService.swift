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
        
        let mappings: [([String], [String])] = [
            (["oat", "porridge"], [
                "1517881917430-e70dfb3610aa", "1511690656020-366021647eb6", "1614548483733-4f9389ea8731"
            ]),
            (["egg", "omelet", "scramble", "frittata"], [
                "1525351484163-7529414344d8", "1533089860892-a7c6f0a88666", "1482049142969-95758d11c41b"
            ]),
            (["pancake", "waffle", "crepe"], [
                "1567620905732-2d1ec7ab7445", "1506084868230-f61b0c05763d", "1558961363-6311ce97ee94"
            ]),
            (["toast", "sandwich", "bread", "bagel", "burger"], [
                "1481070555726-e2883cdf38bd", "1550508443-400f6825c04b", "1528735602780-2552fd46c7af", "1568901346375-23c9450c58cd"
            ]),
            (["salad", "green", "caesar", "lettuce", "spinach", "kale"], [
                "1512621776951-a57141f2eefd", "1540189549336-e6e99c3679fe", "1505253716362-afaea1d3d1af", "1550304943-4f24f54bcde4"
            ]),
            (["chicken", "turkey", "poultry", "wing"], [
                "1532550907401-a500c9a57435", "1604908176997-125f25cc6f3d", "1598514982205-f36b96d1e8d4", "1604908176997-125f25cc6f3d"
            ]),
            (["salmon", "tuna", "fish", "shrimp", "seafood", "prawn"], [
                "1485921325814-a5341aff6148", "1519708227418-c8fd9a32b7a2", "1546069901-ba9599a7e63c", "1615141982309-847fb6f6f966"
            ]),
            (["steak", "beef", "meat", "pork", "lamb", "rib", "brisket"], [
                "1544025162-d76694265947", "1529692236671-f1f6cf9683ba", "1555939594-58d7cb561ad1", "1600891964092-4b16e16ac6f5"
            ]),
            (["pasta", "spaghetti", "lasagna", "noodle", "macaroni", "ramen"], [
                "1563379091339-03b21ab4a4f8", "1473093295043-cdd812d0e601", "1555949258-eb67b1ef0ceb", "1595295333158-4742f28fbd85"
            ]),
            (["soup", "broth", "stew", "chili", "chowder"], [
                "1547592165-e1d17fed6005", "1548943487-a2e4f43b4850", "1604152002344-bd0d9e262de6", "1576402244246-3b6920fdf94f"
            ]),
            (["smoothie", "shake", "juice", "drink", "cocktail"], [
                "1553530666-ba11a7da3888", "1505253716362-afaea1d3d1af", "1557004396-6b21bc598eb4", "1623065422902-30a5d29cfa28"
            ]),
            (["yogurt", "curd", "parfait", "pudding"], [
                "1488477181946-6428a0291777", "1572449043416-55f4685c9bb7", "1495287342676-e1704da8845c"
            ]),
            (["sushi", "roll", "sashimi"], [
                "1579871494447-9811cf80d66c", "1553621042-f6e147245754", "1583623025817-d180a2221d05"
            ]),
            (["wrap", "burrito", "taco", "quesadilla", "fajita"], [
                "1565299585323-38d6b0865b47", "1551504734-b46ec60e58f0", "1564834724105-918b73d1b9e0", "1584988018301-3e47087f9788"
            ]),
            (["rice", "quinoa", "grain", "bowl", "couscous"], [
                "1512058564366-18510be2db19", "1546069901-ba9599a7e63c", "1514326640561-12c5b0c95aeb", "1551244465-ee53154e17b3"
            ]),
            (["fruit", "apple", "banana", "berry", "berries", "melon", "orange"], [
                "1490818384979-93b26b26a5b4", "1481349518771-20055b2a7b24", "1610832958506-aa56368176cf", "1519996434828-991510d9fb6a"
            ]),
            (["nut", "almond", "peanut", "cashew", "walnut"], [
                "1511066929037-9d698502c44d", "1610437435136-1e66ce93f9c6", "1599595562725-d72b53b8110b"
            ]),
            (["vegan", "plant-based", "tofu", "tempeh", "veggie"], [
                "1512621776951-a57141f2eefd", "1490645935980-d698a21133ab", "1546069901-ba9599a7e63c"
            ]),
            (["cake", "cookie", "pie", "dessert", "sweet", "chocolate"], [
                "1550617931-e17a7b70dce2", "1488477181946-6428a0291777", "1578985545062-69928b1d9587", "1551024601-bec78aea704b"
            ])
        ]
        
        // Find matching category
        for (keywords, ids) in mappings {
            if keywords.contains(where: { t.contains($0) }) {
                if let photoId = ids.randomElement() {
                    return "https://images.unsplash.com/photo-\(photoId)?w=600&auto=format&fit=crop"
                }
            }
        }
        
        // Powerful Fallback
        let fallbackIds = [
            "1498837167922-ddd27525d352",
            "1476224203421-9ce132453550",
            "1482049142969-95758d11c41b",
            "1504674900247-0877df9cc836",
            "1490645935980-d698a21133ab",
            "1493770348161-369560ae357d"
        ]
        
        let randomFallback = fallbackIds.randomElement() ?? "1498837167922-ddd27525d352"
        return "https://images.unsplash.com/photo-\(randomFallback)?w=600&auto=format&fit=crop"
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
