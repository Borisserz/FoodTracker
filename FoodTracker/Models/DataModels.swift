//
//  DataModels.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 12.04.26.
//

import SwiftUI
import SwiftData
import Observation

// MARK: - USER MODEL
@Model final class User {
    var name: String
    var weight: Double
    var height: Double
    var age: Int
    var gender: String
    var dailyCaloriesGoal: Int
    var createdDate: Date
    
    init(name: String, weight: Double, height: Double, age: Int, gender: String = "Male") {
        self.name = name
        self.weight = weight
        self.height = height
        self.age = age
        self.gender = gender
        self.createdDate = Date()
        self.dailyCaloriesGoal = 0
        self.calculateGoals()
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

// MARK: - CUSTOM RECIPE MODEL
@Model final class CustomRecipe {
    var name: String
    var info: String
    @Relationship(deleteRule: .cascade) var foodItems: [FoodItem] = []
    var cookingTime: Int
    var difficulty: String
    
    var totalCalories: Int { foodItems.reduce(0) { $0 + $1.calories } }

    init(name: String, info: String, foodItems: [FoodItem] = [], cookingTime: Int, difficulty: String) {
        self.name = name; self.info = info; self.foodItems = foodItems
        self.cookingTime = cookingTime; self.difficulty = difficulty
    }
}

// MARK: - DAILY SUMMARY MODEL
@Model final class DailySummary {
    @Attribute(.unique) var date: Date
    @Relationship(deleteRule: .cascade) var meals: [Meal] = []
    @Relationship(deleteRule: .cascade) var beverages: [Beverage] = []
    var weight: Double?

    var totalFoodCalories: Int { meals.reduce(0) { $0 + $1.totalCalories } }
    var totalDrinkCalories: Int { beverages.reduce(0) { $0 + $1.caloriesPerGlass } }
    var totalCalories: Int { totalFoodCalories + totalDrinkCalories }
    
    var totalHydrationLiters: Double { beverages.reduce(0) { $0 + $1.volumeMl } / 1000.0 }
    
    var totalProtein: Double { meals.reduce(0) { $0 + $1.totalProtein } }
    var totalFats: Double { meals.reduce(0) { $0 + $1.totalFats } }
    var totalCarbs: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
    
    init(date: Date, meals: [Meal] = [], beverages: [Beverage] = []) {
        self.date = Calendar.current.startOfDay(for: date) // Строго начало дня
        self.meals = meals; self.beverages = beverages
    }
}
