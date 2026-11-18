import SwiftUI
import SwiftData
import Observation
enum MacroType: String, Identifiable {
    case protein = "Protein"
    case fat = "Fat"
    case carbs = "Carbs"

    var id: String { self.rawValue }

    var localizedName: String {
        switch self {
        case .protein: return String(localized: "Protein")
        case .fat: return String(localized: "Fat")
        case .carbs: return String(localized: "Carbs")
        }
    }

    var color: Color {
        switch self {
        case .protein: return Color(red: 1.0, green: 0.22, blue: 0.52)
        case .fat: return .orange
        case .carbs: return .blue
        }
    }
}

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color

    static let all: [Achievement] = [
        Achievement(id: "first_log", title: String(localized: "First Step"), description: String(localized: "Log your first meal"), icon: "flag.fill", color: Color(red: 1.0, green: 0.22, blue: 0.52)),
        Achievement(id: "streak_3", title: String(localized: "On Fire"), description: String(localized: "Reach a 3-day streak"), icon: "flame.fill", color: Color(red: 1.0, green: 0.58, blue: 0.0)),
        Achievement(id: "streak_7", title: String(localized: "Unstoppable"), description: String(localized: "Reach a 7-day streak"), icon: "bolt.fill", color: Color(red: 1.0, green: 0.84, blue: 0.04)),
        Achievement(id: "water_pro", title: String(localized: "Hydro Homie"), description: String(localized: "Drink 2.5L in a day"), icon: "drop.fill", color: .blue)
    ]
}

@Model final class User {
    var name: String = ""
    var weight: Double = 0.0
    var height: Double = 0.0
    var age: Int = 0
    var gender: String = "Male"
    var dailyCaloriesGoal: Int = 0
    var createdDate: Date = Date()
    var isHealthKitEnabled: Bool = false

    var activeDietKey: String = "balanced"
    var targetProtein: Double = 150.0
    var targetFats: Double = 70.0
    var targetCarbs: Double = 250.0

    var unlockedAchievements: [String] = []
    
    var totalXP: Int = 0
    var level: Int = 1
    var streakDays: Int = 0
    
    // Goals
    var targetWeight: Double?
    var weightGoalType: String? // "lose", "gain", "maintain"
    var activityMultiplier: Double = 1.3

    init(name: String, weight: Double, height: Double, age: Int, gender: String = "Male") {
        self.name = name
        self.weight = weight
        self.height = height
        self.age = age
        self.gender = gender
        self.createdDate = Date()

        self.dailyCaloriesGoal = 0
        self.isHealthKitEnabled = false
        self.activeDietKey = "balanced"
        self.targetProtein = 150.0
        self.targetFats = 70.0
        self.targetCarbs = 250.0

        self.unlockedAchievements = []

        self.calculateGoals()

        self.applyDietBreakdown(fatPercent: 30, proteinPercent: 30, carbsPercent: 40, dietKey: "balanced")
    }

    func calculateGoals() {
        let bmr: Double
        if gender == "Female" {
            bmr = (10 * weight) + (6.25 * height) - (Double(age) * 5) - 161
        } else {
            bmr = (10 * weight) + (6.25 * height) - (Double(age) * 5) + 5
        }
        let multiplier = activityMultiplier > 0 ? activityMultiplier : 1.3
        let tdee = bmr * multiplier

        switch weightGoalType {
        case "lose":
            self.dailyCaloriesGoal = max(1200, Int(tdee - 450))
        case "gain":
            self.dailyCaloriesGoal = Int(tdee + 350)
        default:
            self.dailyCaloriesGoal = max(1200, Int(tdee))
        }
    }

