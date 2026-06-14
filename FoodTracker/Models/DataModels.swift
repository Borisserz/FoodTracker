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
        case .protein: return .themePink
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
        Achievement(id: "first_log", title: String(localized: "First Step"), description: String(localized: "Log your first meal"), icon: "flag.fill", color: .themePink),
        Achievement(id: "streak_3", title: String(localized: "On Fire"), description: String(localized: "Reach a 3-day streak"), icon: "flame.fill", color: .themeOrange),
        Achievement(id: "streak_7", title: String(localized: "Unstoppable"), description: String(localized: "Reach a 7-day streak"), icon: "bolt.fill", color: .themeYellow),
        Achievement(id: "water_pro", title: String(localized: "Hydro Homie"), description: String(localized: "Drink 2.5L in a day"), icon: "drop.fill", color: .blue)
    ]
}

@Model final class User: @unchecked Sendable {
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
    
    // Goals
    var targetWeight: Double?
    var weightGoalType: String? // "lose", "gain", "maintain"

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
        if gender == "Male" {
            bmr = (10 * weight) + (6.25 * height) - (Double(age) * 5) + 5
        } else {
            bmr = (10 * weight) + (6.25 * height) - (Double(age) * 5) - 161
        }
        self.dailyCaloriesGoal = Int(bmr * 1.3)
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
    @Relationship(deleteRule: .cascade) var foodItems: [FoodItem] = []

    var totalCalories: Int { foodItems.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { foodItems.reduce(0) { $0 + $1.protein } }
    var totalFats: Double { foodItems.reduce(0) { $0 + $1.fats } }
    var totalCarbs: Double { foodItems.reduce(0) { $0 + $1.carbs } }

    var totalOmega3: Double { foodItems.reduce(0) { $0 + $1.omega3 } }
    var totalPotassium: Double { foodItems.reduce(0) { $0 + $1.potassium } }
    var totalMagnesium: Double { foodItems.reduce(0) { $0 + $1.magnesium } }
    var totalCalcium: Double { foodItems.reduce(0) { $0 + $1.calcium } }
    var totalIron: Double { foodItems.reduce(0) { $0 + $1.iron } }
    var totalVitaminC: Double { foodItems.reduce(0) { $0 + $1.vitaminC } }
    var totalVitaminD: Double { foodItems.reduce(0) { $0 + $1.vitaminD } }

    init(title: String, date: Date, foodItems: [FoodItem] = []) {
        self.title = title
        self.date = date
        self.foodItems = foodItems
    }
}

@Model final class CustomRecipe {
    var name: String = ""
    var info: String = ""
    @Relationship(deleteRule: .cascade) var foodItems: [FoodItem] = []
    var cookingTime: Int = 0
    var difficulty: String = ""

    var servings: Int = 1
    var directions: [String] = []

    var totalCalories: Int { foodItems.reduce(0) { $0 + $1.calories } }

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

    init(title: String, icon: String, durationMinutes: Int, calories: Int, date: Date = Date()) {
        self.title = title
        self.icon = icon
        self.durationMinutes = durationMinutes
        self.calories = calories
        self.date = date
    }
}

@Model final class DailySummary: @unchecked Sendable {
    @Attribute(.unique) var date: Date = Date()
    @Relationship(deleteRule: .cascade) var meals: [Meal] = []
    @Relationship(deleteRule: .cascade) var beverages: [Beverage] = []
    @Relationship(deleteRule: .cascade) var activities: [ActivityLog] = []
    var weight: Double?
    var activeCaloriesBurned: Int = 0
    var dayNote: String = ""
    var dayMoodEmoji: String = ""
    var stepsCount: Int = 0

    var workoutCalories: Int = 0

    var totalFoodCalories: Int { meals.reduce(0) { $0 + $1.totalCalories } }
    var totalDrinkCalories: Int { beverages.reduce(0) { $0 + $1.caloriesPerGlass } }
    var totalCalories: Int { totalFoodCalories + totalDrinkCalories }

    var totalHydrationLiters: Double { beverages.reduce(0) { $0 + $1.volumeMl } / 1000.0 }
    var totalProtein: Double { meals.reduce(0) { $0 + $1.totalProtein } }
    var totalFats: Double { meals.reduce(0) { $0 + $1.totalFats } }
    var totalCarbs: Double { meals.reduce(0) { $0 + $1.totalCarbs } }

    var totalOmega3: Double { meals.reduce(0) { $0 + $1.totalOmega3 } }
    var totalPotassium: Double { meals.reduce(0) { $0 + $1.totalPotassium } }
    var totalMagnesium: Double { meals.reduce(0) { $0 + $1.totalMagnesium } }
    var totalCalcium: Double { meals.reduce(0) { $0 + $1.totalCalcium } }
    var totalIron: Double { meals.reduce(0) { $0 + $1.totalIron } }
    var totalVitaminC: Double { meals.reduce(0) { $0 + $1.totalVitaminC } }
    var totalVitaminD: Double { meals.reduce(0) { $0 + $1.totalVitaminD } }

    var localActivityCalories: Int { activities.reduce(0) { $0 + $1.calories } }

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
}

extension CustomRecipe {
    func toFoodItem() -> FoodItem {
        let totalWeight = foodItems.reduce(0) { $0 + $1.weight }
        let totalProtein = foodItems.reduce(0) { $0 + $1.protein }
        let totalFats = foodItems.reduce(0) { $0 + $1.fats }
        let totalCarbs = foodItems.reduce(0) { $0 + $1.carbs }

        return FoodItem(
            name: self.name,
            weight: totalWeight,
            calories: self.totalCalories,
            protein: totalProtein,
            fats: totalFats,
            carbs: totalCarbs
        )
    }
}
enum HealthGrade {
    case clean, balanced, treat

    var color: Color {
        switch self {
        case .clean: return Color.green
        case .balanced: return Color.themeYellow
        case .treat: return Color.themePink
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

@Model final class WeightLog: @unchecked Sendable {
    var id: UUID = UUID()
    var date: Date = Date()
    var weight: Double = 0.0

    init(id: UUID = UUID(), date: Date = Date(), weight: Double = 0.0) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}
