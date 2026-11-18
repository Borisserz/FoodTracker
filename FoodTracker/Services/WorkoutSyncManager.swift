import Foundation
import SwiftData

/// Bidirectional App Group & activity bridge with WorkoutTracker (`group.com.borisdev.WorkoutTracker`)
/// and Apple Health workout energy aggregation.
@MainActor
final class WorkoutSyncManager {
    static let shared = WorkoutSyncManager()

    nonisolated static let suiteName = "group.com.borisdev.WorkoutTracker"
    nonisolated static let healthKitBrandName = "FoodTracker"
    private static let lastSyncedWaterPrefix = "wt_last_synced_water_"

    private var defaultSharedDefaults: UserDefaults? {
        UserDefaults(suiteName: Self.suiteName)
    }

    private init() {}

    nonisolated static func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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
            } else if localWater > sharedWater + 0.01 {
                syncWater(localWater, for: summary.date, sharedDefaults: sharedDefaults, localDefaults: localDefaults)
            }
        } else if localWater > 0.01 {
            syncWater(localWater, for: summary.date, sharedDefaults: sharedDefaults, localDefaults: localDefaults)
        }

        return false
    }

    /// Reconciles local activities, WorkoutTracker App Group workouts, and HealthKit active energy
    /// without double-counting WorkoutTracker's own HealthKit entries or FoodTracker's saved HKWorkouts.
    nonisolated static func computeDailyBurn(
        localActivityCalories: Int,
        workoutTrackerCalories: Int,
        healthKitWorkoutCalories: Int,
        healthKitTotalActiveCalories: Int,
        stepsCount: Int,
        isHealthKitEnabled: Bool
    ) -> (workoutCalories: Int, activeCaloriesBurned: Int, stepsCount: Int) {
        let externalWorkouts = max(0, max(workoutTrackerCalories, healthKitWorkoutCalories))
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
    }
}
