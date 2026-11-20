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
    private static let lastSyncedWaterPrefix = "wt_last_synced_water_"
    private static let pendingWidgetWaterPrefix = "pending_hk_water_ml_"
    private static let pendingWidgetWaterEntriesPrefix = "pending_hk_water_entries_"
    private static let gregorianCalendar: Calendar = {
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

    /// Atomically reads and clears queued widget-added hydration entries (in liters) pending Apple Health sync.
    func consumePendingWidgetWaterEntriesLiters(
        for date: Date,
        appGroupDefaults: UserDefaults? = nil
    ) -> [Double] {
        guard let ftDefaults = appGroupDefaults ?? defaultFoodTrackerDefaults else { return [] }
        let entriesKey = Self.pendingHealthKitWaterEntriesKey(for: date)
        let pendingEntries = (ftDefaults.array(forKey: entriesKey) as? [Double])?.filter { $0 > 0 } ?? []
        if ftDefaults.object(forKey: entriesKey) != nil {
            ftDefaults.removeObject(forKey: entriesKey)
        }

        // Drain legacy scalar queue if present from an older build.
        let legacyKey = Self.pendingHealthKitWaterKey(for: date)
        let legacyMl = max(0, ftDefaults.double(forKey: legacyKey))
        if ftDefaults.object(forKey: legacyKey) != nil {
            ftDefaults.removeObject(forKey: legacyKey)
        }

        var result = pendingEntries.map { $0 / 1000.0 }
        if legacyMl > 0 {
            result.append(legacyMl / 1000.0)
        }
        return result
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

    /// Clears FoodTracker-scoped water sync tracking keys without mutating WorkoutTracker's own keys.
    static func clearLocalSyncMetadata(defaults: UserDefaults = .standard) {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(lastSyncedWaterPrefix) {
            defaults.removeObject(forKey: key)
        }
        if defaults === UserDefaults.standard, let ftDefaults = UserDefaults(suiteName: foodTrackerSuiteName) {
            for key in ftDefaults.dictionaryRepresentation().keys
                where key.hasPrefix(lastSyncedWaterPrefix)
                    || key.hasPrefix(pendingWidgetWaterPrefix)
                    || key.hasPrefix(pendingWidgetWaterEntriesPrefix) {
                ftDefaults.removeObject(forKey: key)
            }
        }
    }
}
