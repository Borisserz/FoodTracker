import XCTest
import SwiftData
@testable import FoodTracker

final class SummaryRepositoryTests: XCTestCase {
    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    @MainActor
    func testEnsureSummary() async throws {
        let repo = SummaryRepository(modelContainer: container)
        let date = Date()
        
        let id1 = try await repo.ensureSummaryID(for: date)
        let summary1 = try XCTUnwrap(container.mainContext.model(for: id1) as? DailySummary)
        XCTAssertTrue(summary1.modelContext === container.mainContext)
        
        // Fetching again should return the same summary ID
        let id2 = try await repo.ensureSummaryID(for: date)
        XCTAssertEqual(id1, id2)
    }

    @MainActor
    func testEnsureSummarySameDayDifferentTimes() async throws {
        let repo = SummaryRepository(modelContainer: container)
        let calendar = Calendar.current
        let morning = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!
        let evening = calendar.date(bySettingHour: 21, minute: 45, second: 0, of: Date())!

        let id1 = try await repo.ensureSummaryID(for: morning)
        let id2 = try await repo.ensureSummaryID(for: evening)

        XCTAssertEqual(id1, id2)
        let allIDs = try await repo.fetchSummaryIDs(startDate: calendar.startOfDay(for: morning), endDate: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: morning))!)
        XCTAssertEqual(allIDs.count, 1)
    }

    func testStreakCalculation() async throws {
        let repo = SummaryRepository(modelContainer: container)
        
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!
        
        // Empty summaries don't count towards streak (totalCalories == 0)
        let s1 = DailySummary(date: today)
        let s2 = DailySummary(date: yesterday)
        let s3 = DailySummary(date: twoDaysAgo)
        
        try await repo.saveSummary(s1)
        try await repo.saveSummary(s2)
        try await repo.saveSummary(s3)
        
        var streak = try await repo.calculateCurrentStreak()
        XCTAssertEqual(streak, 0)
        
        // Add calories to make them count (each day owns its own Meal because of the inverse relationship)
        let makeMeal: (Date) -> Meal = { d in
            Meal(
                title: "Test",
                date: d,
                foodItems: [FoodItem(name: "Apple", weight: 100, calories: 100, protein: 0, fats: 0, carbs: 0)]
            )
        }

        s1.addMeal(makeMeal(today))
        s2.addMeal(makeMeal(yesterday))
        s3.addMeal(makeMeal(twoDaysAgo))

        try await repo.saveSummary(s1)
        try await repo.saveSummary(s2)
        try await repo.saveSummary(s3)
        
        streak = try await repo.calculateCurrentStreak()
        XCTAssertEqual(streak, 3)
    }

    @MainActor
    func testEnsureSummaryMergesCloudKitDuplicates() async throws {
        let repo = SummaryRepository(modelContainer: container)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let s1 = DailySummary(
            date: today,
            meals: [Meal(title: "Lunch", date: today, foodItems: [FoodItem(name: "Salad", weight: 200, calories: 320, protein: 12, fats: 18, carbs: 25)])]
        )
        let s2 = DailySummary(
            date: today,
            beverages: [Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 500)]
        )
        try await repo.saveSummary(s1)
        try await repo.saveSummary(s2)

        let ensuredID = try await repo.ensureSummaryID(for: today)
        let fetchedIDs = try await repo.fetchSummaryIDs(
            startDate: today,
            endDate: calendar.date(byAdding: .day, value: 1, to: today)!
        )
        let ensured = try XCTUnwrap(container.mainContext.model(for: ensuredID) as? DailySummary)

        XCTAssertEqual(fetchedIDs.count, 1)
        XCTAssertTrue(ensured.modelContext === container.mainContext)
        XCTAssertEqual(ensured.totalFoodCalories, 320)
        XCTAssertEqual(ensured.totalHydrationLiters, 0.5, accuracy: 0.01)
    }

    @MainActor
    func testFetchSummariesMergesSameDayDuplicatesWithoutPreMerge() async throws {
        let repo = SummaryRepository(modelContainer: container)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let s1 = DailySummary(
            date: yesterday,
            meals: [Meal(title: "Dinner", date: yesterday, foodItems: [FoodItem(name: "Fish", weight: 150, calories: 280, protein: 30, fats: 10, carbs: 0)])]
        )
        let s2 = DailySummary(
            date: yesterday,
            beverages: [Beverage(name: "Juice", icon: "cup.and.saucer.fill", colorHex: "FFAA00", caloriesPerGlass: 90, volumeMl: 250)]
        )
        try await repo.saveSummary(s1)
        try await repo.saveSummary(s2)

        let rangeEnd = calendar.date(byAdding: .day, value: 1, to: today)!
        let fetchedIDs = try await repo.fetchSummaryIDs(startDate: yesterday, endDate: rangeEnd)
        let fetched = fetchedIDs.compactMap { container.mainContext.model(for: $0) as? DailySummary }

        XCTAssertEqual(fetched.count, 1)
        XCTAssertTrue(fetched.first?.modelContext === container.mainContext)
        XCTAssertEqual(fetched.first?.totalCalories, 370)
        XCTAssertEqual(fetched.first?.totalHydrationLiters ?? 0, 0.25, accuracy: 0.01)
    }
}
