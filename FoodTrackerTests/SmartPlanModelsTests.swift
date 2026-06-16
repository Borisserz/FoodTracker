import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class SmartPlanModelsTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
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
}
