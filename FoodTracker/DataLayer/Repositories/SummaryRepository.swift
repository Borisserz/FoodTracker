import Foundation
import SwiftData

protocol SummaryRepositoryProtocol: Sendable {
    var mainModelContainer: ModelContainer? { get }
    func fetchSummaryID(for date: Date) async throws -> PersistentIdentifier?
    func saveSummary(_ summary: DailySummary) async throws
    func fetchAllTimeCalories() async throws -> Int
    func calculateCurrentStreak() async throws -> Int
    func fetchSummaryIDs(startDate: Date, endDate: Date) async throws -> [PersistentIdentifier]
    func ensureSummaryID(for date: Date) async throws -> PersistentIdentifier
}

extension SummaryRepositoryProtocol {
    var mainModelContainer: ModelContainer? { nil }
}

@ModelActor
actor SummaryRepository: SummaryRepositoryProtocol {
    nonisolated var mainModelContainer: ModelContainer? { modelContainer }
    // modelContext and init(modelContainer:) are provided by the @ModelActor macro.
    // We removed the custom init to avoid redeclaration with the synthesized one.

    func fetchSummaryID(for date: Date) async throws -> PersistentIdentifier? {
        try fetchSummary(for: date)?.persistentModelID
    }

    private func fetchSummary(for date: Date) throws -> DailySummary? {
        var didMerge = false
        let summary = DailySummary.fetchExisting(for: date, in: modelContext, didMerge: &didMerge)
        if didMerge {
            try modelContext.save()
        }
        return summary
    }

    func saveSummary(_ summary: DailySummary) async throws {
        modelContext.insert(summary)
        try modelContext.save()
        WidgetReloader.reloadAll()
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
        let fetchDescriptor = FetchDescriptor<DailySummary>(
            sortBy: [SortDescriptor(\DailySummary.date, order: .reverse)]
        )
        let summaries = try modelContext.fetch(fetchDescriptor)
        return NutritionMath.consecutiveStreak(from: summaries)
    }

    private func fetchSummaries(startDate: Date, endDate: Date) throws -> [DailySummary] {
        let predicate = #Predicate<DailySummary> { $0.date >= startDate && $0.date <= endDate }
        let fetchDescriptor = FetchDescriptor<DailySummary>(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .forward)])
        let rawSummaries = try modelContext.fetch(fetchDescriptor)

        let calendar = Calendar.current
        var seenDays: [Date: Int] = [:]
        var duplicateDays: Set<Date> = []
        for summary in rawSummaries {
            let day = calendar.startOfDay(for: summary.date)
            seenDays[day, default: 0] += 1
            if seenDays[day, default: 0] > 1 {
                duplicateDays.insert(day)
            }
        }

        guard !duplicateDays.isEmpty else {
            return rawSummaries
        }

        var didMerge = false
        for day in duplicateDays {
            _ = DailySummary.fetchExisting(for: day, in: modelContext, didMerge: &didMerge)
        }
        if didMerge {
            try modelContext.save()
        }

        return try modelContext.fetch(fetchDescriptor)
    }

    func fetchSummaryIDs(startDate: Date, endDate: Date) async throws -> [PersistentIdentifier] {
        let summaries = try fetchSummaries(startDate: startDate, endDate: endDate)
        return summaries.map(\.persistentModelID)
    }

    /// Ensures a DailySummary exists for the given date (creates + saves if missing) and returns its Sendable PersistentIdentifier.
    func ensureSummaryID(for date: Date) async throws -> PersistentIdentifier {
        if let existing = try fetchSummary(for: date) {
            return existing.persistentModelID
        }
        let startOfDay = Calendar.current.startOfDay(for: date)
        let newSummary = DailySummary(date: startOfDay)
        try await saveSummary(newSummary)
        return (try fetchSummary(for: date) ?? newSummary).persistentModelID
    }
}
