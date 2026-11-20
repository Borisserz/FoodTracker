import XCTest
@testable import FoodTracker

final class NutritionProgressManagerTests: XCTestCase {

    func testCumulativeXPRequired() {
        let user = User(name: "Test", weight: 70, height: 175, age: 25)
        let manager = NutritionProgressManager(user: user)
        
        // Level 1 should be 0
        XCTAssertEqual(manager.cumulativeXPRequired(forLevel: 1), 0)
        
        // Level 2 should be 1000
        XCTAssertEqual(manager.cumulativeXPRequired(forLevel: 2), 1000)
        
        // Level 3 should be 1000 + 1000*1.2 = 2200
        XCTAssertEqual(manager.cumulativeXPRequired(forLevel: 3), 2200)
    }
    
    func testLevelRecalculation() {
        let user = User(name: "Test", weight: 70, height: 175, age: 25)
        user.totalXP = 0
        let manager = NutritionProgressManager(user: user)
        
        XCTAssertEqual(user.level, 1)
        XCTAssertEqual(manager.currentTitle, "Nutrition Rookie")
        
        // Add 1000 XP
        let breakdown = NutritionXPBreakdown(baseXP: 1000, proteinGoalXP: 0, calorieGoalXP: 0)
        manager.addXP(from: breakdown)
        
        XCTAssertEqual(user.level, 2)
        XCTAssertEqual(user.totalXP, 1000)
        
        // Add 1200 XP
        let breakdown2 = NutritionXPBreakdown(baseXP: 1200, proteinGoalXP: 0, calorieGoalXP: 0)
        manager.addXP(from: breakdown2)
        
        XCTAssertEqual(user.level, 3)
        XCTAssertEqual(user.totalXP, 2200)
    }

    func testProgressPercentage() {
        let user = User(name: "Test", weight: 70, height: 175, age: 25)
        user.totalXP = 500
        let manager = NutritionProgressManager(user: user)
        
        XCTAssertEqual(user.level, 1)
        XCTAssertEqual(manager.progressPercentage, 0.5) // 500 / 1000
        
        user.totalXP = 1600
        // Level 2 requires 1000. Level 3 requires 2200.
        // Current level XP = 1600 - 1000 = 600
        // Required for level 3 = 1200
        // Percentage = 600 / 1200 = 0.5
        manager.addXP(from: NutritionXPBreakdown(baseXP: 0, proteinGoalXP: 0, calorieGoalXP: 0)) // Just to trigger recalculate
        XCTAssertEqual(user.level, 2)
        XCTAssertEqual(manager.progressPercentage, 0.5)
    }
    
    func testTitles() {
        let user = User(name: "Test", weight: 70, height: 175, age: 25)
        let manager = NutritionProgressManager(user: user)
        
        user.level = 1
        XCTAssertEqual(manager.currentTitle, "Nutrition Rookie")
        
        user.level = 5
        XCTAssertEqual(manager.currentTitle, "Macro Trainee")
        
        user.level = 10
        XCTAssertEqual(manager.currentTitle, "Diet Regular")
        
        user.level = 20
        XCTAssertEqual(manager.currentTitle, "Dedicated Eater")
        
        user.level = 30
        XCTAssertEqual(manager.currentTitle, "Nutrition Master")
        
        user.level = 50
        XCTAssertEqual(manager.currentTitle, "Diet Titan")
    }

    func testInitDoesNotMutateUserLevelUntilSyncLevel() {
        let user = User(name: "Test", weight: 70, height: 175, age: 25)
        user.totalXP = 2500
        user.level = 1

        let manager = NutritionProgressManager(user: user)
        XCTAssertEqual(user.level, 1, "Reading or initializing NutritionProgressManager during SwiftUI layout must not mutate SwiftData models")

        manager.syncLevel()
        XCTAssertEqual(user.level, 3)
    }

    func testNutritionMathClampedIntAndScaledValuesPreventOverflow() {
        XCTAssertEqual(NutritionMath.clampedInt(1e25), 999_999)
        XCTAssertEqual(NutritionMath.clampedInt(Double.infinity), 0)
        XCTAssertEqual(NutritionMath.clampedInt(-42), 0)

        let scaled = NutritionMath.scaledValues(
            baseWeight: 100,
            baseCalories: 500,
            baseProtein: 20,
            baseFats: 10,
            baseCarbs: 50,
            targetWeight: 1e25
        )
        XCTAssertEqual(scaled.calories, 999_999)
    }

    func testMaintainGoalProgressUsesToleranceAroundTarget() {
        let withinTolerance = GoalsTabView.computeProgressPercentage(
            goalType: "maintain",
            startWeight: 70,
            currentWeight: 70.8,
            targetWeight: 70
        )
        XCTAssertEqual(withinTolerance, 1.0, accuracy: 0.001)

        let drifting = GoalsTabView.computeProgressPercentage(
            goalType: "maintain",
            startWeight: 70,
            currentWeight: 73.0,
            targetWeight: 70
        )
        XCTAssertEqual(drifting, 0.5, accuracy: 0.01)

        let farOff = GoalsTabView.computeProgressPercentage(
            goalType: "maintain",
            startWeight: 70,
            currentWeight: 76.0,
            targetWeight: 70
        )
        XCTAssertEqual(farOff, 0.0, accuracy: 0.001)
    }
}