    /// Recomputes macro targets (g) for the current `dailyCaloriesGoal`, preserving existing macro ratios when valid.
    func recalculateMacrosPreservingRatios(fromPreviousCalories previousCalories: Int? = nil) {
        let targetCalories = Double(max(dailyCaloriesGoal, 0))
        guard targetCalories > 0 else { return }

        let currentMacroCalories = (targetProtein * 4.0) + (targetFats * 9.0) + (targetCarbs * 4.0)
        let baseline = currentMacroCalories > 0 ? currentMacroCalories : Double(previousCalories ?? 0)

        if baseline > 0, currentMacroCalories > 0 {
            let pRatio = (targetProtein * 4.0) / currentMacroCalories
            let fRatio = (targetFats * 9.0) / currentMacroCalories
            let cRatio = max(0, 1.0 - pRatio - fRatio)

            self.targetProtein = (targetCalories * pRatio) / 4.0
            self.targetFats = (targetCalories * fRatio) / 9.0
            self.targetCarbs = (targetCalories * cRatio) / 4.0
        } else {
            let protein = max(0, weight * 2.1)
            let fats = (targetCalories * 0.25) / 9.0
            let carbs = max(100.0, (targetCalories - (protein * 4.0) - (fats * 9.0)) / 4.0)
            self.targetProtein = protein
            self.targetFats = fats
            self.targetCarbs = carbs
        }
    }

    func applyDietBreakdown(fatPercent: Int, proteinPercent: Int, carbsPercent: Int, dietKey: String) {
        self.activeDietKey = dietKey
        let targetCalories = Double(dailyCaloriesGoal)

        self.targetProtein = (targetCalories * Double(proteinPercent) / 100.0) / 4.0
        self.targetCarbs   = (targetCalories * Double(carbsPercent) / 100.0) / 4.0
        self.targetFats    = (targetCalories * Double(fatPercent) / 100.0) / 9.0
    }
}

@Model final class Beverage {
    var date: Date = Date()
    var name: String = ""
    var icon: String = ""
    var colorHex: String = ""
    var caloriesPerGlass: Int = 0
    var volumeMl: Double = 0.0
    var parentDailySummary: DailySummary?

    init(date: Date = Date(), name: String, icon: String, colorHex: String, caloriesPerGlass: Int, volumeMl: Double = 250.0) {
        self.date = date
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.caloriesPerGlass = caloriesPerGlass
        self.volumeMl = volumeMl
    }
}

@Model final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""
    var weight: Double = 0.0
    var calories: Int = 0
    var protein: Double = 0.0
    var fats: Double = 0.0
    var carbs: Double = 0.0

    var omega3: Double = 0.0
    var calcium: Double = 0.0
    var potassium: Double = 0.0
    var magnesium: Double = 0.0
    var iron: Double = 0.0
    var vitaminC: Double = 0.0
    var vitaminD: Double = 0.0
    var parentMeal: Meal?
    var parentRecipe: CustomRecipe?

    init(name: String, weight: Double, calories: Int, protein: Double, fats: Double, carbs: Double,
         omega3: Double = 0, calcium: Double = 0, potassium: Double = 0,
         magnesium: Double = 0, iron: Double = 0, vitaminC: Double = 0, vitaminD: Double = 0) {

        self.id = UUID()

        self.name = name; self.weight = weight; self.calories = calories
        self.protein = protein; self.fats = fats; self.carbs = carbs
        self.omega3 = omega3; self.calcium = calcium; self.potassium = potassium
        self.magnesium = magnesium; self.iron = iron; self.vitaminC = vitaminC; self.vitaminD = vitaminD
    }
}

@Model final class Meal {
    var title: String = ""
    var date: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \FoodItem.parentMeal) var foodItems: [FoodItem]? = []
    var parentDailySummary: DailySummary?

    var totalCalories: Int { (foodItems ?? []).reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { (foodItems ?? []).reduce(0) { $0 + $1.protein } }
    var totalFats: Double { (foodItems ?? []).reduce(0) { $0 + $1.fats } }
    var totalCarbs: Double { (foodItems ?? []).reduce(0) { $0 + $1.carbs } }

    var totalOmega3: Double { (foodItems ?? []).reduce(0) { $0 + $1.omega3 } }
    var totalPotassium: Double { (foodItems ?? []).reduce(0) { $0 + $1.potassium } }
    var totalMagnesium: Double { (foodItems ?? []).reduce(0) { $0 + $1.magnesium } }
    var totalCalcium: Double { (foodItems ?? []).reduce(0) { $0 + $1.calcium } }
    var totalIron: Double { (foodItems ?? []).reduce(0) { $0 + $1.iron } }
    var totalVitaminC: Double { (foodItems ?? []).reduce(0) { $0 + $1.vitaminC } }
    var totalVitaminD: Double { (foodItems ?? []).reduce(0) { $0 + $1.vitaminD } }

    init(title: String, date: Date, foodItems: [FoodItem] = []) {
        self.title = title
        self.date = date
        self.foodItems = foodItems
    }

    func addFoodItem(_ item: FoodItem) {
        if foodItems == nil { foodItems = [] }
        foodItems?.append(item)
    }

    func addFoodItems(_ items: [FoodItem]) {
        if foodItems == nil { foodItems = [] }
        foodItems?.append(contentsOf: items)
    }
}

