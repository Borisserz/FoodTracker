import XCTest
import SwiftData
@testable import FoodTracker

final class SummaryRepositoryTests: XCTestCase {
    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    func testEnsureSummary() async throws {
        let repo = SummaryRepository(modelContainer: container)
        let date = Date()
        
        let summary1 = try await repo.ensureSummary(for: date)
        XCTAssertNotNil(summary1)
        
        // Fetching again should return the same summary
        let summary2 = try await repo.ensureSummary(for: date)
        XCTAssertEqual(summary1.persistentModelID, summary2.persistentModelID)
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
        
        // Add calories to make them count
        let meal = Meal(title: "Test", date: today, foodItems: [FoodItem(name: "Apple", weight: 100, calories: 100, protein: 0, fats: 0, carbs: 0)])
        
        s1.meals = [meal]
        s2.meals = [meal]
        s3.meals = [meal]
        
        try await repo.saveSummary(s1)
        try await repo.saveSummary(s2)
        try await repo.saveSummary(s3)
        
        streak = try await repo.calculateCurrentStreak()
        XCTAssertEqual(streak, 3)
    }
}
