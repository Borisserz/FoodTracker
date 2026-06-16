import SwiftUI

@Observable
final class PromoManager {
    static let shared = PromoManager()
    
    var showWidgetPromo: Bool = false
    
    // We use a UserDefaults standard check so we can mutate it outside of a View context easily
    private let firstLaunchKey = "app_first_launch_date"
    private let hasSeenWidgetPromoKey = "has_seen_widget_promo"
    
    // 600 seconds = 10 minutes. Set lower for testing if needed.
    private let promoDelaySeconds: TimeInterval = 600
    
    init() {
        // Record first launch date if not already set
        if UserDefaults.standard.object(forKey: firstLaunchKey) == nil {
            UserDefaults.standard.set(Date(), forKey: firstLaunchKey)
        }
    }
    
    func checkAndShowWidgetPromo() {
        let hasSeen = UserDefaults.standard.bool(forKey: hasSeenWidgetPromoKey)
        if hasSeen { return }
        
        guard let firstLaunch = UserDefaults.standard.object(forKey: firstLaunchKey) as? Date else { return }
        
        let elapsed = Date().timeIntervalSince(firstLaunch)
        if elapsed >= promoDelaySeconds {
            showWidgetPromo = true
        }
    }
    
    func markWidgetPromoAsSeen() {
        UserDefaults.standard.set(true, forKey: hasSeenWidgetPromoKey)
        showWidgetPromo = false
    }
    
    func remindMeLater() {
        // Reset the "first launch date" to now, so it takes another 10 mins
        UserDefaults.standard.set(Date(), forKey: firstLaunchKey)
        showWidgetPromo = false
    }
}
