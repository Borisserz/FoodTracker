// File: FoodTracker/Utils/SampleData.swift

import SwiftUI
import SwiftData

// MARK: - Sample Data Generator (for testing/preview)
class SampleDataGenerator {
    static func createSampleData() -> [DailySummary] {
        let calendar = Calendar.current
        var summaries: [DailySummary] = []
        
        let foodItems1_breakfast = [
            FoodItem(name: "Scrambled Eggs", weight: 100, calories: 155, protein: 13, fats: 11, carbs: 1),
            FoodItem(name: "Whole Grain Toast", weight: 50, calories: 130, protein: 4, fats: 2.5, carbs: 23)
        ]
        
        let meal1_breakfast = Meal(title: "Breakfast", date: Date.now, foodItems: foodItems1_breakfast)
        
        let foodItems1_lunch = [
            FoodItem(name: "Grilled Chicken", weight: 150, calories: 240, protein: 31, fats: 3.6, carbs: 0),
            FoodItem(name: "White Rice", weight: 200, calories: 260, protein: 5.4, fats: 0.3, carbs: 58)
        ]
        
        let meal1_lunch = Meal(title: "Lunch", date: Date.now, foodItems: foodItems1_lunch)
        
        let today = DailySummary(
            date: Date.now,
            meals: [meal1_breakfast, meal1_lunch],
            beverages: []
        )
        today.weight = 75.0
        
        summaries.append(today)
        
     
        for i in 1...6 {
            guard let date = calendar.date(byAdding: .day, value: -i, to: Date.now) else { continue }
            
            let randomMeals = [
                Meal(title: "Breakfast", date: date, foodItems: foodItems1_breakfast),
                Meal(title: "Lunch", date: date, foodItems: foodItems1_lunch)
            ]
            
            let summary = DailySummary(date: date, meals: randomMeals, beverages: [])
            summary.weight = 75.0 - Double(i) * 0.2
            
            summaries.append(summary)
        }
        
        return summaries
    }
    
    static func createSampleUser() -> User {
        return User(name: "Alex", weight: 75.0, height: 180.0, age: 28, gender: "Male")
    }
    
    static func createSampleRecipes() -> [CustomRecipe] {
        return [
            CustomRecipe(
                name: "Oatmeal Bowl",
                info: "Healthy breakfast with oats, berries, and almonds",
                foodItems: [
                    FoodItem(name: "Oats", weight: 50, calories: 190, protein: 5, fats: 5, carbs: 34),
                    FoodItem(name: "Blueberries", weight: 100, calories: 57, protein: 0.7, fats: 0.3, carbs: 14)
                ],
                cookingTime: 10,
                difficulty: "Easy"
            ),
            CustomRecipe(
                name: "Protein Smoothie",
                info: "Post-workout protein recovery shake",
                foodItems: [
                    FoodItem(name: "Whey Protein", weight: 30, calories: 110, protein: 24, fats: 1, carbs: 2),
                    FoodItem(name: "Banana", weight: 100, calories: 89, protein: 1.1, fats: 0.3, carbs: 23)
                ],
                cookingTime: 5,
                difficulty: "Easy"
            ),
            CustomRecipe(
                name: "Salmon Salad",
                info: "Mediterranean-style salmon with mixed greens",
                foodItems: [
                    FoodItem(name: "Salmon", weight: 120, calories: 208, protein: 22, fats: 13, carbs: 0),
                    FoodItem(name: "Mixed Greens", weight: 100, calories: 23, protein: 2.2, fats: 0.4, carbs: 3.7)
                ],
                cookingTime: 20,
                difficulty: "Medium"
            )
        ]
    }
}
