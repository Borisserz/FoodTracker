import Foundation
import Observation

@Observable final class WorkoutSyncManager {
    static let shared = WorkoutSyncManager()

    private let sharedDefaults = UserDefaults(suiteName: "group.com.borisdev.WorkoutTracker")

    private init() {}

    func fetchWorkoutCalories(for date: Date) -> Int {
        let isPromoEnabled = sharedDefaults?.bool(forKey: "show_foodtracker_promo_enabled") ?? false
        guard isPromoEnabled else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let dateKey = "workout_calories_\(dateString)"
        return sharedDefaults?.integer(forKey: dateKey) ?? 0
    }

    func syncWater(_ liters: Double, for date: Date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let dateKey = "water_liters_\(dateString)"
        sharedDefaults?.set(liters, forKey: dateKey)
    }
}
