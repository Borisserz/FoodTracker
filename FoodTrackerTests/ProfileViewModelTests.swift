import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class ProfileViewModelTests: XCTestCase {
    var container: ModelContainer!
    var viewModel: ProfileViewModel!
    var summaryRepo: SummaryRepository!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: User.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        
        summaryRepo = SummaryRepository(modelContainer: container)
        let userRepo = UserRepository(modelContainer: container)
        viewModel = ProfileViewModel(summaryRepository: summaryRepo, userRepository: userRepo)
    }

    override func tearDownWithError() throws {
        viewModel = nil
        summaryRepo = nil
        container = nil
    }

    func testLoadDataInitialStreakIsZero() async throws {
        XCTAssertEqual(viewModel.currentStreak, 0)
        viewModel.loadData()
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(viewModel.currentStreak, 0)
    }

    func testLoadDataCalculatesConsecutiveStreak() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        let s1 = DailySummary(
            date: today,
            meals: [Meal(title: "Breakfast", date: today, foodItems: [FoodItem(name: "Oats", weight: 50, calories: 190, protein: 5, fats: 3, carbs: 32)])]
        )
        let s2 = DailySummary(
            date: yesterday,
            meals: [Meal(title: "Lunch", date: yesterday, foodItems: [FoodItem(name: "Chicken", weight: 150, calories: 250, protein: 35, fats: 5, carbs: 0)])]
        )

        try await summaryRepo.saveSummary(s1)
        try await summaryRepo.saveSummary(s2)

        viewModel.loadData()
        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(viewModel.currentStreak, 2)
    }

    func testMacroPercentagesRebalanceClampedZeroToHundredWithoutNegativeRemainder() {
        let initial = NutritionSettingsEditor.normalizedInitialPercentages(
            dailyCalories: 1500,
            proteinGrams: 300,
            fatGrams: 100,
            carbsGrams: 100
        )
        XCTAssertGreaterThanOrEqual(initial.protein, 0)
        XCTAssertGreaterThanOrEqual(initial.fat, 0)
        XCTAssertGreaterThanOrEqual(initial.carbs, 0)
        XCTAssertEqual(initial.protein + initial.fat + initial.carbs, 100.0, accuracy: 0.01)

        // Increase protein to 85% while fat=25% and carbs=35%: drains carbs (35->0) then spills 10 into fat (25->15).
        let rebalanced = NutritionSettingsEditor.rebalanceMacroPercentages(
            protein: 85,
            fat: 25,
            carbs: 35,
            changed: .protein
        )
        XCTAssertEqual(rebalanced.protein, 85, accuracy: 0.01)
        XCTAssertEqual(rebalanced.carbs, 0, accuracy: 0.01)
        XCTAssertEqual(rebalanced.fat, 15, accuracy: 0.01)
        XCTAssertEqual(rebalanced.protein + rebalanced.fat + rebalanced.carbs, 100.0, accuracy: 0.01)
    }

    func testWeightTrendColorRespectsGoalType() {
        XCTAssertEqual(WeightTrendFormatter.trendColor(diff: 0.8, goalType: "gain"), .green)
        XCTAssertEqual(WeightTrendFormatter.trendColor(diff: -0.8, goalType: "gain"), .red)
        XCTAssertEqual(WeightTrendFormatter.trendColor(diff: -0.8, goalType: "lose"), .green)
        XCTAssertEqual(WeightTrendFormatter.trendColor(diff: 0.8, goalType: "lose"), .red)
        XCTAssertEqual(WeightTrendFormatter.trendColor(diff: 0.2, goalType: "maintain"), .green)
    }
}
