import Foundation
import SwiftData

/// Bidirectional App Group & activity bridge with WorkoutTracker (`group.com.borisdev.WorkoutTracker`)
/// and Apple Health workout energy aggregation.
@MainActor
final class WorkoutSyncManager {
    static let shared = WorkoutSyncManager()

    nonisolated static let suiteName = "group.com.borisdev.WorkoutTracker"
    nonisolated static let foodTrackerSuiteName = "group.com.borisdev.FoodTracker2026"
    nonisolated static let healthKitBrandName = "FoodTracker"
    nonisolated static let workoutTrackerBrandName = "AI Workout"
    nonisolated static let externalWaterSentinelID = "external:workouttracker"
    private nonisolated static let lastSyncedWaterPrefix = "wt_last_synced_water_"
    private nonisolated static let waterLitersPrefix = "water_liters_"
    private nonisolated static let pendingWidgetWaterPrefix = "pending_hk_water_ml_"
    private nonisolated static let pendingWidgetWaterEntriesPrefix = "pending_hk_water_entries_"
    private nonisolated static let activityHealthKitMapKey = "hk_activity_sample_ids_v1"

    nonisolated static func standardWaterGlassMl(useMetric: Bool) -> Double {
        useMetric ? 250.0 : (8.0 * 29.5735)
    }
    private nonisolated static let gregorianCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        return cal
    }()

    private var defaultSharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.suiteName)
    }

    private var defaultFoodTrackerDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.foodTrackerSuiteName)
    }

    private init() {}

    nonisolated static func dateString(for date: Date) -> String {
        var cal = gregorianCalendar
        cal.timeZone = .current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    nonisolated static func date(fromSuffix suffix: String) -> Date? {
        let parts = suffix.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }
        var cal = gregorianCalendar
        cal.timeZone = .current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        guard let date = cal.date(from: comps) else { return nil }
        let roundTrip = cal.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else {
            return nil
        }
        return date
    }

    nonisolated static func workoutCaloriesKey(for date: Date) -> String {
        "workout_calories_\(dateString(for: date))"
    }

    nonisolated static func waterLitersKey(for date: Date) -> String {
        "water_liters_\(dateString(for: date))"
    }

    nonisolated static func lastSyncedWaterKey(for date: Date) -> String {
        "\(lastSyncedWaterPrefix)\(dateString(for: date))"
    }

    nonisolated static func pendingHealthKitWaterKey(for date: Date) -> String {
        "\(pendingWidgetWaterPrefix)\(dateString(for: date))"
    }

    nonisolated static func pendingHealthKitWaterEntriesKey(for date: Date) -> String {
        "\(pendingWidgetWaterEntriesPrefix)\(dateString(for: date))"
    }

    private func resolveSyncStateDefaults(appGroupDefaults: UserDefaults?, localDefaults: UserDefaults?) -> UserDefaults {
        localDefaults ?? appGroupDefaults ?? defaultFoodTrackerDefaults ?? .standard
    }

    nonisolated static func priorExternalWorkoutCalories(
        totalWorkoutCalories: Int,
        previousLocalActivityCalories: Int
    ) -> Int {
        max(0, totalWorkoutCalories - max(0, previousLocalActivityCalories))
    }

    /// Reads daily calories burned written by WorkoutTracker (`WorkoutStore.syncSharedDailyCalories`).
    func fetchWorkoutCalories(for date: Date, sharedDefaults: UserDefaults? = nil) -> Int {
        guard let defaults = sharedDefaults ?? defaultSharedDefaults else { return 0 }
        let key = Self.workoutCaloriesKey(for: date)
        return max(0, defaults.integer(forKey: key))
    }

    @discardableResult
    func logWaterAndReconcile(
        volumeMl: Double,
        for date: Date,
        in context: ModelContext,
        sharedDefaults: UserDefaults? = nil,
        appGroupDefaults: UserDefaults? = nil,
        localDefaults: UserDefaults? = nil
    ) -> (summary: DailySummary, beverage: Beverage, deletedHealthKitSamples: [DeletedWaterHealthSample]) {
        let summary = DailySummary.fetchOrCreate(for: date, in: context)
        let reconcileOutcome = reconcileWaterWithOutcome(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appGroupDefaults,
            localDefaults: localDefaults
        )
        let newBeverage = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: volumeMl)
        context.insert(newBeverage)
        summary.addBeverage(newBeverage)
        try? context.save()
        syncWater(
            summary.totalPureWaterLiters,
            for: summary.date,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appGroupDefaults,
            localDefaults: localDefaults
        )
        return (summary, newBeverage, reconcileOutcome.deletedHealthKitSamples)
    }

    /// Reads explicit daily hydration in liters from the shared App Group (`HydrationLog`).
    func fetchWaterLiters(for date: Date, sharedDefaults: UserDefaults? = nil) -> Double? {
        guard let defaults = sharedDefaults ?? defaultSharedDefaults else { return nil }
        let key = Self.waterLitersKey(for: date)
        guard defaults.object(forKey: key) != nil else { return nil }
        return max(0, defaults.double(forKey: key))
    }

    /// Writes FoodTracker's daily hydration total to WorkoutTracker's shared App Group.
    func syncWater(
        _ liters: Double,
        for date: Date,
        sharedDefaults: UserDefaults? = nil,
        appGroupDefaults: UserDefaults? = nil,
        localDefaults: UserDefaults? = nil
    ) {
        let sanitized = max(0, liters)
        let waterKey = Self.waterLitersKey(for: date)
        if let defaults = sharedDefaults ?? defaultSharedDefaults {
            defaults.set(sanitized, forKey: waterKey)
        }
        let syncDefaults = resolveSyncStateDefaults(appGroupDefaults: appGroupDefaults, localDefaults: localDefaults)
        syncDefaults.set(sanitized, forKey: Self.lastSyncedWaterKey(for: date))
    }

    /// Called by WidgetIntents after adding water: updates WorkoutTracker App Group immediately
    /// and queues each widget-added delta so the main app flushes distinct HealthKit samples on next sync.
    func syncWaterFromWidget(
        totalLiters: Double,
        addedMl: Double,
        for date: Date,
        sharedDefaults: UserDefaults? = nil,
        appGroupDefaults: UserDefaults? = nil,
        localDefaults: UserDefaults? = nil
    ) {
        syncWater(
            totalLiters,
            for: date,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appGroupDefaults,
            localDefaults: localDefaults
        )
        guard addedMl > 0, let ftDefaults = appGroupDefaults ?? defaultFoodTrackerDefaults else { return }
        let entriesKey = Self.pendingHealthKitWaterEntriesKey(for: date)
        var pendingEntries = (ftDefaults.array(forKey: entriesKey) as? [Double])?.filter { $0 > 0 } ?? []
        pendingEntries.append(addedMl)
        ftDefaults.set(pendingEntries, forKey: entriesKey)
    }

    /// Queues HealthKit water sample deletions produced during a widget-side reconciliation
    /// (e.g. after WorkoutTracker lowered/reset water) so the main app cleans up Apple Health on foreground.
    struct PendingHealthKitWaterDeletion: Codable, Equatable {
        let sampleID: String?
        let volumeMl: Double
        let date: Date
    }

    nonisolated static func pendingHealthKitWaterDeletionsKey(for date: Date) -> String {
        "pending_hk_water_deletions_\(dateString(for: date))"
    }

    func recordPendingWidgetWaterDeletions(
        _ samples: [DeletedWaterHealthSample],
        for date: Date,
        appGroupDefaults: UserDefaults? = nil
    ) {
        let actionable = samples.filter {
            $0.sampleID != Self.externalWaterSentinelID && ($0.sampleID != nil || $0.volumeMl > 0)
        }
        guard !actionable.isEmpty,
              let ftDefaults = appGroupDefaults ?? defaultFoodTrackerDefaults else { return }

        // First cancel out matching unsynced pending widget water entries that haven't been flushed to HealthKit yet.
        let entriesKey = Self.pendingHealthKitWaterEntriesKey(for: date)
        var pendingEntries = (ftDefaults.array(forKey: entriesKey) as? [Double])?.filter { $0 > 0 } ?? []
        var remainingSamples: [DeletedWaterHealthSample] = []

        for sample in actionable {
            if sample.sampleID == nil,
               let matchIndex = pendingEntries.lastIndex(where: { abs($0 - sample.volumeMl) < 1.0 }) {
                pendingEntries.remove(at: matchIndex)
            } else {
                remainingSamples.append(sample)
            }
        }
        if pendingEntries.isEmpty {
            ftDefaults.removeObject(forKey: entriesKey)
        } else {
            ftDefaults.set(pendingEntries, forKey: entriesKey)
        }

        guard !remainingSamples.isEmpty else { return }
        let key = Self.pendingHealthKitWaterDeletionsKey(for: date)
        var existing: [PendingHealthKitWaterDeletion] = []
        if let raw = ftDefaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([PendingHealthKitWaterDeletion].self, from: raw) {
            existing = decoded
        }
        existing.append(contentsOf: remainingSamples.map {
            PendingHealthKitWaterDeletion(sampleID: $0.sampleID, volumeMl: $0.volumeMl, date: date)
        })
        if let encoded = try? JSONEncoder().encode(existing) {
            ftDefaults.set(encoded, forKey: key)
        }
    }

    func clearPendingWidgetWaterQueues(appGroupDefaults: UserDefaults? = nil) {
        guard let ftDefaults = appGroupDefaults ?? defaultFoodTrackerDefaults else { return }
        for key in ftDefaults.dictionaryRepresentation().keys
            where key.hasPrefix(Self.pendingWidgetWaterPrefix)
                || key.hasPrefix(Self.pendingWidgetWaterEntriesPrefix)
                || key.hasPrefix("pending_hk_water_deletions_") {
            ftDefaults.removeObject(forKey: key)
        }
    }

    func consumePendingWidgetWaterDeletions(
        for date: Date,
        appGroupDefaults: UserDefaults? = nil
    ) -> [PendingHealthKitWaterDeletion] {
        guard let ftDefaults = appGroupDefaults ?? defaultFoodTrackerDefaults else { return [] }
        let key = Self.pendingHealthKitWaterDeletionsKey(for: date)
        guard let raw = ftDefaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([PendingHealthKitWaterDeletion].self, from: raw) else {
            return []
        }
        ftDefaults.removeObject(forKey: key)
        return decoded
    }

    /// Reads queued widget-added hydration entries (in liters) without clearing them until Apple Health confirms save.
    func peekPendingWidgetWaterEntriesLiters(
        for date: Date,
        appGroupDefaults: UserDefaults? = nil
    ) -> [Double] {
        guard let ftDefaults = appGroupDefaults ?? defaultFoodTrackerDefaults else { return [] }
        let entriesKey = Self.pendingHealthKitWaterEntriesKey(for: date)
        let pendingEntries = (ftDefaults.array(forKey: entriesKey) as? [Double])?.filter { $0 > 0 } ?? []
        let legacyKey = Self.pendingHealthKitWaterKey(for: date)
        let legacyMl = max(0, ftDefaults.double(forKey: legacyKey))

        var result = pendingEntries.map { $0 / 1000.0 }
        if legacyMl > 0 {
            result.append(legacyMl / 1000.0)
        }
        return result
    }

    /// Removes only acknowledged widget hydration entries after Apple Health save succeeds.
    func acknowledgePendingWidgetWaterEntries(
        syncedIndices: Set<Int>,
        for date: Date,
        appGroupDefaults: UserDefaults? = nil
    ) {
        guard !syncedIndices.isEmpty,
              let ftDefaults = appGroupDefaults ?? defaultFoodTrackerDefaults else { return }
        let entriesKey = Self.pendingHealthKitWaterEntriesKey(for: date)
        let pendingEntries = (ftDefaults.array(forKey: entriesKey) as? [Double])?.filter { $0 > 0 } ?? []
        let remainingEntries = pendingEntries.enumerated().compactMap { idx, ml in
            syncedIndices.contains(idx) ? nil : ml
        }
        if remainingEntries.isEmpty {
            ftDefaults.removeObject(forKey: entriesKey)
        } else {
            ftDefaults.set(remainingEntries, forKey: entriesKey)
        }

        let legacyKey = Self.pendingHealthKitWaterKey(for: date)
        let legacyMl = max(0, ftDefaults.double(forKey: legacyKey))
        if legacyMl > 0 && syncedIndices.contains(pendingEntries.count) {
            ftDefaults.removeObject(forKey: legacyKey)
        }
    }

    func acknowledgePendingWidgetWaterEntries(
        syncedCount: Int,
        for date: Date,
        appGroupDefaults: UserDefaults? = nil
    ) {
        guard syncedCount > 0 else { return }
        acknowledgePendingWidgetWaterEntries(
            syncedIndices: Set(0..<syncedCount),
            for: date,
            appGroupDefaults: appGroupDefaults
        )
    }

    /// Atomically reads and clears queued widget-added hydration entries (in liters) pending Apple Health sync.
    func consumePendingWidgetWaterEntriesLiters(
        for date: Date,
        appGroupDefaults: UserDefaults? = nil
    ) -> [Double] {
        let entries = peekPendingWidgetWaterEntriesLiters(for: date, appGroupDefaults: appGroupDefaults)
        acknowledgePendingWidgetWaterEntries(
            syncedCount: entries.count,
            for: date,
            appGroupDefaults: appGroupDefaults
        )
        return entries
    }

    /// Returns all days whose queued widget water entries should be flushed (selected day, today, and any
    /// older pending widget water days across midnight rollover), deduplicated and sorted ascending.
    func allPendingWidgetWaterFlushDates(
        selectedDate: Date,
        today: Date = Date(),
        appGroupDefaults: UserDefaults? = nil,
        calendar: Calendar = .current
    ) -> [Date] {
        var seenDays: Set<Date> = [
            calendar.startOfDay(for: selectedDate),
            calendar.startOfDay(for: today)
        ]

        if let ftDefaults = appGroupDefaults ?? defaultFoodTrackerDefaults {
            for key in ftDefaults.dictionaryRepresentation().keys {
                let suffix: String?
                if key.hasPrefix(Self.pendingWidgetWaterEntriesPrefix) {
                    suffix = String(key.dropFirst(Self.pendingWidgetWaterEntriesPrefix.count))
                } else if key.hasPrefix(Self.pendingWidgetWaterPrefix) {
                    suffix = String(key.dropFirst(Self.pendingWidgetWaterPrefix.count))
                } else {
                    suffix = nil
                }
                if let suffix,
                   let parsedDate = Self.date(fromSuffix: suffix),
                   !peekPendingWidgetWaterEntriesLiters(for: parsedDate, appGroupDefaults: ftDefaults).isEmpty {
                    seenDays.insert(calendar.startOfDay(for: parsedDate))
                }
            }
        }

        return seenDays.sorted()
    }

    /// Removes a water beverage while reconciling external WorkoutTracker water so shared App Group water is preserved.
    @discardableResult
    func removeWaterAndReconcile(
        _ beverage: Beverage,
        from summary: DailySummary,
        in context: ModelContext,
        sharedDefaults: UserDefaults? = nil,
        appGroupDefaults: UserDefaults? = nil,
        localDefaults: UserDefaults? = nil
    ) -> [DeletedWaterHealthSample] {
        let targetID = beverage.id
        let targetPersistentID = beverage.persistentModelID
        let targetSampleID = beverage.healthKitSampleID
        let targetVolumeMl = beverage.volumeMl

        let outcome = reconcileWaterWithOutcome(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appGroupDefaults,
            localDefaults: localDefaults
        )
        var deletedSamples = outcome.deletedHealthKitSamples

        if let index = summary.beverages?.firstIndex(where: { $0.id == targetID }) {
            let toDelete = summary.beverages![index]
            summary.beverages?.remove(at: index)
            context.delete(toDelete)

            if let partialTrimIndex = deletedSamples.firstIndex(where: { $0.beverageID == targetPersistentID }) {
                deletedSamples[partialTrimIndex].replacementVolumeMl = 0
                deletedSamples[partialTrimIndex].beverageID = nil
            } else {
                deletedSamples.append(
                    DeletedWaterHealthSample(sampleID: targetSampleID, volumeMl: targetVolumeMl)
                )
            }
        }

        try? context.save()
        syncWater(
            summary.totalPureWaterLiters,
            for: summary.date,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appGroupDefaults,
            localDefaults: localDefaults
        )
        return deletedSamples
    }

    /// Atomically reads and clears queued widget-added hydration (in liters) pending Apple Health sync.
    func consumePendingWidgetWaterLiters(
        for date: Date,
        appGroupDefaults: UserDefaults? = nil
    ) -> Double {
        consumePendingWidgetWaterEntriesLiters(for: date, appGroupDefaults: appGroupDefaults).reduce(0, +)
    }

    /// Assigns a saved HealthKit sample UUID to the best-matching untagged Water beverage in `summary`.
    @discardableResult
    static func attachHealthKitSampleID(_ sampleID: UUID, volumeLiters: Double, to summary: DailySummary) -> Bool {
        let targetMl = volumeLiters * 1000.0
        let untagged = (summary.beverages ?? []).filter { $0.name == "Water" && $0.healthKitSampleID == nil }
        guard let match = untagged.first(where: { abs($0.volumeMl - targetMl) < 1.0 }) ?? untagged.first else {
            return false
        }
        match.healthKitSampleID = sampleID.uuidString
        return true
    }

    struct DeletedWaterHealthSample: Equatable {
        let sampleID: String?
        let volumeMl: Double
        var replacementVolumeMl: Double = 0
        var beverageID: PersistentIdentifier? = nil
    }

    struct WaterReconcileOutcome: Equatable {
        let mutated: Bool
        let deletedHealthKitSamples: [DeletedWaterHealthSample]
    }

    /// Pulls external water added from WorkoutTracker into `summary`, keeps App Group aligned,
    /// and reports trimmed HealthKit water samples when an external reset/decrease occurred.
    @discardableResult
    func reconcileWaterWithOutcome(
        for summary: DailySummary,
        in context: ModelContext,
        sharedDefaults: UserDefaults? = nil,
        appGroupDefaults: UserDefaults? = nil,
        localDefaults: UserDefaults? = nil
    ) -> WaterReconcileOutcome {
        let localWater = summary.totalPureWaterLiters
        let lastKey = Self.lastSyncedWaterKey(for: summary.date)
        let syncDefaults = resolveSyncStateDefaults(appGroupDefaults: appGroupDefaults, localDefaults: localDefaults)
        var lastSynced = syncDefaults.object(forKey: lastKey) as? Double
        if lastSynced == nil, localDefaults == nil,
           let legacyLastSynced = UserDefaults.standard.object(forKey: lastKey) as? Double {
            lastSynced = legacyLastSynced
            syncDefaults.set(legacyLastSynced, forKey: lastKey)
        }

        if let sharedWater = fetchWaterLiters(for: summary.date, sharedDefaults: sharedDefaults) {
            if let prevSynced = lastSynced,
               sharedWater > prevSynced + 0.01,
               localWater > prevSynced + 0.01 {
                let externalDeltaMl = ((sharedWater - prevSynced) * 1000.0).rounded()
                if externalDeltaMl > 0 {
                    let syncedDrink = Beverage(
                        name: "Water",
                        icon: "drop.fill",
                        colorHex: "4CA3E6",
                        caloriesPerGlass: 0,
                        volumeMl: externalDeltaMl
                    )
                    syncedDrink.healthKitSampleID = Self.externalWaterSentinelID
                    context.insert(syncedDrink)
                    summary.addBeverage(syncedDrink)
                    let mergedTotal = summary.totalPureWaterLiters
                    syncWater(
                        mergedTotal,
                        for: summary.date,
                        sharedDefaults: sharedDefaults,
                        appGroupDefaults: appGroupDefaults,
                        localDefaults: localDefaults
                    )
                    return WaterReconcileOutcome(mutated: true, deletedHealthKitSamples: [])
                }
            }

            let deltaLiters = sharedWater - localWater
            let isExternalIncrease = deltaLiters > 0.01 && (lastSynced == nil || abs(sharedWater - lastSynced!) > 0.005)
            let isExternalDecrease = lastSynced != nil
                && sharedWater < lastSynced! - 0.01
                && abs(localWater - lastSynced!) <= 0.01

            if isExternalIncrease {
                let deltaMl = (deltaLiters * 1000.0).rounded()
                if deltaMl > 0 {
                    let syncedDrink = Beverage(
                        name: "Water",
                        icon: "drop.fill",
                        colorHex: "4CA3E6",
                        caloriesPerGlass: 0,
                        volumeMl: deltaMl
                    )
                    syncedDrink.healthKitSampleID = Self.externalWaterSentinelID
                    context.insert(syncedDrink)
                    summary.addBeverage(syncedDrink)
                    syncDefaults.set(sharedWater, forKey: lastKey)
                    return WaterReconcileOutcome(mutated: true, deletedHealthKitSamples: [])
                }
            } else if isExternalDecrease {
                let excessMl = ((localWater - sharedWater) * 1000.0).rounded()
                if excessMl > 0 {
                    let trimResult = trimWaterBeverages(excessMl: excessMl, from: summary, in: context)
                    if trimResult.mutated {
                        syncDefaults.set(sharedWater, forKey: lastKey)
                        return WaterReconcileOutcome(
                            mutated: true,
                            deletedHealthKitSamples: trimResult.deletedSamples
                        )
                    }
                }
            } else if localWater > sharedWater + 0.01 {
                syncWater(
                    localWater,
                    for: summary.date,
                    sharedDefaults: sharedDefaults,
                    appGroupDefaults: appGroupDefaults,
                    localDefaults: localDefaults
                )
            }
        } else if localWater > 0.01 {
            syncWater(
                localWater,
                for: summary.date,
                sharedDefaults: sharedDefaults,
                appGroupDefaults: appGroupDefaults,
                localDefaults: localDefaults
            )
        }

        return WaterReconcileOutcome(mutated: false, deletedHealthKitSamples: [])
    }

    @discardableResult
    func reconcileWater(
        for summary: DailySummary,
        in context: ModelContext,
        sharedDefaults: UserDefaults? = nil,
        appGroupDefaults: UserDefaults? = nil,
        localDefaults: UserDefaults? = nil
    ) -> Bool {
        reconcileWaterWithOutcome(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appGroupDefaults,
            localDefaults: localDefaults
        ).mutated
    }

    private func trimWaterBeverages(
        excessMl: Double,
        from summary: DailySummary,
        in context: ModelContext
    ) -> (mutated: Bool, deletedSamples: [DeletedWaterHealthSample]) {
        var remainingToTrim = excessMl
        var mutated = false
        var deletedSamples: [DeletedWaterHealthSample] = []
        let waterEntries = (summary.beverages ?? []).filter { $0.name == "Water" }.reversed()

        for beverage in waterEntries where remainingToTrim > 0.5 {
            if beverage.volumeMl <= remainingToTrim + 0.5 {
                remainingToTrim -= beverage.volumeMl
                deletedSamples.append(
                    DeletedWaterHealthSample(sampleID: beverage.healthKitSampleID, volumeMl: beverage.volumeMl)
                )
                summary.beverages?.removeAll { $0.id == beverage.id }
                context.delete(beverage)
                mutated = true
            } else {
                let originalMl = beverage.volumeMl
                let oldSampleID = beverage.healthKitSampleID
                let remainingMl = max(0, originalMl - remainingToTrim)
                beverage.volumeMl = remainingMl
                beverage.healthKitSampleID = nil
                deletedSamples.append(
                    DeletedWaterHealthSample(
                        sampleID: oldSampleID,
                        volumeMl: originalMl,
                        replacementVolumeMl: remainingMl,
                        beverageID: beverage.persistentModelID
                    )
                )
                remainingToTrim = 0
                mutated = true
            }
        }
        return (mutated, deletedSamples)
    }

    /// Reconciles local activities, WorkoutTracker App Group workouts, and HealthKit active energy
    /// without double-counting WorkoutTracker's own HealthKit entries or dropping Apple Watch workouts.
    nonisolated static func computeDailyBurn(
        localActivityCalories: Int,
        workoutTrackerCalories: Int,
        healthKitWorkoutCalories: Int,
        otherExternalWorkoutCalories: Int = 0,
        healthKitTotalActiveCalories: Int,
        stepsCount: Int,
        isHealthKitEnabled: Bool
    ) -> (workoutCalories: Int, activeCaloriesBurned: Int, stepsCount: Int) {
        let wtAndSharedWorkouts = max(0, max(workoutTrackerCalories, healthKitWorkoutCalories))
        let externalWorkouts = wtAndSharedWorkouts + max(0, otherExternalWorkoutCalories)
        let totalWorkouts = max(0, localActivityCalories) + externalWorkouts

        if isHealthKitEnabled {
            let activeBurn = max(max(0, healthKitTotalActiveCalories), totalWorkouts)
            return (totalWorkouts, activeBurn, max(0, stepsCount))
        } else {
            return (totalWorkouts, totalWorkouts, 0)
        }
    }

    private static func activityHealthKitStorageKey(
        title: String,
        date: Date,
        calories: Int,
        durationMinutes: Int
    ) -> String {
        "\(Int(date.timeIntervalSince1970))|\(calories)|\(durationMinutes)|\(title)"
    }

    func storeActivityHealthKitIDs(
        workoutID: String?,
        energySampleID: String?,
        title: String,
        date: Date,
        calories: Int,
        durationMinutes: Int,
        defaults: UserDefaults = .standard
    ) {
        guard workoutID != nil || energySampleID != nil else { return }
        let key = Self.activityHealthKitStorageKey(
            title: title,
            date: date,
            calories: calories,
            durationMinutes: durationMinutes
        )
        var map = defaults.dictionary(forKey: Self.activityHealthKitMapKey) as? [String: [String]] ?? [:]
        map[key] = [workoutID ?? "", energySampleID ?? ""]
        defaults.set(map, forKey: Self.activityHealthKitMapKey)
    }

    func consumeActivityHealthKitIDs(
        title: String,
        date: Date,
        calories: Int,
        durationMinutes: Int,
        defaults: UserDefaults = .standard
    ) -> (workoutID: String?, energySampleID: String?) {
        let key = Self.activityHealthKitStorageKey(
            title: title,
            date: date,
            calories: calories,
            durationMinutes: durationMinutes
        )
        var map = defaults.dictionary(forKey: Self.activityHealthKitMapKey) as? [String: [String]] ?? [:]
        guard let pair = map.removeValue(forKey: key) else {
            return (nil, nil)
        }
        defaults.set(map, forKey: Self.activityHealthKitMapKey)
        let workoutID = pair.first.flatMap { $0.isEmpty ? nil : $0 }
        let energyID = pair.count > 1 ? (pair[1].isEmpty ? nil : pair[1]) : nil
        return (workoutID, energyID)
    }

    /// Clears FoodTracker-scoped water sync tracking keys without mutating WorkoutTracker's own keys,
    /// while anchoring `wt_last_synced_water_*` to any existing WorkoutTracker values so pre-wipe water isn't re-imported.
    static func clearLocalSyncMetadata(
        defaults: UserDefaults = .standard,
        sharedDefaults: UserDefaults? = nil,
        appGroupDefaults: UserDefaults? = nil
    ) {
        defaults.removeObject(forKey: activityHealthKitMapKey)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(lastSyncedWaterPrefix) {
            defaults.removeObject(forKey: key)
        }

        let effectiveShared = sharedDefaults ?? UserDefaults(suiteName: suiteName)
        var existingSharedWaterByDateSuffix: [String: Double] = [:]
        if let effectiveShared {
            for (key, value) in effectiveShared.dictionaryRepresentation() where key.hasPrefix(waterLitersPrefix) {
                let dateSuffix = String(key.dropFirst(waterLitersPrefix.count))
                if let liters = value as? Double, liters > 0 {
                    existingSharedWaterByDateSuffix[dateSuffix] = liters
                } else if let num = value as? NSNumber, num.doubleValue > 0 {
                    existingSharedWaterByDateSuffix[dateSuffix] = num.doubleValue
                }
            }
        }

        let effectiveAppGroup = appGroupDefaults ?? (defaults === UserDefaults.standard ? UserDefaults(suiteName: foodTrackerSuiteName) : defaults)
        if let effectiveAppGroup {
            for key in effectiveAppGroup.dictionaryRepresentation().keys
                where key.hasPrefix(lastSyncedWaterPrefix)
                    || key.hasPrefix(pendingWidgetWaterPrefix)
                    || key.hasPrefix(pendingWidgetWaterEntriesPrefix) {
                effectiveAppGroup.removeObject(forKey: key)
            }
            for (dateSuffix, liters) in existingSharedWaterByDateSuffix {
                effectiveAppGroup.set(liters, forKey: "\(lastSyncedWaterPrefix)\(dateSuffix)")
            }
        }
        if defaults !== effectiveAppGroup {
            for (dateSuffix, liters) in existingSharedWaterByDateSuffix {
                defaults.set(liters, forKey: "\(lastSyncedWaterPrefix)\(dateSuffix)")
            }
        }
    }
}
