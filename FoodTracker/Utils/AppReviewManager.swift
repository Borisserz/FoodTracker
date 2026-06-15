import Foundation
import StoreKit
import SwiftUI

@MainActor
final class AppReviewManager {
    static let shared = AppReviewManager()
    
    @AppStorage("loggedMealsCount") private var loggedMealsCount = 0
    @AppStorage("lastReviewPromptAppVersion") private var lastReviewPromptAppVersion = ""
    
    private init() {}
    
    func userDidLogMeal() {
        loggedMealsCount += 1
        
        // Ask for review on the 3rd, 15th, and 50th meal logged
        let milestones = [3, 15, 50]
        
        if milestones.contains(loggedMealsCount) {
            requestReview()
        }
    }
    
    private func requestReview() {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        
        // Avoid spamming the user on the same app version
        guard currentVersion != lastReviewPromptAppVersion else { return }
        
        // Delay slightly so it doesn't interrupt the immediate UI action
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                SKStoreReviewController.requestReview(in: windowScene)
                self.lastReviewPromptAppVersion = currentVersion
            }
        }
    }

    static func openAppStoreReview() {
        guard let url = URL(string: "https://apps.apple.com/app/id6778506345?action=write-review") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
