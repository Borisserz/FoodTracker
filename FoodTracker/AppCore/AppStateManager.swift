import SwiftUI
import Observation

enum CrossAppLinkResolver {
    static let workoutTrackerAppURL = URL(string: "workouttracker://")!
    static let workoutTrackerStoreURL = URL(string: "https://apps.apple.com/app/id6774895106")!

    @MainActor
    static func openWorkoutTracker() {
        if UIApplication.shared.canOpenURL(workoutTrackerAppURL) {
            UIApplication.shared.open(workoutTrackerAppURL)
        } else {
            UIApplication.shared.open(workoutTrackerStoreURL)
        }
    }
}

@Observable
final class AppStateManager {
    var selectedTab: Int = 0
    var hasCompletedOnboarding: Bool = false
    var isPremiumActivated: Bool = true
    var requestedWidgetAction: String? = nil
    var spotlightTourRestartToken: Int = 0

    func requestSpotlightTourRestart() {
        spotlightTourRestartToken += 1
    }
    
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
        case "":
            selectedTab = 0
            requestedWidgetAction = nil
            return true
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
