import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class DataModelsTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self, ActivityLog.self, DailySummary.self, ShoppingItem.self, WeightLog.self, AIChatSession.self, configurations: config)
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testUserInitializationAndGoalsCalculation() throws {
        let user = User(name: "TestUser", weight: 70, height: 175, age: 30, gender: "Male")
        context.insert(user)
        
        XCTAssertEqual(user.name, "TestUser")
        XCTAssertEqual(user.weight, 70)
        XCTAssertEqual(user.height, 175)
        XCTAssertEqual(user.age, 30)
        XCTAssertEqual(user.gender, "Male")
        
        // BMR for male: (10 * 70) + (6.25 * 175) - (30 * 5) + 5 = 700 + 1093.75 - 150 + 5 = 1648.75
        // Goal = BMR * 1.3 = 2143
        XCTAssertEqual(user.dailyCaloriesGoal, 2143)
        XCTAssertEqual(user.activeDietKey, "balanced")
    }

    func testFoodItemHealthGrade() throws {
        // High protein, clean
        let chicken = FoodItem(name: "Chicken", weight: 100, calories: 165, protein: 31, fats: 3.6, carbs: 0)
        XCTAssertEqual(chicken.healthGrade, .clean)

        // Low calories, low carbs, clean
        let cucumber = FoodItem(name: "Cucumber", weight: 100, calories: 15, protein: 0.6, fats: 0.1, carbs: 3.6)
        XCTAssertEqual(cucumber.healthGrade, .clean)

        // High calories, low protein, treat
        let cake = FoodItem(name: "Cake", weight: 100, calories: 400, protein: 3, fats: 20, carbs: 50)
        XCTAssertEqual(cake.healthGrade, .treat)

        // Balanced
        let balancedFood = FoodItem(name: "Balanced Meal", weight: 100, calories: 250, protein: 10, fats: 10, carbs: 30)
        XCTAssertEqual(balancedFood.healthGrade, .balanced)
    }

    func testMealTotalCalculations() throws {
        let apple = FoodItem(name: "Apple", weight: 100, calories: 52, protein: 0.3, fats: 0.2, carbs: 14)
        let banana = FoodItem(name: "Banana", weight: 100, calories: 89, protein: 1.1, fats: 0.3, carbs: 23)
        
        let meal = Meal(title: "Breakfast", date: Date(), foodItems: [apple, banana])
        
        XCTAssertEqual(meal.totalCalories, 141)
        XCTAssertEqual(meal.totalProtein, 1.4)
        XCTAssertEqual(meal.totalFats, 0.5)
        XCTAssertEqual(meal.totalCarbs, 37)
    }

    func testDailySummaryCalculations() throws {
        let summary = DailySummary(date: Date())
        
        let meal = Meal(title: "Lunch", date: Date())
        meal.foodItems = [FoodItem(name: "Rice", weight: 100, calories: 130, protein: 2, fats: 0, carbs: 28)]
        summary.meals = [meal]
        
        let water = Beverage(name: "Water", icon: "drop", colorHex: "blue", caloriesPerGlass: 0, volumeMl: 500)
        let soda = Beverage(name: "Soda", icon: "cup.and.saucer", colorHex: "brown", caloriesPerGlass: 150, volumeMl: 330)
        summary.beverages = [water, soda]
        
        let activity = ActivityLog(title: "Running", icon: "figure.run", durationMinutes: 30, calories: 300)
        summary.activities = [activity]
        
        summary.activeCaloriesBurned = 300
        
        XCTAssertEqual(summary.totalFoodCalories, 130)
        XCTAssertEqual(summary.totalDrinkCalories, 150)
        XCTAssertEqual(summary.totalCalories, 280)
        XCTAssertEqual(summary.totalHydrationLiters, 0.83, accuracy: 0.01)
        XCTAssertEqual(summary.netCalories, -20)
        
        let remaining = summary.remainingCalories(userGoal: 2000)
        // (2000 + 300) - 280 = 2020
        XCTAssertEqual(remaining, 2020)
    }
}
