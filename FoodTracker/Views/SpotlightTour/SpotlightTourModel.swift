import SwiftUI

// MARK: - Spotlight Tour Step Definition
enum SpotlightStep: Int, CaseIterable, Identifiable {
    case addMeal = 0
    case macroRings = 1
    case fastingWater = 2
    case aiCoach = 3
    
    var id: Int { rawValue }
    
    var icon: String {
        switch self {
        case .addMeal: return "plus.circle.fill"
        case .macroRings: return "chart.pie.fill"
        case .fastingWater: return "drop.fill"
        case .aiCoach: return "sparkles"
        }
    }
    
    var title: String {
        switch self {
        case .addMeal: return "Quick Meal Scanner"
        case .macroRings: return "Daily Macro Engine"
        case .fastingWater: return "Fasting & Hydration"
        case .aiCoach: return "AI Nutrition Coach"
        }
    }
    
    var description: String {
        switch self {
        case .addMeal:
            return "Tap here to instantly snap a photo of your dish or scan a barcode. AI detects macros in seconds!"
        case .macroRings:
            return "Monitor your real-time caloric deficit, protein synthesis, and daily nutrient targets."
        case .fastingWater:
            return "Track your 16:8 fasting window and log water with interactive fluid waves."
        case .aiCoach:
            return "Get personalized meal recommendations and ask your AI coach for nutritional advice."
        }
    }
    
    var tag: String {
        return "\(rawValue + 1)/\(SpotlightStep.allCases.count)"
    }
}

// MARK: - Preference Key for Global Coordinate Measurement
struct SpotlightFramePreferenceKey: PreferenceKey {
    static var defaultValue: [SpotlightStep: CGRect] = [:]
    
    static func reduce(value: inout [SpotlightStep: CGRect], nextValue: () -> [SpotlightStep: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Tour Manager
@Observable
final class SpotlightTourManager {
    static let shared = SpotlightTourManager()
    
    var isTourActive: Bool = false
    var currentStep: SpotlightStep = .addMeal
    var targetFrames: [SpotlightStep: CGRect] = [:]
    
    @ObservationIgnored
    private let storageKey = "hasCompletedSpotlightTour_v2"
    
    var hasCompletedTour: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
    
    func startTourIfNeeded() {
        if !hasCompletedTour {
            // Small delay to allow the dashboard to render and measure frames
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    self.currentStep = .addMeal
                    self.isTourActive = true
                }
            }
        }
    }
    
    func nextStep() {
        let all = SpotlightStep.allCases
        if let idx = all.firstIndex(of: currentStep), idx + 1 < all.count {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                currentStep = all[idx + 1]
            }
        } else {
            finishTour()
        }
    }
    
    func finishTour() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isTourActive = false
            hasCompletedTour = true
        }
    }
    
    func replayTour() {
        hasCompletedTour = false
        currentStep = .addMeal
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            isTourActive = true
        }
    }
}
