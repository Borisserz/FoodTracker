import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class DataModelsTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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
        XCTAssertEqual(meal.totalProtein, 1.4, accuracy: 0.0001)
        XCTAssertEqual(meal.totalFats, 0.5, accuracy: 0.0001)
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

    func testCloudKitSchemaCompatibility() throws {
        let schema = Schema([
            User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self,
            ActivityLog.self, DailySummary.self, AIChatSession.self, ShoppingItem.self,
            WeeklyMealPlan.self, MealPlanDay.self, MealPlanItem.self, WeightLog.self
        ])

        for entity in schema.entities {
            XCTAssertTrue(
                entity.uniquenessConstraints.isEmpty,
                "CloudKit forbids @Attribute(.unique) on \(entity.name): \(entity.uniquenessConstraints)"
            )

            for attr in entity.attributes where !attr.isOptional {
                XCTAssertNotNil(
                    attr.defaultValue,
                    "CloudKit requires defaultValue for non-optional attribute \(entity.name).\(attr.name)"
                )
            }

            for rel in entity.relationships {
                XCTAssertTrue(
                    rel.isOptional,
                    "CloudKit requires relationship \(entity.name).\(rel.name) to be optional"
                )
                XCTAssertNotNil(
                    rel.inverseName,
                    "CloudKit requires inverse relationship on \(entity.name).\(rel.name)"
                )
            }
        }
    }

    func testUserCalculateGoalsRespectsActivityAndWeightGoalType() {
        let user = User(name: "Alex", weight: 80, height: 180, age: 30, gender: "Male")
        user.activityMultiplier = 1.55
        user.weightGoalType = "lose"
        user.calculateGoals()

        // BMR = 1780; TDEE = 2759; lose = 2759 - 450 = 2309
        XCTAssertEqual(user.dailyCaloriesGoal, 2309)

        user.recalculateMacrosPreservingRatios(fromPreviousCalories: 2759)
        XCTAssertGreaterThan(user.targetProtein, 0)
        XCTAssertGreaterThan(user.targetFats, 0)
        XCTAssertGreaterThan(user.targetCarbs, 0)
        let macroCals = user.targetProtein * 4.0 + user.targetFats * 9.0 + user.targetCarbs * 4.0
        XCTAssertEqual(macroCals, Double(user.dailyCaloriesGoal), accuracy: 30.0)

        user.weightGoalType = "gain"
        user.calculateGoals()
        XCTAssertEqual(user.dailyCaloriesGoal, 3109) // 2759 + 350
    }

    func testDailySummaryFetchOrCreateMergesDuplicates() throws {
        let day = Calendar.current.startOfDay(for: Date())
        let first = DailySummary(
            date: day,
            meals: [Meal(title: "Breakfast", date: day, foodItems: [FoodItem(name: "Eggs", weight: 100, calories: 155, protein: 13, fats: 11, carbs: 1)])]
        )
        let second = DailySummary(
            date: day,
            beverages: [Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 300)],
            activities: [ActivityLog(title: "Walk", icon: "figure.walk", durationMinutes: 20, calories: 90)]
        )
        second.stepsCount = 5400

        context.insert(first)
        context.insert(second)
        try context.save()

        let merged = DailySummary.fetchOrCreate(for: day, in: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<DailySummary>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(merged.totalFoodCalories, 155)
        XCTAssertEqual(merged.totalHydrationLiters, 0.3, accuracy: 0.01)
        XCTAssertEqual(merged.localActivityCalories, 90)
        XCTAssertEqual(merged.stepsCount, 5400)
    }

    func testSharedModelContainerFallsBackWithoutCrashing() {
        let schema = Schema([User.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self])
        let unreachableURL = URL(fileURLWithPath: "/System/Library/NonWritablePath/\(UUID().uuidString)/Food.sqlite")
        let container = SharedModelContainer.makeContainer(schema: schema, url: unreachableURL, enableCloudKit: false)
        XCTAssertNotNil(container)
    }
}
