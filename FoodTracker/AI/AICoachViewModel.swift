import SwiftUI
import SwiftData

@MainActor
@Observable
class AICoachViewModel {
    private let summaryRepository: SummaryRepositoryProtocol
    private let userRepository: UserRepositoryProtocol

    var isFixingMacros = false
    var isFixingHydration = false
    var macroAdvice: MacroFixAdviceDTO? = nil
    var hydrationAdvice: HydrationAdviceDTO? = nil

    var isAnalyzing = false
    var hasAnalyzedToday = false
    var verdictTitle: String = "AI Daily Review"
    var verdictMessage: String = "Tap the button below to analyze your calories, macros, and get a personalized summary for today."
    var verdictMood: String = "neutral"

    var fridgeInput: String = ""
    var isGeneratingRecipe = false
    var generatedRecipe: AIRecipeDTO? = nil
    var errorMessage: String? = nil

    init(summaryRepository: SummaryRepositoryProtocol, userRepository: UserRepositoryProtocol) {
        self.summaryRepository = summaryRepository
        self.userRepository = userRepository
    }

    func runDailyAnalysis(currentSummary: DailySummary, currentUser: User) {
        let cals = currentSummary.totalCalories
        let goal = currentUser.dailyCaloriesGoal
        let protein = currentSummary.totalProtein
        let targetP = currentUser.targetProtein

        HapticManager.shared.impact(style: .medium)
        errorMessage = nil
        isAnalyzing = true

        Task {
            if let verdict = await AINutritionService.shared.generateDailyVerdict(consumed: cals, goal: goal, protein: protein, targetProtein: targetP) {
                withAnimation(.spring()) {
                    self.verdictTitle = verdict.title
                    self.verdictMessage = verdict.message
                    self.verdictMood = verdict.mood
                    self.hasAnalyzedToday = true
                    self.isAnalyzing = false
                    HapticManager.shared.impact(style: .heavy)
                }
            } else {
                withAnimation(.spring()) {
                    self.isAnalyzing = false
                    self.errorMessage = String(localized: "Couldn't analyze your day right now. Please check your connection and try again.")
                    HapticManager.shared.notification(type: .error)
                }
            }
        }
    }

    func generateSmartRecipe(currentSummary: DailySummary, currentUser: User) {
        let missingCals = max(0, currentUser.dailyCaloriesGoal - currentSummary.totalCalories)
        let missingProtein = max(0, Int(currentUser.targetProtein - currentSummary.totalProtein))

        HapticManager.shared.impact(style: .medium)
        errorMessage = nil
        withAnimation { isGeneratingRecipe = true }

        Task {
            if let recipe = await AINutritionService.shared.generateFridgeRecipe(ingredients: fridgeInput, missingCalories: missingCals, missingProtein: missingProtein) {
                withAnimation(.spring()) {
                    self.generatedRecipe = recipe
                    self.fridgeInput = ""
                    self.isGeneratingRecipe = false
                    HapticManager.shared.impact(style: .heavy)
                }
            } else {
                self.isGeneratingRecipe = false
                self.errorMessage = String(localized: "Couldn't generate a recipe right now. Please try again.")
                HapticManager.shared.notification(type: .error)
            }
        }
    }

    func analyzeMacros(currentSummary: DailySummary, currentUser: User) {
        HapticManager.shared.impact(style: .medium)
        errorMessage = nil
        isFixingMacros = true

        let missingCals = currentUser.dailyCaloriesGoal - currentSummary.totalCalories
        let missingP = Int(currentUser.targetProtein - currentSummary.totalProtein)
        let missingF = Int(currentUser.targetFats - currentSummary.totalFats)
        let missingC = Int(currentUser.targetCarbs - currentSummary.totalCarbs)

        Task {
            if let advice = await AINutritionService.shared.getMacroFixAdvice(missingCals: missingCals, missingProtein: missingP, missingFats: missingF, missingCarbs: missingC) {
                self.macroAdvice = advice
                self.isFixingMacros = false
                HapticManager.shared.impact(style: .heavy)
            } else {
                self.isFixingMacros = false
                self.errorMessage = String(localized: "Couldn't fetch macro advice right now. Please try again.")
                HapticManager.shared.notification(type: .error)
            }
        }
    }

    func analyzeHydration(currentSummary: DailySummary) {
        HapticManager.shared.impact(style: .medium)
        errorMessage = nil
        isFixingHydration = true
        let drank = currentSummary.totalHydrationLiters

        Task {
            if let advice = await AINutritionService.shared.getHydrationAdvice(drankLiters: drank, goalLiters: 2.5) {
                self.isFixingHydration = false
                self.hydrationAdvice = advice
                HapticManager.shared.impact(style: .heavy)
            } else {
                self.isFixingHydration = false
                self.errorMessage = String(localized: "Couldn't fetch hydration advice right now. Please try again.")
                HapticManager.shared.notification(type: .error)
            }
        }
    }
}