@Model final class CustomRecipe {
    var name: String = ""
    var info: String = ""
    @Relationship(deleteRule: .cascade, inverse: \FoodItem.parentRecipe) var foodItems: [FoodItem]? = []
    var cookingTime: Int = 0
    var difficulty: String = ""

    var servings: Int = 1
    var directions: [String] = []

    var totalCalories: Int { (foodItems ?? []).reduce(0) { $0 + $1.calories } }

    init(name: String, info: String, foodItems: [FoodItem] = [], cookingTime: Int, difficulty: String, servings: Int = 1, directions: [String] = []) {
        self.name = name; self.info = info; self.foodItems = foodItems
        self.cookingTime = cookingTime; self.difficulty = difficulty
        self.servings = servings
        self.directions = directions
    }
}

@Model final class ActivityLog {
    var title: String = ""
    var icon: String = ""
    var durationMinutes: Int = 0
    var calories: Int = 0
    var date: Date = Date()
    var parentDailySummary: DailySummary?

    init(title: String, icon: String, durationMinutes: Int, calories: Int, date: Date = Date()) {
        self.title = title
        self.icon = icon
        self.durationMinutes = durationMinutes
        self.calories = calories
        self.date = date
    }
}

@Model final class DailySummary {
    var date: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \Meal.parentDailySummary) var meals: [Meal]? = []
    @Relationship(deleteRule: .cascade, inverse: \Beverage.parentDailySummary) var beverages: [Beverage]? = []
    @Relationship(deleteRule: .cascade, inverse: \ActivityLog.parentDailySummary) var activities: [ActivityLog]? = []
    var weight: Double?
    var activeCaloriesBurned: Int = 0
    var dayNote: String = ""
    var dayMoodEmoji: String = ""
    var stepsCount: Int = 0

    var workoutCalories: Int = 0

    var totalFoodCalories: Int { (meals ?? []).reduce(0) { $0 + $1.totalCalories } }
    var totalDrinkCalories: Int { (beverages ?? []).reduce(0) { $0 + $1.caloriesPerGlass } }
    var totalCalories: Int { totalFoodCalories + totalDrinkCalories }

    var totalHydrationLiters: Double { (beverages ?? []).reduce(0) { $0 + $1.volumeMl } / 1000.0 }
    var totalProtein: Double { (meals ?? []).reduce(0) { $0 + $1.totalProtein } }
    var totalFats: Double { (meals ?? []).reduce(0) { $0 + $1.totalFats } }
    var totalCarbs: Double { (meals ?? []).reduce(0) { $0 + $1.totalCarbs } }

    var totalOmega3: Double { (meals ?? []).reduce(0) { $0 + $1.totalOmega3 } }
    var totalPotassium: Double { (meals ?? []).reduce(0) { $0 + $1.totalPotassium } }
    var totalMagnesium: Double { (meals ?? []).reduce(0) { $0 + $1.totalMagnesium } }
    var totalCalcium: Double { (meals ?? []).reduce(0) { $0 + $1.totalCalcium } }
    var totalIron: Double { (meals ?? []).reduce(0) { $0 + $1.totalIron } }
    var totalVitaminC: Double { (meals ?? []).reduce(0) { $0 + $1.totalVitaminC } }
    var totalVitaminD: Double { (meals ?? []).reduce(0) { $0 + $1.totalVitaminD } }

    var localActivityCalories: Int { (activities ?? []).reduce(0) { $0 + $1.calories } }

    var netCalories: Int {
        totalCalories - activeCaloriesBurned
    }

    func remainingCalories(userGoal: Int) -> Int {
        return (userGoal + activeCaloriesBurned) - totalCalories
    }

    init(date: Date, meals: [Meal] = [], beverages: [Beverage] = [], activities: [ActivityLog] = []) {
        self.date = Calendar.current.startOfDay(for: date)
        self.meals = meals; self.beverages = beverages; self.activities = activities
        self.activeCaloriesBurned = 0
        self.stepsCount = 0
        self.workoutCalories = 0
    }

    func addMeal(_ meal: Meal) {
        if meals == nil { meals = [] }
        meals?.append(meal)
    }

    func addBeverage(_ beverage: Beverage) {
        if beverages == nil { beverages = [] }
        beverages?.append(beverage)
    }

    func addActivity(_ activity: ActivityLog) {
        if activities == nil { activities = [] }
        activities?.append(activity)
    }

    /// Fetches the canonical DailySummary for `date`'s calendar day, merging any CloudKit-synced duplicates safely.
    static func fetchExisting(for date: Date, in context: ModelContext, didMerge: inout Bool) -> DailySummary? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        guard let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = #Predicate<DailySummary> { summary in
            summary.date >= startOfDay && summary.date < endOfDay
        }
        var descriptor = FetchDescriptor<DailySummary>(predicate: predicate)
        descriptor.sortBy = [SortDescriptor(\.date, order: .forward)]

        guard let matches = try? context.fetch(descriptor), !matches.isEmpty else {
            return nil
        }
        if matches.count > 1 { didMerge = true }
        return mergeDuplicates(matches, in: context)
    }

    static func fetchExisting(for date: Date, in context: ModelContext) -> DailySummary? {
        var ignored = false
        return fetchExisting(for: date, in: context, didMerge: &ignored)
    }

    /// Fetches or inserts the single canonical DailySummary for `date`'s calendar day.
    static func fetchOrCreate(for date: Date, in context: ModelContext) -> DailySummary {
        if let existing = fetchExisting(for: date, in: context) {
            return existing
        }
        let startOfDay = Calendar.current.startOfDay(for: date)
        let newSummary = DailySummary(date: startOfDay)
        context.insert(newSummary)
        return newSummary
    }

    static func canonicalMealSlot(_ raw: String) -> String {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["breakfast", "завтрак", "frühstück", "desayuno", "petit-déjeuner", "petit dejeuner", "colazione", "pequeno-almoço", "pequeno almoco"].contains(where: { lower.contains($0) }) {
            return "Breakfast"
        }
        if ["lunch", "обед", "mittagessen", "almuerzo", "comida", "déjeuner", "dejeuner", "pranzo", "almoço", "almoco"].contains(where: { lower.contains($0) }) {
            return "Lunch"
        }
        if ["dinner", "ужин", "abendessen", "cena", "dîner", "diner", "jantar"].contains(where: { lower.contains($0) }) {
            return "Dinner"
        }
        if ["snack", "перекус", "zwischenmahlzeit", "merienda", "collation", "spuntino", "lanche"].contains(where: { lower.contains($0) }) {
            return "Snack"
        }
        return "Snack"
    }

    private static func mergeDuplicates(_ matches: [DailySummary], in context: ModelContext) -> DailySummary? {
        guard let primary = matches.first else { return nil }
        guard matches.count > 1 else { return primary }

        for duplicate in matches.dropFirst() {
            let dupMeals = duplicate.meals ?? []
            duplicate.meals = []
            for meal in dupMeals {
                let targetSlot = canonicalMealSlot(meal.title)
                if let existingMeal = (primary.meals ?? []).first(where: {
                    canonicalMealSlot($0.title) == targetSlot
                }) {
                    let items = meal.foodItems ?? []
                    meal.foodItems = []
                    existingMeal.addFoodItems(items)
                    context.delete(meal)
                } else {
                    primary.addMeal(meal)
                }
            }

            let dupBeverages = duplicate.beverages ?? []
            duplicate.beverages = []
            for beverage in dupBeverages {
                primary.addBeverage(beverage)
            }

            let dupActivities = duplicate.activities ?? []
            duplicate.activities = []
            for activity in dupActivities {
                primary.addActivity(activity)
            }

            primary.stepsCount = max(primary.stepsCount, duplicate.stepsCount)
            primary.activeCaloriesBurned = max(primary.activeCaloriesBurned, duplicate.activeCaloriesBurned)
            primary.workoutCalories = max(primary.workoutCalories, duplicate.workoutCalories)
            if primary.weight == nil, let w = duplicate.weight { primary.weight = w }
            if primary.dayNote.isEmpty, !duplicate.dayNote.isEmpty { primary.dayNote = duplicate.dayNote }
            if primary.dayMoodEmoji.isEmpty, !duplicate.dayMoodEmoji.isEmpty { primary.dayMoodEmoji = duplicate.dayMoodEmoji }

            context.delete(duplicate)
        }
        return primary
    }
}

