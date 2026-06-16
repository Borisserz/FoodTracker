import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class AnalyticsViewModelTests: XCTestCase {
    var container: ModelContainer!
    var viewModel: AnalyticsViewModel!
    var repository: SummaryRepository!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        repository = SummaryRepository(modelContainer: container)
        viewModel = AnalyticsViewModel(summaryRepository: repository)
    }

    override func tearDownWithError() throws {
        viewModel = nil
        repository = nil
        container = nil
    }

    func testLoadDataDaily() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let summary = DailySummary(date: today)
        try await repository.saveSummary(summary)
        
        viewModel.loadData(for: .day)
        
        // Yield to allow task to finish
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertEqual(viewModel.summaries.count, 1)
        XCTAssertEqual(viewModel.summaries.first?.date, today)
    }
    
    func testLoadDataWeekly() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let lastMonth = Calendar.current.date(byAdding: .day, value: -35, to: today)!
        
        try await repository.saveSummary(DailySummary(date: today))
        try await repository.saveSummary(DailySummary(date: yesterday))
        try await repository.saveSummary(DailySummary(date: lastMonth))
        
        viewModel.loadData(for: .week)
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // It fetches at least 14 days for heatmaps, so lastMonth shouldn't be included.
        XCTAssertEqual(viewModel.summaries.count, 2)
    }
}
