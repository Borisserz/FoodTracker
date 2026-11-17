import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class OnboardingBlueprintTests: XCTestCase {

    func testLoseWeightBlueprintMatchesSwissBentoMath() {
        let metrics = OnboardingMetrics(
            age: 30,
            height: 180,
            weight: 80,
            targetWeight: 74,
            goal: "Lose Weight",
            activityLevel: .active
        )

        let blueprint = MetabolicBlueprintCalculator.calculate(for: metrics)

        // BMR = max(1200, Int(10*80 + 6.25*180 - 5*30 + 5)) = 1780
        // TDEE = 1780 * 1.55 = 2759.0; Lose Weight = Int(2759 - 450) = 2309
        XCTAssertEqual(blueprint.bmr, 1780)
        XCTAssertEqual(blueprint.dailyCalories, 2309)
        XCTAssertEqual(blueprint.proteinGrams, 168) // Int(80 * 2.1)
        XCTAssertEqual(blueprint.fatGrams, 64)      // Int(2309 * 0.25 / 9.0)
        XCTAssertEqual(blueprint.carbsGrams, 265)   // (2309 - 168*4 - 64*9) / 4
        XCTAssertEqual(blueprint.weightGoalType, "lose")
        XCTAssertEqual(blueprint.targetWeightKg, 74.0, accuracy: 0.01)
    }

    func testBuildMuscleAndMaintainWeightBlueprints() {
        let bulkMetrics = OnboardingMetrics(
            age: 25,
            height: 175,
            weight: 70,
            targetWeight: 77,
            goal: "Build Muscle",
            activityLevel: .beast
        )
        let bulk = MetabolicBlueprintCalculator.calculate(for: bulkMetrics)
        // BMR = max(1200, Int(700 + 1093.75 - 125 + 5)) = 1673
        // TDEE = 1673 * 1.725 = 2885.925; Build Muscle = Int(2885.925 + 350) = 3235
        XCTAssertEqual(bulk.bmr, 1673)
        XCTAssertEqual(bulk.dailyCalories, 3235)
        XCTAssertEqual(bulk.weightGoalType, "gain")
        XCTAssertEqual(bulk.targetWeightKg, 77.0, accuracy: 0.01)

        let maintainMetrics = OnboardingMetrics(
            age: 25,
            height: 175,
            weight: 72,
            targetWeight: 60, // Should normalize to current weight when maintaining
            goal: "Maintain Weight",
            activityLevel: .light
        )
        let maintain = MetabolicBlueprintCalculator.calculate(for: maintainMetrics)
        XCTAssertEqual(maintain.weightGoalType, "maintain")
        XCTAssertEqual(maintain.targetWeightKg, 72.0, accuracy: 0.01)
    }

    func testOnboardingPersistenceSavesNewAndUpdatesExistingUser() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: User.self, configurations: config)
        let context = container.mainContext

        let firstMetrics = OnboardingMetrics(
            age: 30,
            height: 180,
            weight: 80,
            targetWeight: 74,
            goal: "Lose Weight",
            activityLevel: .active
        )
        OnboardingPersistence.save(metrics: firstMetrics, existingUser: nil, in: context)

        let inserted = try context.fetch(FetchDescriptor<User>())
        XCTAssertEqual(inserted.count, 1)
        let user = try XCTUnwrap(inserted.first)
        XCTAssertEqual(user.dailyCaloriesGoal, 2309)
        XCTAssertEqual(user.targetProtein, 168.0, accuracy: 0.01)
        XCTAssertEqual(user.targetFats, 64.0, accuracy: 0.01)
        XCTAssertEqual(user.targetCarbs, 265.0, accuracy: 0.01)
        XCTAssertEqual(user.targetWeight ?? -1, 74.0, accuracy: 0.01)
        XCTAssertEqual(user.weightGoalType, "lose")

        // Now re-run onboarding on existing user with different goal
        let updatedMetrics = OnboardingMetrics(
            age: 31,
            height: 180,
            weight: 74,
            targetWeight: 80,
            goal: "Build Muscle",
            activityLevel: .beast
        )
        OnboardingPersistence.save(metrics: updatedMetrics, existingUser: user, in: context)

        let refetched = try context.fetch(FetchDescriptor<User>())
        XCTAssertEqual(refetched.count, 1)
        let expected = MetabolicBlueprintCalculator.calculate(for: updatedMetrics)
        XCTAssertEqual(user.age, 31)
        XCTAssertEqual(user.weight, 74.0, accuracy: 0.01)
        XCTAssertEqual(user.dailyCaloriesGoal, expected.dailyCalories)
        XCTAssertEqual(user.targetProtein, Double(expected.proteinGrams), accuracy: 0.01)
        XCTAssertEqual(user.targetFats, Double(expected.fatGrams), accuracy: 0.01)
        XCTAssertEqual(user.targetCarbs, Double(expected.carbsGrams), accuracy: 0.01)
        XCTAssertEqual(user.targetWeight ?? -1, 80.0, accuracy: 0.01)
        XCTAssertEqual(user.weightGoalType, "gain")
    }

    func testMetabolicBlueprintRespectsFemaleBMRAndPersistenceCreatesWeightLog() throws {
        let maleMetrics = OnboardingMetrics(
            age: 28,
            height: 170,
            weight: 62,
            targetWeight: 58,
            goal: "Lose Weight",
            activityLevel: .light,
            gender: "Male"
        )
        let femaleMetrics = OnboardingMetrics(
            age: 28,
            height: 170,
            weight: 62,
            targetWeight: 58,
            goal: "Lose Weight",
            activityLevel: .light,
            gender: "Female"
        )

        let maleBlueprint = MetabolicBlueprintCalculator.calculate(for: maleMetrics)
        let femaleBlueprint = MetabolicBlueprintCalculator.calculate(for: femaleMetrics)

        XCTAssertEqual(maleBlueprint.bmr - femaleBlueprint.bmr, 166)

        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(
            for: User.self, WeightLog.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self,
            configurations: config
        )
        let context = container.mainContext

        OnboardingPersistence.save(metrics: femaleMetrics, existingUser: nil, in: context)

        let users = try context.fetch(FetchDescriptor<User>())
        let logs = try context.fetch(FetchDescriptor<WeightLog>())
        let summaries = try context.fetch(FetchDescriptor<DailySummary>())

        XCTAssertEqual(users.first?.gender, "Female")
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.weight ?? -1, 62.0, accuracy: 0.01)
        XCTAssertEqual(summaries.first?.weight ?? -1, 62.0, accuracy: 0.01)
    }
}