extension CustomRecipe {
    func toFoodItem(servingsCount: Int = 1) -> FoodItem {
        let items = foodItems ?? []
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let totalProtein = items.reduce(0) { $0 + $1.protein }
        let totalFats = items.reduce(0) { $0 + $1.fats }
        let totalCarbs = items.reduce(0) { $0 + $1.carbs }
        let totalOmega3 = items.reduce(0) { $0 + $1.omega3 }
        let totalCalcium = items.reduce(0) { $0 + $1.calcium }
        let totalPotassium = items.reduce(0) { $0 + $1.potassium }
        let totalMagnesium = items.reduce(0) { $0 + $1.magnesium }
        let totalIron = items.reduce(0) { $0 + $1.iron }
        let totalVitaminC = items.reduce(0) { $0 + $1.vitaminC }
        let totalVitaminD = items.reduce(0) { $0 + $1.vitaminD }

        let recipeServings = max(Double(self.servings), 1.0)
        let portionFactor = Double(max(servingsCount, 1)) / recipeServings

        return FoodItem(
            name: self.name,
            weight: totalWeight * portionFactor,
            calories: max(0, Int((Double(self.totalCalories) * portionFactor).rounded())),
            protein: totalProtein * portionFactor,
            fats: totalFats * portionFactor,
            carbs: totalCarbs * portionFactor,
            omega3: totalOmega3 * portionFactor,
            calcium: totalCalcium * portionFactor,
            potassium: totalPotassium * portionFactor,
            magnesium: totalMagnesium * portionFactor,
            iron: totalIron * portionFactor,
            vitaminC: totalVitaminC * portionFactor,
            vitaminD: totalVitaminD * portionFactor
        )
    }
}
enum HealthGrade {
    case clean, balanced, treat

