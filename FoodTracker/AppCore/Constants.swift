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
        static let privacyPolicyURL = URL(string: "https://borisserz.github.io/foodtracker-privacy/")!
        static let eulaURL = URL(string: "https://borisserz.github.io/foodtracker-privacy/eula.html")!
    }
}
