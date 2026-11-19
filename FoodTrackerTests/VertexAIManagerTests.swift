import XCTest
@testable import FoodTracker

final class VertexAIManagerTests: XCTestCase {

    func testAIFoodResponseDecoding() throws {
        let jsonString = """
        {
            "isFood": true,
            "name": "Apple",
            "weight": 120.0,
            "calories": 60,
            "protein": 0.5,
            "fats": 0.2,
            "carbs": 14.0
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(VertexAIManager.AIFoodResponse.self, from: data)
        
        XCTAssertTrue(response.isFood)
        XCTAssertEqual(response.name, "Apple")
        XCTAssertEqual(response.weight, 120.0)
        XCTAssertEqual(response.calories, 60)
        XCTAssertEqual(response.protein, 0.5)
        XCTAssertEqual(response.fats, 0.2)
        XCTAssertEqual(response.carbs, 14.0)
        XCTAssertNil(response.errorMessage)
    }
    
    func testAIFoodResponseDecodingNotFood() throws {
        let jsonString = """
        {
            "isFood": false,
            "errorMessage": "That's a keyboard!"
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(VertexAIManager.AIFoodResponse.self, from: data)
        
        XCTAssertFalse(response.isFood)
        XCTAssertEqual(response.errorMessage, "That's a keyboard!")
        XCTAssertNil(response.name)
        XCTAssertNil(response.weight)
    }
    
    func testMenuAIResponseDecoding() throws {
        let jsonString = """
        {
            "ideal": {
                "dishName": "Grilled Chicken Salad",
                "estimatedCalories": 350,
                "protein": 40.0,
                "reasoning": "High protein, low carb."
            },
            "caution": {
                "dishName": "Caesar Salad",
                "estimatedCalories": 500,
                "protein": 20.0,
                "reasoning": "Dressing has high fat."
            },
            "avoid": {
                "dishName": "Cheeseburger",
                "estimatedCalories": 900,
                "protein": 30.0,
                "reasoning": "Too many calories."
            }
        }
        """
        
        let data = jsonString.data(using: .utf8)!
        let response = try JSONDecoder().decode(VertexAIManager.MenuAIResponse.self, from: data)
        
        XCTAssertEqual(response.ideal.dishName, "Grilled Chicken Salad")
        XCTAssertEqual(response.caution.estimatedCalories, 500)
        XCTAssertEqual(response.avoid.reasoning, "Too many calories.")
    }

    func testCookingStepEvaluationDecoding() throws {
        let jsonString = """
        {
            "isGood": true,
            "feedback": "Great golden sear on both sides. Ready to rest."
        }
        """
        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(VertexAIManager.CookingStepEvaluation.self, from: data)
        XCTAssertTrue(decoded.isGood)
        XCTAssertEqual(decoded.feedback, "Great golden sear on both sides. Ready to rest.")
    }

    func testTransformationAnalysisDecoding() throws {
        let jsonString = """
        {
            "metrics": [
                {"label": "Posture", "value": "Aligned", "detail": "Stronger shoulders", "isPositive": true},
                {"label": "Midsection", "value": "Leaner", "detail": "Visible waist definition", "isPositive": true}
            ],
            "feedback": "Noticeable improvement in posture and core tone between photos."
        }
        """
        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(VertexAIManager.TransformationAnalysisDTO.self, from: data)
        XCTAssertEqual(decoded.metrics.count, 2)
        XCTAssertEqual(decoded.metrics.first?.label, "Posture")
        XCTAssertFalse(decoded.feedback.isEmpty)
    }

    func testMoodAdviceBaselineCoversAllSevenDailyNoteMoods() {
        let dailyNoteEmojis = ["☀️", "🍩", "🍔", "🥲", "🏋️", "🧘‍♀️", "🤢"]
        var titles = Set<String>()
        for emoji in dailyNoteEmojis {
            let baseline = MoodAdviceBaseline.advice(forEmoji: emoji, moodName: "Mood")
            XCTAssertNotEqual(baseline.title, "AI Coach Insights", "Emoji \(emoji) should not fall through to generic default")
            titles.insert(baseline.title)
        }
        XCTAssertEqual(titles.count, dailyNoteEmojis.count)
    }

    func testMoodAdviceDTODecoding() throws {
        let jsonString = """
        {
            "title": "Refuel & Recover",
            "message": "After training, aim for lean protein and water."
        }
        """
        let data = jsonString.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(MoodAdviceDTO.self, from: data)
        XCTAssertEqual(decoded.title, "Refuel & Recover")
        XCTAssertFalse(decoded.message.isEmpty)
    }

    func testFlexibleNumericDecodingAnd1xDownsampling() throws {
        let foodJSON = """
        {
            "isFood": true,
            "name": "Grilled Salmon",
            "weight": "180.5",
            "calories": 340.6,
            "protein": "32.0",
            "fats": 18,
            "carbs": "0"
        }
        """.data(using: .utf8)!
        let food = try JSONDecoder().decode(VertexAIManager.AIFoodResponse.self, from: foodJSON)
        XCTAssertEqual(food.calories, 341)
        XCTAssertEqual(food.weight ?? 0, 180.5, accuracy: 0.01)
        XCTAssertEqual(food.protein ?? 0, 32.0, accuracy: 0.01)

        let menuJSON = """
        {
            "ideal": {"dishName": "Chicken", "estimatedCalories": "410.2", "protein": "38", "fats": 11.5, "carbs": 24, "reasoning": "Lean"},
            "caution": {"dishName": "Pasta", "estimatedCalories": 650, "protein": 18, "reasoning": "Sauce"},
            "avoid": {"dishName": "Fries", "estimatedCalories": 900, "protein": 8, "reasoning": "Fried"}
        }
        """.data(using: .utf8)!
        let menu = try JSONDecoder().decode(VertexAIManager.MenuAIResponse.self, from: menuJSON)
        XCTAssertEqual(menu.ideal.estimatedCalories, 410)
        XCTAssertEqual(menu.ideal.fats ?? 0, 11.5, accuracy: 0.01)
        XCTAssertEqual(menu.ideal.carbs ?? 0, 24.0, accuracy: 0.01)

        // Ensure 1x scale rendering does not multiply dimensions by 3x display scale.
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2400, height: 1200))
        let large = renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 2400, height: 1200))
        }
        let downsampled = VertexAIManager.downsampledImage(large, maxDimension: 1024)
        XCTAssertEqual(downsampled.scale, 1.0)
        XCTAssertLessThanOrEqual(max(downsampled.size.width, downsampled.size.height), 1024.0)
    }

    func testAIRecipeAndFoodItemDTODecodeStringNumbersAndStableAdviceIDs() throws {
        let recipeJSON = """
        {
            "name": "Protein Bowl",
            "info": "Quick dinner",
            "calories": "520",
            "protein": "42.5",
            "fats": "14,2",
            "carbs": 55,
            "cookingTime": "20"
        }
        """.data(using: .utf8)!
        let recipe = try JSONDecoder().decode(AIRecipeDTO.self, from: recipeJSON)
        XCTAssertEqual(recipe.calories, 520)
        XCTAssertEqual(recipe.protein, 42.5, accuracy: 0.01)
        XCTAssertEqual(recipe.fats, 14.2, accuracy: 0.01)
        XCTAssertEqual(recipe.carbs, 55.0, accuracy: 0.01)

        let foodJSON = """
        {
            "name": "Greek Yogurt",
            "calories": 120,
            "protein": "18.0",
            "fats": "2.5",
            "carbs": "7.0"
        }
        """.data(using: .utf8)!
        let food = try JSONDecoder().decode(AIFoodItemDTO.self, from: foodJSON)
        XCTAssertEqual(food.protein, 18.0, accuracy: 0.01)
        XCTAssertEqual(food.fats, 2.5, accuracy: 0.01)
        XCTAssertEqual(food.carbs, 7.0, accuracy: 0.01)

        let macroJSON = """
        {
            "title": "Add Protein",
            "explanation": "You are short on protein.",
            "suggestedSnacks": [{"name": "Whey", "calories": 120, "protein": 24}]
        }
        """.data(using: .utf8)!
        let macroAdvice = try JSONDecoder().decode(MacroFixAdviceDTO.self, from: macroJSON)
        let firstMacroID = macroAdvice.id
        let secondMacroID = macroAdvice.id
        XCTAssertEqual(firstMacroID, secondMacroID)

        let hydJSON = """
        {
            "title": "Drink Water",
            "message": "Have a glass now.",
            "nextGlassTimeMinutes": 30
        }
        """.data(using: .utf8)!
        let hydAdvice = try JSONDecoder().decode(HydrationAdviceDTO.self, from: hydJSON)
        let firstHydID = hydAdvice.id
        let secondHydID = hydAdvice.id
        XCTAssertEqual(firstHydID, secondHydID)
    }

    func testDefensiveDTOsDecodeOmittedFieldsStringBoolsAndDistinctMetricIDs() throws {
        let macroNoSnacks = #"{"title":"Stay Steady","explanation":"All good today."}"#.data(using: .utf8)!
        let macro = try JSONDecoder().decode(MacroFixAdviceDTO.self, from: macroNoSnacks)
        XCTAssertEqual(macro.suggestedSnacks, [])

        let hydNoMinutes = #"{"title":"Goal Hit","message":"Great hydration!"}"#.data(using: .utf8)!
        let hyd = try JSONDecoder().decode(HydrationAdviceDTO.self, from: hydNoMinutes)
        XCTAssertEqual(hyd.nextGlassTimeMinutes, 30)

        let stringBoolFood = #"{"isFood":"true","name":"Apple","weight":150,"calories":78,"protein":0.4,"fats":0.2,"carbs":21}"#.data(using: .utf8)!
        let food = try JSONDecoder().decode(VertexAIManager.AIFoodResponse.self, from: stringBoolFood)
        XCTAssertTrue(food.isFood)

        let dupMetricJSON = #"""
        {
          "metrics": [
            {"label": "Posture", "value": "+10%", "detail": "Better", "isPositive": "true"},
            {"label": "Posture", "value": "+12%", "detail": "Also better", "isPositive": "false"}
          ],
          "feedback": "Solid"
        }
        """#.data(using: .utf8)!
        let analysis = try JSONDecoder().decode(VertexAIManager.TransformationAnalysisDTO.self, from: dupMetricJSON)
        XCTAssertEqual(analysis.metrics.count, 2)
        XCTAssertNotEqual(analysis.metrics[0].id, analysis.metrics[1].id)
        XCTAssertTrue(analysis.metrics[0].isPositive)
        XCTAssertFalse(analysis.metrics[1].isPositive)
    }
}