    var color: Color {
        switch self {
        case .clean: return Color.green
        case .balanced: return Color(red: 1.0, green: 0.84, blue: 0.04)
        case .treat: return Color(red: 1.0, green: 0.22, blue: 0.52)
        }
    }

    var icon: String {
        switch self {
        case .clean: return "leaf.fill"
        case .balanced: return "scale.3d"
        case .treat: return "flame.fill"
        }
    }

    var title: String {
        switch self {
        case .clean: return String(localized: "Clean")
        case .balanced: return String(localized: "Balanced")
        case .treat: return String(localized: "Treat")
        }
    }
}

extension FoodItem {

    var healthGrade: HealthGrade {
        let proteinCals = protein * 4.0
        let proteinPercentage = calories > 0 ? (proteinCals / Double(calories)) : 0

        if proteinPercentage > 0.20 || (calories < 100 && carbs < 15) {
            return .clean
        }

        else if calories > 350 && proteinPercentage < 0.10 {
            return .treat
        }

        else {
            return .balanced
        }
    }
}
@Model final class ShoppingItem {
    var id: UUID = UUID()
    var name: String = ""
    var amount: String = ""
    var isChecked: Bool = false
    var addedFromRecipe: String?
    var dateAdded: Date = Date()

    init(name: String, amount: String = "", isChecked: Bool = false, addedFromRecipe: String? = nil) {
        self.name = name
        self.amount = amount
        self.isChecked = isChecked
        self.addedFromRecipe = addedFromRecipe
        self.dateAdded = Date()
    }
}

@Model final class WeightLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var weight: Double = 0.0

    init(id: UUID = UUID(), date: Date = Date(), weight: Double = 0.0) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}

@Model final class AIChatSession {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var messages: [AIChatMessage] = []

