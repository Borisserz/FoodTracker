import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class SmartPlanModelsTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: WeeklyMealPlan.self, MealPlanDay.self, MealPlanItem.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testWeeklyPlanInitializationAndRelationships() throws {
        let plan = WeeklyMealPlan(targetCalories: 2000, dietType: "keto")
        context.insert(plan)
        
        let day1 = MealPlanDay(dayIndex: 0, totalCalories: 1950, totalProtein: 150, totalCarbs: 20, totalFat: 140)
        let day2 = MealPlanDay(dayIndex: 1, totalCalories: 2050, totalProtein: 140, totalCarbs: 25, totalFat: 155)
        
        plan.days = [day1, day2]
        
        let breakfast = MealPlanItem(title: "Eggs and Bacon", type: "Breakfast", calories: 450, protein: 30, carbs: 2, fat: 35, ingredients: "Eggs, Bacon", instructions: "Cook eggs and bacon", prepTimeMinutes: 10)
        day1.meals = [breakfast]
        
        XCTAssertEqual(plan.targetCalories, 2000)
        XCTAssertEqual(plan.dietType, "keto")
        XCTAssertTrue(plan.isCurrentPlan)
        XCTAssertEqual(plan.days?.count, 2)
        XCTAssertEqual(plan.days?.first?.meals?.first?.title, "Eggs and Bacon")
        XCTAssertEqual(breakfast.parentDay?.dayIndex, 0)
        XCTAssertEqual(day1.parentPlan?.targetCalories, 2000)
    }

    func testNormalizedPlanDaysAndChefRecipeMacroDecoding() throws {
        let rawDaysJSON = """
        [
          {"dayIndex": 7, "totalCalories": 2100, "totalProtein": 140, "totalCarbs": 200, "totalFat": 70, "meals": []},
          {"dayIndex": 1, "totalCalories": 1900, "totalProtein": 130, "totalCarbs": 180, "totalFat": 65, "meals": []}
        ]
        """.data(using: .utf8)!
        let decodedDays = try JSONDecoder().decode([AIWeeklyPlanDayDTO].self, from: rawDaysJSON)
        let normalized = AINutritionService.normalizedPlanDays(decodedDays)
        XCTAssertEqual(normalized.first?.totalCalories, 1900)
        XCTAssertEqual(normalized.last?.totalCalories, 2100)

        let fullChefJSON = """
        {
          "title": "Seared Tuna",
          "calories": "420",
          "protein": "42",
          "fat": "12",
          "carbs": "28",
          "cookTime": 15,
          "difficulty": 2,
          "history": "Quick classic.",
          "ingredients": ["Tuna 200g"],
          "steps": [{"instruction": "Sear", "aiTip": null}],
          "platingTip": "Serve warm"
        }
        """.data(using: .utf8)!
        let fullRecipe = try JSONDecoder().decode(AIChefRecipeDTO.self, from: fullChefJSON)
        XCTAssertEqual(fullRecipe.fat, 12)
        XCTAssertEqual(fullRecipe.carbs, 28)

        let stepChefJSON = """
        {
          "title": "Quick Soup",
          "calories": 250,
          "protein": 15,
          "cookTime": 20,
          "difficulty": 1,
          "history": "Warm broth.",
          "ingredients": ["Veg"],
          "steps": [],
          "platingTip": "Top with herbs"
        }
        """.data(using: .utf8)!
        let stepRecipe = try JSONDecoder().decode(AIChefRecipeDTO.self, from: stepChefJSON)
        XCTAssertEqual(stepRecipe.fat, 0)
        XCTAssertEqual(stepRecipe.carbs, 0)
    }
}
