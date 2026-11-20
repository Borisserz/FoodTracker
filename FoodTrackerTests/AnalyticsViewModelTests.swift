import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class AnalyticsViewModelTests: XCTestCase {
    var container: ModelContainer!
    var viewModel: AnalyticsViewModel!
    var repository: SummaryRepository!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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

    func testLoadDataIncludesStartOfDayOnOldestDayInPeriod() async throws {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let fourteenDaysAgoStart = calendar.date(byAdding: .day, value: -14, to: todayStart)!

        try await repository.saveSummary(DailySummary(date: fourteenDaysAgoStart))

        viewModel.loadData(for: .week)
        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(viewModel.summaries.count, 1)
        XCTAssertTrue(calendar.isDate(try XCTUnwrap(viewModel.summaries.first?.date), inSameDayAs: fourteenDaysAgoStart))
    }

    func testLoadedSummariesAreBoundToMainModelContext() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        try await repository.saveSummary(DailySummary(date: today))

        viewModel.loadData(for: .day)
        try await Task.sleep(nanoseconds: 150_000_000)

        let loaded = try XCTUnwrap(viewModel.summaries.first)
        XCTAssertTrue(loaded.modelContext === container.mainContext)
    }

    func testRapidPeriodSwitchingCancelsStaleLoad() async throws {
        let today = Calendar.current.startOfDay(for: Date())
        let summary = DailySummary(date: today)
        container.mainContext.insert(summary)
        try container.mainContext.save()

        let slowDelayRepo = DelayedSummaryRepository(
            container: container,
            monthDelayNanoseconds: 350_000_000,
            dayDelayNanoseconds: 10_000_000,
            monthIDs: [],
            dayIDs: [summary.persistentModelID]
        )
        let racedVM = AnalyticsViewModel(summaryRepository: slowDelayRepo)

        racedVM.loadData(for: .month)
        try await Task.sleep(nanoseconds: 20_000_000)
        racedVM.loadData(for: .day)

        try await Task.sleep(nanoseconds: 450_000_000)
        XCTAssertEqual(racedVM.summaries.count, 1, "Fast .day load must not be overwritten by slower cancelled .month load")
    }
}

private final class DelayedSummaryRepository: SummaryRepositoryProtocol, @unchecked Sendable {
    let mainModelContainer: ModelContainer?
    let monthDelayNanoseconds: UInt64
    let dayDelayNanoseconds: UInt64
    let monthIDs: [PersistentIdentifier]
    let dayIDs: [PersistentIdentifier]

    init(
        container: ModelContainer,
        monthDelayNanoseconds: UInt64,
        dayDelayNanoseconds: UInt64,
        monthIDs: [PersistentIdentifier],
        dayIDs: [PersistentIdentifier]
    ) {
        self.mainModelContainer = container
        self.monthDelayNanoseconds = monthDelayNanoseconds
        self.dayDelayNanoseconds = dayDelayNanoseconds
        self.monthIDs = monthIDs
        self.dayIDs = dayIDs
    }

    func fetchSummaryID(for date: Date) async throws -> PersistentIdentifier? { nil }
    func saveSummary(_ summary: DailySummary) async throws {}
    func fetchAllTimeCalories() async throws -> Int { 0 }
    func calculateCurrentStreak() async throws -> Int { 0 }
    func ensureSummaryID(for date: Date) async throws -> PersistentIdentifier { fatalError("unused") }

    func fetchSummaryIDs(startDate: Date, endDate: Date) async throws -> [PersistentIdentifier] {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let delay = days >= 25 ? monthDelayNanoseconds : dayDelayNanoseconds
        try await Task.sleep(nanoseconds: delay)
        return days >= 25 ? monthIDs : dayIDs
    }
}
