import Foundation
import SwiftData

@MainActor
@Observable
class AnalyticsViewModel {
    private let summaryRepository: SummaryRepositoryProtocol

    var summaries: [DailySummary] = []

    init(summaryRepository: SummaryRepositoryProtocol) {
        self.summaryRepository = summaryRepository
    }

    func loadData(for period: AnalyticsPeriod) {
        let endDate = Date()
        // Ensure we fetch at least 14 days for the heatmap, or up to 30 days for month period.
        let daysToFetch = max(period.daysCount, 14)
        let startDate = Calendar.current.date(byAdding: .day, value: -daysToFetch, to: endDate)!

        Task {
            do {
                self.summaries = try await summaryRepository.fetchSummaries(startDate: startDate, endDate: endDate)
            } catch {
                print("Failed to load analytics data: \(error)")
            }
        }
    }
}
