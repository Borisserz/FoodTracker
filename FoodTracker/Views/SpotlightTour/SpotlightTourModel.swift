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
        case .addMeal: return "Нажмите, чтобы добавить еду"
        case .macroRings: return "Нажмите, чтобы открыть баланс БЖУ"
        case .fastingWater: return "Нажмите, чтобы записать воду и голодание"
        case .aiCoach: return "Нажмите, чтобы спросить ИИ-тренера"
        }
    }
    
    var description: String {
        switch self {
        case .addMeal:
            return "Сфотографируйте блюдо, отсканируйте штрихкод или введите название — ИИ мгновенно рассчитает калории и БЖУ."
        case .macroRings:
            return "Следите за суточной нормой калорий, белков, жиров и углеводов в реальном времени."
        case .fastingWater:
            return "Ведите учет выпитой воды в один тап и контролируйте таймер интервального голодания."
        case .aiCoach:
            return "Персональный ИИ-нутрициолог подберет рацион, ответит на любые вопросы и поможет достичь цели."
        }
    }
    
    var tag: String {
        return "Шаг \(rawValue + 1) из \(SpotlightStep.allCases.count)"
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
    private let storageKey = "hasCompletedSpotlightTour_v3"
    
    var hasCompletedTour: Bool {
        get { UserDefaults.standard.bool(forKey: storageKey) }
        set { UserDefaults.standard.set(newValue, forKey: storageKey) }
    }
    
    func startTourIfNeeded() {
        if !hasCompletedTour {
            // Small delay to allow the dashboard to render and measure frames
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
    
    func resetTour() {
        hasCompletedTour = false
        startTourIfNeeded()
    }
}
