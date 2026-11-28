import Foundation
import SwiftData

@MainActor
@Observable
class AnalyticsViewModel {
    private let summaryRepository: SummaryRepositoryProtocol
    private var loadTask: Task<Void, Never>?

    var summaries: [DailySummary] = []

    init(summaryRepository: SummaryRepositoryProtocol) {
        self.summaryRepository = summaryRepository
    }

    func loadData(for period: AnalyticsPeriod) {
        loadTask?.cancel()

        let endDate = Date()
        // Ensure we fetch at least 14 days for the heatmap, or up to 30 days for month period.
        let daysToFetch = max(period.daysCount, 14)
        let todayStart = Calendar.current.startOfDay(for: endDate)
        let startDate = Calendar.current.date(byAdding: .day, value: -daysToFetch, to: todayStart)!

        loadTask = Task {
            do {
                guard let mainContext = summaryRepository.mainModelContainer?.mainContext else {
                    self.summaries = []
                    return
                }
                let ids = try await summaryRepository.fetchSummaryIDs(startDate: startDate, endDate: endDate)
                guard !Task.isCancelled else { return }
                self.summaries = ids.compactMap { mainContext.model(for: $0) as? DailySummary }
            } catch is CancellationError {
                return
            } catch {
                #if DEBUG
                print("Failed to load analytics data: \(error)")
                #endif
            }
        }
    }
}
