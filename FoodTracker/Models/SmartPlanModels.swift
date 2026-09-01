import Foundation
import SwiftData

@Model
final class WeeklyMealPlan {
    var id: UUID = UUID()
    var createdDate: Date = Date()
    var targetCalories: Int = 0
    var dietType: String = ""
    var isCurrentPlan: Bool = true
    
    @Relationship(deleteRule: .cascade)
    var days: [MealPlanDay] = []
    
    init(targetCalories: Int, dietType: String, isCurrentPlan: Bool = true) {
        self.targetCalories = targetCalories
        self.dietType = dietType
        self.isCurrentPlan = isCurrentPlan
    }
}

@Model
final class MealPlanDay {
    var id: UUID = UUID()
    var dayIndex: Int = 0 // 0 to 6 for a 7-day plan
    var totalCalories: Int = 0
    var totalProtein: Int = 0
    var totalCarbs: Int = 0
    var totalFat: Int = 0
    
    @Relationship(deleteRule: .cascade)
    var meals: [MealPlanItem] = []
    
    var parentPlan: WeeklyMealPlan?
    
    init(dayIndex: Int, totalCalories: Int, totalProtein: Int, totalCarbs: Int, totalFat: Int) {
        self.dayIndex = dayIndex
        self.totalCalories = totalCalories
        self.totalProtein = totalProtein
        self.totalCarbs = totalCarbs
        self.totalFat = totalFat
    }
}

@Model
final class MealPlanItem {
    var id: UUID = UUID()
    var title: String = ""
    var type: String = "Breakfast" // Breakfast, Lunch, Dinner, Snack
    var calories: Int = 0
    var protein: Int = 0
    var carbs: Int = 0
    var fat: Int = 0
    var ingredients: String = "" // Comma separated
    var instructions: String = ""
    var prepTimeMinutes: Int = 0
    
    var parentDay: MealPlanDay?
    
    init(title: String, type: String, calories: Int, protein: Int, carbs: Int, fat: Int, ingredients: String, instructions: String, prepTimeMinutes: Int) {
        self.title = title
        self.type = type
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.ingredients = ingredients
        self.instructions = instructions
        self.prepTimeMinutes = prepTimeMinutes
    }
}
