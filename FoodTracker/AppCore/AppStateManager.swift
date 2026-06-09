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
}
