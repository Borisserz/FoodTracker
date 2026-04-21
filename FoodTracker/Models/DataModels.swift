//
//  DataModels.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 12.04.26.
//

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
// MARK: - ACHIEVEMENTS (Геймификация)
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

// MARK: - USER MODEL
@Model final class User {
    var name: String
    var weight: Double
    var height: Double
    var age: Int
    var gender: String
    var dailyCaloriesGoal: Int
    var createdDate: Date
    var isHealthKitEnabled: Bool = false
    
    // НОВЫЕ ПОЛЯ ДЛЯ ДИЕТ И МАКРОСОВ
    var activeDietKey: String = "balanced"  // Internal diet identifier (not localized)
    var targetProtein: Double = 150.0
    var targetFats: Double = 70.0
    var targetCarbs: Double = 250.0
    
    // НОВОЕ ПОЛЕ ДЛЯ ДОСТИЖЕНИЙ
    var unlockedAchievements: [String] = []
    
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
        
        self.unlockedAchievements = [] // Дефолтное значение для избежания крэшей
        
        self.calculateGoals()
        // Устанавливаем дефолтное соотношение при создании пользователя (30% жиры / 30% белки / 40% углеводы)
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
    
    // НОВЫЙ МЕТОД ДЛЯ ПРИМЕНЕНИЯ ДИЕТЫ
    func applyDietBreakdown(fatPercent: Int, proteinPercent: Int, carbsPercent: Int, dietKey: String) {
        self.activeDietKey = dietKey
        let targetCalories = Double(dailyCaloriesGoal)
        
        // 1 грамм белка = 4 ккал, 1 грамм углеводов = 4 ккал, 1 грамм жира = 9 ккал
        self.targetProtein = (targetCalories * Double(proteinPercent) / 100.0) / 4.0
        self.targetCarbs   = (targetCalories * Double(carbsPercent) / 100.0) / 4.0
        self.targetFats    = (targetCalories * Double(fatPercent) / 100.0) / 9.0
    }
}

// MARK: - BEVERAGE MODEL (Event-based)
@Model final class Beverage {
    var date: Date
    var name: String
    var icon: String
    var colorHex: String
    var caloriesPerGlass: Int
    var volumeMl: Double

    init(date: Date = Date(), name: String, icon: String, colorHex: String, caloriesPerGlass: Int, volumeMl: Double = 250.0) {
        self.date = date
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.caloriesPerGlass = caloriesPerGlass
        self.volumeMl = volumeMl
    }
}

// MARK: - FOOD ITEM MODEL
@Model final class FoodItem {
    var id: UUID = UUID()
    var name: String
    var weight: Double
    var calories: Int
    var protein: Double
    var fats: Double
    var carbs: Double

    var omega3: Double
    var calcium: Double
    var potassium: Double
    var magnesium: Double
    var iron: Double
    var vitaminC: Double
    var vitaminD: Double

    init(name: String, weight: Double, calories: Int, protein: Double, fats: Double, carbs: Double,
         omega3: Double = 0, calcium: Double = 0, potassium: Double = 0,
         magnesium: Double = 0, iron: Double = 0, vitaminC: Double = 0, vitaminD: Double = 0) {
        
        self.id = UUID() // 🔥 ВОТ ЭТО ИСПРАВИТ ПУСТОЙ ЭКРАН! (Заставляем Swift генерировать уникальный ID)
        
        self.name = name; self.weight = weight; self.calories = calories
        self.protein = protein; self.fats = fats; self.carbs = carbs
        self.omega3 = omega3; self.calcium = calcium; self.potassium = potassium
        self.magnesium = magnesium; self.iron = iron; self.vitaminC = vitaminC; self.vitaminD = vitaminD
    }
}

// MARK: - MEAL MODEL
@Model final class Meal {
    var title: String
    var date: Date
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
    var name: String
    var info: String
    @Relationship(deleteRule: .cascade) var foodItems: [FoodItem] = []
    var cookingTime: Int
    var difficulty: String
    
    // НОВЫЕ ПОЛЯ
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

// MARK: - DAILY SUMMARY MODEL
@Model final class DailySummary {
    @Attribute(.unique) var date: Date
    @Relationship(deleteRule: .cascade) var meals: [Meal] = []
    @Relationship(deleteRule: .cascade) var beverages: [Beverage] = []
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
    
    // ✅ НОВОЕ: Чистый баланс (Съедено - Сожжено)
    var netCalories: Int {
        totalCalories - activeCaloriesBurned
    }
    
    func remainingCalories(userGoal: Int) -> Int {
        return (userGoal + activeCaloriesBurned) - totalCalories
    }
    
    init(date: Date, meals: [Meal] = [], beverages: [Beverage] = []) {
        self.date = Calendar.current.startOfDay(for: date)
        self.meals = meals; self.beverages = beverages
        self.activeCaloriesBurned = 0
        self.stepsCount = 0
        self.workoutCalories = 0
    }
}
// MARK: - EXTENSIONS
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
    // Вычисляем грейд на основе плотности калорий и процента белка
    var healthGrade: HealthGrade {
        let proteinCals = protein * 4.0
        let proteinPercentage = calories > 0 ? (proteinCals / Double(calories)) : 0
        
        // Если белка больше 20% от калорий ИЛИ это низкокалорийный продукт (овощи)
        if proteinPercentage > 0.20 || (calories < 100 && carbs < 15) {
            return .clean
        }
        // Если калорий много, а белка мало (сладости, фастфуд)
        else if calories > 350 && proteinPercentage < 0.10 {
            return .treat
        }
        // Все остальное - сбалансированная еда (рис, обычное мясо, хлеб)
        else {
            return .balanced
        }
    }
}
@Model final class ShoppingItem {
    var id: UUID = UUID()
    var name: String
    var amount: String
    var isChecked: Bool
    var addedFromRecipe: String?
    var dateAdded: Date
    
    init(name: String, amount: String = "", isChecked: Bool = false, addedFromRecipe: String? = nil) {
        self.name = name
        self.amount = amount
        self.isChecked = isChecked
        self.addedFromRecipe = addedFromRecipe
        self.dateAdded = Date()
    }
}
