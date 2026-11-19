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
    private static let lastSyncedWaterPrefix = "wt_last_synced_water_"
    private static let pendingWidgetWaterPrefix = "pending_hk_water_ml_"
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
        localDefaults: UserDefaults = .standard
    ) {
        let sanitized = max(0, liters)
        let waterKey = Self.waterLitersKey(for: date)
        if let defaults = sharedDefaults ?? defaultSharedDefaults {
            defaults.set(sanitized, forKey: waterKey)
        }
        localDefaults.set(sanitized, forKey: Self.lastSyncedWaterKey(for: date))
    }

    /// Called by WidgetIntents after adding water: updates WorkoutTracker App Group immediately
    /// and queues the widget-added delta so the main app flushes it to Apple Health on next sync.
    func syncWaterFromWidget(
        totalLiters: Double,
        addedMl: Double,
        for date: Date,
        sharedDefaults: UserDefaults? = nil,
        appGroupDefaults: UserDefaults? = nil,
        localDefaults: UserDefaults = .standard
    ) {
        syncWater(totalLiters, for: date, sharedDefaults: sharedDefaults, localDefaults: localDefaults)
        guard addedMl > 0, let ftDefaults = appGroupDefaults ?? defaultFoodTrackerDefaults else { return }
        let pendingKey = Self.pendingHealthKitWaterKey(for: date)
        let currentPending = max(0, ftDefaults.double(forKey: pendingKey))
        ftDefaults.set(currentPending + addedMl, forKey: pendingKey)
    }

    /// Atomically reads and clears queued widget-added hydration (in liters) pending Apple Health sync.
    func consumePendingWidgetWaterLiters(
        for date: Date,
        appGroupDefaults: UserDefaults? = nil
    ) -> Double {
        guard let ftDefaults = appGroupDefaults ?? defaultFoodTrackerDefaults else { return 0 }
        let pendingKey = Self.pendingHealthKitWaterKey(for: date)
        let ml = max(0, ftDefaults.double(forKey: pendingKey))
        if ml > 0 {
            ftDefaults.removeObject(forKey: pendingKey)
        }
        return ml / 1000.0
    }

    /// Pulls external water added from WorkoutTracker into `summary` and keeps App Group aligned.
    /// Returns `true` when `summary` was mutated and needs saving.
    @discardableResult
    func reconcileWater(
        for summary: DailySummary,
        in context: ModelContext,
        sharedDefaults: UserDefaults? = nil,
        localDefaults: UserDefaults = .standard
    ) -> Bool {
        let localWater = summary.totalHydrationLiters
        let lastKey = Self.lastSyncedWaterKey(for: summary.date)
        let lastSynced = localDefaults.object(forKey: lastKey) as? Double

        if let sharedWater = fetchWaterLiters(for: summary.date, sharedDefaults: sharedDefaults) {
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
                    context.insert(syncedDrink)
                    summary.addBeverage(syncedDrink)
                    localDefaults.set(sharedWater, forKey: lastKey)
                    return true
                }
            } else if isExternalDecrease {
                let excessMl = ((localWater - sharedWater) * 1000.0).rounded()
                if excessMl > 0, trimWaterBeverages(excessMl: excessMl, from: summary, in: context) {
                    localDefaults.set(sharedWater, forKey: lastKey)
                    return true
                }
            } else if localWater > sharedWater + 0.01 {
                syncWater(localWater, for: summary.date, sharedDefaults: sharedDefaults, localDefaults: localDefaults)
            }
        } else if localWater > 0.01 {
            syncWater(localWater, for: summary.date, sharedDefaults: sharedDefaults, localDefaults: localDefaults)
        }

        return false
    }

    private func trimWaterBeverages(excessMl: Double, from summary: DailySummary, in context: ModelContext) -> Bool {
        var remainingToTrim = excessMl
        var mutated = false
        let waterEntries = (summary.beverages ?? []).filter { $0.name == "Water" }.reversed()

        for beverage in waterEntries where remainingToTrim > 0.5 {
            if beverage.volumeMl <= remainingToTrim + 0.5 {
                remainingToTrim -= beverage.volumeMl
                summary.beverages?.removeAll { $0.id == beverage.id }
                context.delete(beverage)
                mutated = true
            } else {
                beverage.volumeMl = max(0, beverage.volumeMl - remainingToTrim)
                remainingToTrim = 0
                mutated = true
            }
        }
        return mutated
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
        if let ftDefaults = UserDefaults(suiteName: foodTrackerSuiteName) {
            for key in ftDefaults.dictionaryRepresentation().keys where key.hasPrefix(pendingWidgetWaterPrefix) {
                ftDefaults.removeObject(forKey: key)
            }
        }
    }
}
