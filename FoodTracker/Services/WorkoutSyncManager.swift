import Foundation
import Observation

@Observable final class WorkoutSyncManager {
    static let shared = WorkoutSyncManager()

    private let sharedDefaults = UserDefaults(suiteName: "group.com.borisdev.WorkoutTracker")

    private init() {}

    func fetchWorkoutCalories(for date: Date) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let dateKey = "workout_calories_\(dateString)"
        return sharedDefaults?.integer(forKey: dateKey) ?? 0
    }
}
