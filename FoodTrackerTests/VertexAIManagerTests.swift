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
}
