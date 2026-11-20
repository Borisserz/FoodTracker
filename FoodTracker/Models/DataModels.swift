import SwiftUI
import SwiftData
import Observation

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
        let rawBMR: Double
        if gender == "Female" {
            rawBMR = (10 * weight) + (6.25 * height) - (Double(age) * 5) - 161
        } else {
            rawBMR = (10 * weight) + (6.25 * height) - (Double(age) * 5) + 5
        }
        let bmr = max(800.0, rawBMR)
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

    /// Deduplicates `User` singletons created across devices via CloudKit, keeping the customized profile over default `"Alex"`.
    static func deduplicatedPrimary(in context: ModelContext) -> User? {
        let descriptor = FetchDescriptor<User>()
        guard let users = try? context.fetch(descriptor), !users.isEmpty else { return nil }
        guard users.count > 1 else { return users.first }

        let keeper = users.max { lhs, rhs in
            scoreProfile(lhs) < scoreProfile(rhs)
        } ?? users[0]

        for user in users where user !== keeper {
            context.delete(user)
        }
        return keeper
    }

    private static func scoreProfile(_ user: User) -> Int {
        var score = 0
        if user.name != "Alex" && !user.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { score += 4 }
        if user.dailyCaloriesGoal != 2000 { score += 2 }
        if user.totalXP > 0 || user.streakDays > 0 { score += 3 }
        if user.targetWeight != nil { score += 1 }
        return score
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
            let rawProtein = max(0, weight * 2.1)
            let fats = (targetCalories * 0.25) / 9.0
            let minCarbGrams = min(100.0, max(0.0, (targetCalories * 0.25) / 4.0))
            let maxProteinGrams = max(0.0, (targetCalories - (fats * 9.0) - (minCarbGrams * 4.0)) / 4.0)
            let protein = min(rawProtein, maxProteinGrams)
            let carbs = max(minCarbGrams, (targetCalories - (protein * 4.0) - (fats * 9.0)) / 4.0)
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
    var healthKitSampleID: String? = nil
    var parentDailySummary: DailySummary?

    init(date: Date = Date(), name: String, icon: String, colorHex: String, caloriesPerGlass: Int, volumeMl: Double = 250.0, healthKitSampleID: String? = nil) {
        self.date = date
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.caloriesPerGlass = caloriesPerGlass
        self.volumeMl = volumeMl
        self.healthKitSampleID = healthKitSampleID
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
    var fiber: Double = 0.0
    var sugar: Double = 0.0

    var omega3: Double = 0.0
    var calcium: Double = 0.0
    var potassium: Double = 0.0
    var magnesium: Double = 0.0
    var iron: Double = 0.0
    var vitaminC: Double = 0.0
    var vitaminD: Double = 0.0
    var healthKitSampleID: String? = nil
    var parentMeal: Meal?
    var parentRecipe: CustomRecipe?

    var netCarbs: Double {
        max(0.0, carbs - fiber)
    }

    init(name: String, weight: Double, calories: Int, protein: Double, fats: Double, carbs: Double,
         fiber: Double = 0, sugar: Double = 0,
         omega3: Double = 0, calcium: Double = 0, potassium: Double = 0,
         magnesium: Double = 0, iron: Double = 0, vitaminC: Double = 0, vitaminD: Double = 0) {

        self.id = UUID()

        self.name = name; self.weight = weight; self.calories = calories
        self.protein = protein; self.fats = fats; self.carbs = carbs
        self.fiber = fiber; self.sugar = sugar
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
    var totalFiber: Double { (foodItems ?? []).reduce(0) { $0 + $1.fiber } }
    var totalSugar: Double { (foodItems ?? []).reduce(0) { $0 + $1.sugar } }
    var totalNetCarbs: Double { (foodItems ?? []).reduce(0) { $0 + $1.netCarbs } }

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
    var totalPureWaterLiters: Double { (beverages ?? []).filter { $0.name == "Water" }.reduce(0) { $0 + $1.volumeMl } / 1000.0 }
    var totalProtein: Double { (meals ?? []).reduce(0) { $0 + $1.totalProtein } }
    var totalFats: Double { (meals ?? []).reduce(0) { $0 + $1.totalFats } }
    var totalCarbs: Double { (meals ?? []).reduce(0) { $0 + $1.totalCarbs } }
    var totalFiber: Double { (meals ?? []).reduce(0) { $0 + $1.totalFiber } }
    var totalSugar: Double { (meals ?? []).reduce(0) { $0 + $1.totalSugar } }
    var totalNetCarbs: Double { (meals ?? []).reduce(0) { $0 + $1.totalNetCarbs } }

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

    struct DeletedFoodHealthSample: Equatable {
        let sampleID: String?
        let calories: Int
    }

    @MainActor
    @discardableResult
    func removeFoodItem(_ food: FoodItem, from meal: Meal, in context: ModelContext) -> DeletedFoodHealthSample? {
        guard let index = meal.foodItems?.firstIndex(where: { $0.id == food.id }) else {
            return nil
        }
        let info = DeletedFoodHealthSample(sampleID: food.healthKitSampleID, calories: food.calories)
        meal.foodItems?.remove(at: index)
        context.delete(food)
        if (meal.foodItems ?? []).isEmpty {
            meals?.removeAll { $0.id == meal.id }
            context.delete(meal)
        }
        return info
    }

    @MainActor
    @discardableResult
    func removeActivity(_ activity: ActivityLog, in context: ModelContext) -> Int? {
        guard let index = activities?.firstIndex(where: { $0.persistentModelID == activity.persistentModelID }) else {
            return nil
        }
        let calories = max(0, activity.calories)
        activities?.remove(at: index)
        context.delete(activity)
        workoutCalories = max(0, workoutCalories - calories)
        activeCaloriesBurned = max(0, activeCaloriesBurned - calories)
        return calories
    }

    static func duplicateFoodItem(_ item: FoodItem) -> FoodItem {
        FoodItem(
            name: item.name,
            weight: item.weight,
            calories: item.calories,
            protein: item.protein,
            fats: item.fats,
            carbs: item.carbs,
            fiber: item.fiber,
            sugar: item.sugar,
            omega3: item.omega3,
            calcium: item.calcium,
            potassium: item.potassium,
            magnesium: item.magnesium,
            iron: item.iron,
            vitaminC: item.vitaminC,
            vitaminD: item.vitaminD
        )
    }

    @MainActor
    @discardableResult
    static func copyMeal(
        _ sourceMeal: Meal,
        toDate targetDate: Date,
        targetSlot: String? = nil,
        in context: ModelContext
    ) -> Int {
        let items = sourceMeal.foodItems ?? []
        guard !items.isEmpty else { return 0 }

        let slot = canonicalMealSlot(targetSlot ?? sourceMeal.title)
        let targetSummary = DailySummary.fetchOrCreate(for: targetDate, in: context)
        let timestamp = Calendar.current.isDateInToday(targetDate)
            ? Date()
            : Calendar.current.startOfDay(for: targetDate)

        var duplicated: [FoodItem] = []
        for item in items {
            let copy = duplicateFoodItem(item)
            context.insert(copy)
            duplicated.append(copy)
        }

        if let existingMeal = (targetSummary.meals ?? []).first(where: { canonicalMealSlot($0.title) == slot }) {
            existingMeal.addFoodItems(duplicated)
            existingMeal.date = timestamp
        } else {
            let newMeal = Meal(title: slot, date: timestamp, foodItems: duplicated)
            context.insert(newMeal)
            targetSummary.addMeal(newMeal)
        }
        return duplicated.count
    }

    @MainActor
    @discardableResult
    static func copyDay(
        from sourceSummary: DailySummary,
        toDate targetDate: Date,
        in context: ModelContext
    ) -> Int {
        var totalCopied = 0
        for meal in sourceSummary.meals ?? [] {
            totalCopied += copyMeal(meal, toDate: targetDate, targetSlot: meal.title, in: context)
        }
        return totalCopied
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
    struct NutritionTotals: Equatable {
        let calories: Int
        let protein: Double
        let fats: Double
        let carbs: Double
    }

    var perServingNutrition: NutritionTotals {
        let items = foodItems ?? []
        let divisor = max(Double(self.servings), 1.0)
        return NutritionTotals(
            calories: max(0, Int((Double(totalCalories) / divisor).rounded())),
            protein: items.reduce(0) { $0 + $1.protein } / divisor,
            fats: items.reduce(0) { $0 + $1.fats } / divisor,
            carbs: items.reduce(0) { $0 + $1.carbs } / divisor
        )
    }

    func toFoodItem(servingsCount: Int = 1) -> FoodItem {
        let items = foodItems ?? []
        let totalWeight = items.reduce(0) { $0 + $1.weight }
        let totalProtein = items.reduce(0) { $0 + $1.protein }
        let totalFats = items.reduce(0) { $0 + $1.fats }
        let totalCarbs = items.reduce(0) { $0 + $1.carbs }
        let totalFiber = items.reduce(0) { $0 + $1.fiber }
        let totalSugar = items.reduce(0) { $0 + $1.sugar }
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
            fiber: totalFiber * portionFactor,
            sugar: totalSugar * portionFactor,
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

    @MainActor
    @discardableResult
    static func insertDeduplicated(
        items: [(name: String, amount: String)],
        recipeTitle: String? = nil,
        in context: ModelContext
    ) -> Int {
        let existingItems = (try? context.fetch(FetchDescriptor<ShoppingItem>())) ?? []
        var seenKeys = Set(
            existingItems.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        var insertedCount = 0
        for entry in items {
            let trimmedName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }
            let key = trimmedName.lowercased()
            guard seenKeys.insert(key).inserted else { continue }
            let item = ShoppingItem(
                name: trimmedName,
                amount: entry.amount.trimmingCharacters(in: .whitespacesAndNewlines),
                addedFromRecipe: recipeTitle
            )
            context.insert(item)
            insertedCount += 1
        }
        return insertedCount
    }
}

@Model final class WeightLog {
    var id: UUID = UUID()
    var date: Date = Date()
    var weight: Double = 0.0
    var healthKitSampleID: String? = nil

    init(id: UUID = UUID(), date: Date = Date(), weight: Double = 0.0, healthKitSampleID: String? = nil) {
        self.id = id
        self.date = date
        self.weight = weight
        self.healthKitSampleID = healthKitSampleID
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

enum WidgetStorageActions {
    @MainActor
    static func addWaterGlass(volumeMl: Double = 250.0, in context: ModelContext, for date: Date = Date()) throws {
        guard volumeMl > 0 else { return }
        let summary = DailySummary.fetchOrCreate(for: date, in: context)
        let newBeverage = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: volumeMl)
        context.insert(newBeverage)
        summary.addBeverage(newBeverage)
        try context.save()
    }

    @MainActor
    static func addWaterGlassAndRecordPendingDelta(
        volumeMl: Double = 250.0,
        in context: ModelContext,
        for date: Date = Date(),
        sharedDefaults: UserDefaults? = nil,
        appGroupDefaults: UserDefaults? = nil
    ) throws {
        let summary = DailySummary.fetchOrCreate(for: date, in: context)
        _ = WorkoutSyncManager.shared.reconcileWater(
            for: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: appGroupDefaults,
            localDefaults: appGroupDefaults
        )
        try addWaterGlass(volumeMl: volumeMl, in: context, for: date)
        if volumeMl > 0 {
            WorkoutSyncManager.shared.syncWaterFromWidget(
                totalLiters: summary.totalPureWaterLiters,
                addedMl: volumeMl,
                for: date,
                sharedDefaults: sharedDefaults,
                appGroupDefaults: appGroupDefaults,
                localDefaults: appGroupDefaults
            )
        }
    }

    @MainActor
    static func toggleShoppingItem(idString: String, in context: ModelContext) throws {
        guard let uuid = UUID(uuidString: idString) else { return }
        let descriptor = FetchDescriptor<ShoppingItem>(
            predicate: #Predicate<ShoppingItem> { $0.id == uuid }
        )
        if let item = try context.fetch(descriptor).first {
            item.isChecked.toggle()
            try context.save()
        }
    }
}
