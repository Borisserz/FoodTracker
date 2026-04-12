import SwiftUI
import SwiftData
import Observation

// MARK: - App Settings (Observable)
@Observable final class AppSettings {
    var soundEnabled: Bool = true
    var notificationsEnabled: Bool = true
    var waterReminderInterval: Int = 60
    var preferredMealCategories: [String] = ["Breakfast", "Lunch", "Snack", "Dinner"]
    var selectedColorTheme: String = "default"
    
    init() {}
}
