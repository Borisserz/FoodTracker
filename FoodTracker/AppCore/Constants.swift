import Foundation

public enum Constants {
    public enum UserDefaultsKeys: String, CaseIterable {
        case hasCompletedOnboarding
        case isPremiumActivated
        case userAvatar
        case dailyCaloriesGoal
        case selectedDiet
    }
    
    public enum Legal {
        static let privacyPolicyURL = URL(string: "https://borisserz.github.io/workouttracker-privacy/Privacy%20Policy%20-%20FoodTracker.html")!
        static let eulaURL = URL(string: "https://borisserz.github.io/workouttracker-privacy/Terms%20of%20Use%20-%20FoodTracker.html")!
        static let supportURL = URL(string: "https://borisserz.github.io/workouttracker-privacy/Support-%20FoodTracker.html")!
    }
}
