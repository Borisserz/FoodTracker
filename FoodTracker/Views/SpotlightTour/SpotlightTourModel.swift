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
        case .addMeal: return "ИИ-СКАНИРОВАНИЕ & ЛОГИНГ"
        case .macroRings: return "МЕТАБОЛИЗМ & БЖУ"
        case .fastingWater: return "ВОДНЫЙ БАЛАНС"
        case .streakFire: return "ГЕЙМИФИКАЦИЯ & XP"
        case .aiChef: return "ПЕРСОНАЛЬНЫЙ ШЕФ"
        }
    }
    
    var title: String {
        switch self {
        case .addMeal: return "Умное добавление еды"
        case .macroRings: return "Энергетический баланс и БЖУ"
        case .fastingWater: return "3D Колба гидратации"
        case .streakFire: return "Огненный стрик и уровень"
        case .aiChef: return "Студия питания и рецепты"
        }
    }
    
    var description: String {
        switch self {
        case .addMeal:
            return "Сфотографируйте блюдо, отсканируйте штрихкод или запишите голосом — нейросеть моментально определит калории и макросы."
        case .macroRings:
            return "Интерактивные кольца суточной нормы калорий, белков, жиров и углеводов с авто-синхронизацией активности Apple Health."
        case .fastingWater:
            return "Живая колба с синусоидальной физикой волн и мерной шкалой. Быстро отмечайте стакан или бутылку воды в один тап."
        case .streakFire:
            return "Сохраняйте серию дней без пропусков, зарабатывайте XP за закрытие целей и открывайте редкие достижения."
        case .aiChef:
            return "Генерируйте уникальные рецепты из продуктов в холодильнике с идеальной подгонкой под оставшиеся на день калории."
        }
    }
    
    var tag: String {
        return "Шаг \(rawValue + 1) из \(SpotlightStep.allCases.count)"
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
