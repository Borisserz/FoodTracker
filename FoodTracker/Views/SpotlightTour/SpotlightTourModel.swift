import SwiftUI

// MARK: - Spotlight Tour Step Definition
enum SpotlightStep: Int, CaseIterable, Identifiable {
    case addMeal = 0
    case macroRings = 1
    case fastingWater = 2
    case streakFire = 3
    case aiChef = 4
    
    var id: Int { rawValue }
    
    var icon: String {
        switch self {
        case .addMeal: return "camera.viewfinder"
        case .macroRings: return "flame.fill"
        case .fastingWater: return "drop.fill"
        case .streakFire: return "bolt.fill"
        case .aiChef: return "sparkles"
        }
    }
    
    var category: String {
        switch self {
        case .addMeal: return String(localized: "AI SCAN & LOGGING")
        case .macroRings: return String(localized: "METABOLISM & MACROS")
        case .fastingWater: return String(localized: "HYDRATION")
        case .streakFire: return String(localized: "GAMIFICATION & XP")
        case .aiChef: return String(localized: "PERSONAL CHEF")
        }
    }
    
    var title: String {
        switch self {
        case .addMeal: return String(localized: "Smart Meal Logging")
        case .macroRings: return String(localized: "Energy & Macro Balance")
        case .fastingWater: return String(localized: "3D Hydration Flask")
        case .streakFire: return String(localized: "Streak Fire & Level")
        case .aiChef: return String(localized: "AI Chef & Recipes")
        }
    }
    
    var description: String {
        switch self {
        case .addMeal:
            return String(localized: "Snap a photo, scan a barcode, or log by text — AI instantly estimates calories and macros.")
        case .macroRings:
            return String(localized: "Interactive daily rings for calories, protein, fats, and carbs with automatic Apple Health activity sync.")
        case .fastingWater:
            return String(localized: "Live wave-physics flask with volume ticks. Log a glass or bottle of water in one tap.")
        case .streakFire:
            return String(localized: "Keep your daily streak alive, earn XP for hitting nutrition goals, and unlock achievements.")
        case .aiChef:
            return String(localized: "Generate custom recipes from ingredients in your fridge tailored to your remaining daily calories.")
        }
    }
    
    var tag: String {
        return String(localized: "Step \(rawValue + 1) of \(SpotlightStep.allCases.count)")
    }
    
    var accentColor: Color {
        switch self {
        case .addMeal: return Color(red: 0.18, green: 0.86, blue: 0.38)
        case .macroRings: return Color(red: 1.0, green: 0.55, blue: 0.0)
        case .fastingWater: return Color.cyan
        case .streakFire: return Color(red: 1.0, green: 0.82, blue: 0.1)
        case .aiChef: return Color(red: 0.75, green: 0.35, blue: 0.95)
        }
    }
}

// MARK: - Preference Key for Named Coordinate Space Measurement
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
    private let storageKey = "hasCompletedSpotlightTour_v5"
    
    var hasCompletedTour: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
    
    func startTourIfNeeded() {
        if !hasCompletedTour {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                    self.currentStep = .addMeal
                    self.isTourActive = true
                }
            }
        }
    }
    
    func startTourForcefully() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            self.currentStep = .addMeal
            self.isTourActive = true
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
    
    func previousStep() {
        let all = SpotlightStep.allCases
        if let idx = all.firstIndex(of: currentStep), idx > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                currentStep = all[idx - 1]
            }
        }
    }
    
    func finishTour() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isTourActive = false
            hasCompletedTour = true
        }
    }
    
    func resetTour() {
        hasCompletedTour = false
        startTourForcefully()
    }
}
