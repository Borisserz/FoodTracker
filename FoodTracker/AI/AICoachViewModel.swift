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
                    if cals > goal { self.verdictMood = "danger" } else if cals < goal / 2 { self.verdictMood = "warning" } else { self.verdictMood = "perfect" }
                    self.verdictTitle = "Data Collected"
                    self.verdictMessage = "You've eaten \(cals) kcal out of \(goal)."
                    self.hasAnalyzedToday = true
                    self.isAnalyzing = false
                }
            }
        }
    }

    func generateSmartRecipe(currentSummary: DailySummary, currentUser: User) {
        let missingCals = max(0, currentUser.dailyCaloriesGoal - currentSummary.totalCalories)
        let missingProtein = max(0, Int(currentUser.targetProtein - currentSummary.totalProtein))

        HapticManager.shared.impact(style: .medium)
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
            }
        }
    }

    func analyzeMacros(currentSummary: DailySummary, currentUser: User) {
        HapticManager.shared.impact(style: .medium)
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
                print("❌ Не удалось получить совет по макросам от ИИ")
                self.isFixingMacros = false
            }
        }
    }

    func analyzeHydration(currentSummary: DailySummary) {
        HapticManager.shared.impact(style: .medium)
        isFixingHydration = true
        let drank = currentSummary.totalHydrationLiters

        Task {
            if let advice = await AINutritionService.shared.getHydrationAdvice(drankLiters: drank, goalLiters: 2.5) {
                self.isFixingHydration = false
                self.hydrationAdvice = advice
                HapticManager.shared.impact(style: .heavy)
            } else {
                self.isFixingHydration = false
            }
        }
    }
}
