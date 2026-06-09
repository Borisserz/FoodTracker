import Foundation
import SwiftData

protocol SummaryRepositoryProtocol: Sendable {
    func fetchSummary(for date: Date) async throws -> DailySummary?
    func saveSummary(_ summary: DailySummary) async throws
    func fetchAllTimeCalories() async throws -> Int
    func calculateCurrentStreak() async throws -> Int
    func fetchSummaries(startDate: Date, endDate: Date) async throws -> [DailySummary]
    func ensureSummary(for date: Date) async throws -> DailySummary
}

@ModelActor
actor SummaryRepository: SummaryRepositoryProtocol {
    // modelContext and init(modelContainer:) are provided by the @ModelActor macro.
    // We removed the custom init to avoid redeclaration with the synthesized one.

    func fetchSummary(for date: Date) async throws -> DailySummary? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<DailySummary> { summary in
            summary.date >= startOfDay && summary.date < endOfDay
        }

        var fetchDescriptor = FetchDescriptor<DailySummary>(predicate: predicate)
        fetchDescriptor.fetchLimit = 1

        return try modelContext.fetch(fetchDescriptor).first
    }

    func saveSummary(_ summary: DailySummary) async throws {
        modelContext.insert(summary)
        try modelContext.save()
    }

    func fetchAllTimeCalories() async throws -> Int {
        // We have to fetch the full objects because totalCalories is a computed property
        // (depends on relationships to meals and beverages).
        // For a true aggregate without loading everything, we would need to persist the total
        // or use a different query strategy.
        let fetchDescriptor = FetchDescriptor<DailySummary>()
        let summaries = try modelContext.fetch(fetchDescriptor)
        return summaries.reduce(0) { $0 + $1.totalCalories }
    }

    func calculateCurrentStreak() async throws -> Int {
        // Fetch full objects so we can access the computed totalCalories.
        var fetchDescriptor = FetchDescriptor<DailySummary>(
            sortBy: [SortDescriptor(\DailySummary.date, order: .reverse)]
        )
        let summaries = try modelContext.fetch(fetchDescriptor)

        let calendar = Calendar.current
        let activeDates = summaries
            .filter { $0.totalCalories > 0 }
            .map { calendar.startOfDay(for: $0.date) }

        guard let firstDate = activeDates.first else { return 0 }
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        if firstDate != today && firstDate != yesterday {
            return 0
        }

        var streak = 1
        var currentDate = firstDate
        for date in activeDates.dropFirst() {
            if let expected = calendar.date(byAdding: .day, value: -1, to: currentDate), date == expected {
                streak += 1
                currentDate = date
            } else if date == currentDate {
                continue
            } else {
                break
            }
        }
        return streak
    }

    func fetchSummaries(startDate: Date, endDate: Date) async throws -> [DailySummary] {
        let predicate = #Predicate<DailySummary> { $0.date >= startDate && $0.date <= endDate }
        let fetchDescriptor = FetchDescriptor<DailySummary>(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .forward)])
        return try modelContext.fetch(fetchDescriptor)
    }

    /// Ensures a DailySummary exists for the given date (creates + saves if missing).
    /// Returns the object fetched in the actor's isolated context.
    func ensureSummary(for date: Date) async throws -> DailySummary {
        if let existing = try await fetchSummary(for: date) {
            return existing
        }
        let startOfDay = Calendar.current.startOfDay(for: date)
        let newSummary = DailySummary(date: startOfDay)
        try await saveSummary(newSummary)
        // Re-fetch to return a properly attached instance from this context
        return try await fetchSummary(for: date) ?? newSummary
    }
}
