import SwiftUI
import Observation

@Observable
final class AppStateManager {
    var selectedTab: Int = 0
    var hasCompletedOnboarding: Bool = false
    var isPremiumActivated: Bool = true
    var requestedWidgetAction: String? = nil
    
    init() {
        self.isPremiumActivated = true // All features free
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    func completeOnboarding() {
        self.hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func activatePremium() {
        self.isPremiumActivated = true
        UserDefaults.standard.set(true, forKey: "isPremiumActivated")
    }

    @discardableResult
    func handleWidgetURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "foodtracker" else { return false }
        let route = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        switch route {
        case "hydration", "macros":
            selectedTab = 0
            requestedWidgetAction = route
            return true
        case "metabolic", "analytics":
            selectedTab = 3
            requestedWidgetAction = route
            return true
        case "shopping":
            requestedWidgetAction = "shopping"
            return true
        case "fasting":
            requestedWidgetAction = "fasting"
            return true
        default:
            return false
        }
    }
}