    init(title: String = "New Chat", date: Date = Date(), messages: [AIChatMessage] = []) {
        self.title = title
        self.date = date
        self.messages = messages
    }
}

struct AIChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    let isUser: Bool
    var text: String
    var isAnimating: Bool = false

    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

/// Shared today widget snapshot shared between app tests and WidgetExtension without duplicating formulas.
struct DailyWidgetSnapshot: Equatable {
    let hydrationLiters: Double
    let hydrationGoalLiters: Double
    let protein: Int
    let proteinGoal: Int
    let fat: Int
    let fatGoal: Int
    let carbs: Int
    let carbGoal: Int
    let totalCalories: Int
    let calorieGoal: Int
    let metabolicScore: Int

    static func compute(summary: DailySummary?, user: User?) -> DailyWidgetSnapshot {
        let calGoal = max(1, user?.dailyCaloriesGoal ?? 2000)
        let pGoal = max(1, Int((user?.targetProtein ?? 150).rounded()))
        let fGoal = max(1, Int((user?.targetFats ?? 70).rounded()))
        let cGoal = max(1, Int((user?.targetCarbs ?? 250).rounded()))
        let hydGoal = 2.5

        guard let summary else {
            return DailyWidgetSnapshot(
                hydrationLiters: 0,
                hydrationGoalLiters: hydGoal,
                protein: 0,
                proteinGoal: pGoal,
                fat: 0,
                fatGoal: fGoal,
                carbs: 0,
                carbGoal: cGoal,
                totalCalories: 0,
                calorieGoal: calGoal,
                metabolicScore: 0
            )
        }

        let cals = summary.totalCalories
        let hyd = summary.totalHydrationLiters
        let prot = Int(summary.totalProtein.rounded())
        let fat = Int(summary.totalFats.rounded())
        let carbs = Int(summary.totalCarbs.rounded())

        let calRatio = Double(cals) / Double(calGoal)
        let calScore = calRatio <= 1.0 ? (calRatio * 50.0) : max(0.0, 50.0 - ((calRatio - 1.0) * 100.0))
        let hydScore = min(hyd / hydGoal, 1.0) * 30.0
        let avgMacroRatio = (
            min(Double(prot) / Double(pGoal), 1.0) +
            min(Double(fat) / Double(fGoal), 1.0) +
            min(Double(carbs) / Double(cGoal), 1.0)
        ) / 3.0
        let macroScore = avgMacroRatio * 20.0
        let finalScore = min(100, max(0, Int((calScore + hydScore + macroScore).rounded())))

        return DailyWidgetSnapshot(
            hydrationLiters: hyd,
            hydrationGoalLiters: hydGoal,
            protein: prot,
            proteinGoal: pGoal,
            fat: fat,
            fatGoal: fGoal,
            carbs: carbs,
            carbGoal: cGoal,
            totalCalories: cals,
            calorieGoal: calGoal,
            metabolicScore: finalScore
        )
    }

    /// Returns a midnight-reset snapshot retaining user goals with all daily intake counters zeroed.
    func zeroedForNewDay() -> DailyWidgetSnapshot {
        DailyWidgetSnapshot(
            hydrationLiters: 0,
            hydrationGoalLiters: hydrationGoalLiters,
            protein: 0,
            proteinGoal: proteinGoal,
            fat: 0,
            fatGoal: fatGoal,
            carbs: 0,
            carbGoal: carbGoal,
            totalCalories: 0,
            calorieGoal: calorieGoal,
            metabolicScore: 0
        )
    }

    /// Builds a WidgetKit timeline containing the current entry and a midnight rollover entry so widgets reset at 00:00.
    static func timelineSchedule(
        for snapshot: DailyWidgetSnapshot,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (entries: [(date: Date, snapshot: DailyWidgetSnapshot)], reloadAt: Date) {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now.addingTimeInterval(86400)
        let nextHour = calendar.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        let entries: [(date: Date, snapshot: DailyWidgetSnapshot)] = [
            (now, snapshot),
            (startOfTomorrow, snapshot.zeroedForNewDay())
        ]
        return (entries: entries, reloadAt: min(nextHour, startOfTomorrow))
    }
}
