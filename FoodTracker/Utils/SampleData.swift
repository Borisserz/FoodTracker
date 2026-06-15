import SwiftUI
import SwiftData

class SampleDataGenerator {
    static func createSampleData() -> [DailySummary] {
        let calendar = Calendar.current
        var summaries: [DailySummary] = []

        let foodItems1_breakfast = [
            FoodItem(name: String(localized: "Scrambled Eggs"), weight: 100, calories: 155, protein: 13, fats: 11, carbs: 1, omega3: 0.1, calcium: 50, potassium: 130, magnesium: 12, iron: 1.2, vitaminC: 0, vitaminD: 1.0),
            FoodItem(name: String(localized: "Whole Grain Toast"), weight: 50, calories: 130, protein: 4, fats: 2.5, carbs: 23, omega3: 0.0, calcium: 30, potassium: 100, magnesium: 40, iron: 1.5, vitaminC: 0, vitaminD: 0.0)
        ]

        let meal1_breakfast = Meal(title: String(localized: "Breakfast"), date: Date.now, foodItems: foodItems1_breakfast)

        let foodItems1_lunch = [
            FoodItem(name: String(localized: "Grilled Chicken"), weight: 150, calories: 240, protein: 31, fats: 3.6, carbs: 0, omega3: 0.0, calcium: 15, potassium: 300, magnesium: 30, iron: 1.0, vitaminC: 0, vitaminD: 0.0),
            FoodItem(name: String(localized: "White Rice"), weight: 200, calories: 260, protein: 5.4, fats: 0.3, carbs: 58, omega3: 0.0, calcium: 10, potassium: 50, magnesium: 20, iron: 0.5, vitaminC: 0, vitaminD: 0.0)
        ]

        let meal1_lunch = Meal(title: String(localized: "Lunch"), date: Date.now, foodItems: foodItems1_lunch)

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
                Meal(title: String(localized: "Breakfast"), date: date, foodItems: foodItems1_breakfast),
                Meal(title: String(localized: "Lunch"), date: date, foodItems: foodItems1_lunch)
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
                name: String(localized: "Oatmeal Bowl"),
                info: String(localized: "Healthy breakfast with oats, berries, and almonds"),
                foodItems: [
                    FoodItem(name: String(localized: "Oats"), weight: 50, calories: 190, protein: 5, fats: 5, carbs: 34, omega3: 0.0, calcium: 20, potassium: 150, magnesium: 50, iron: 2.0, vitaminC: 0, vitaminD: 0),
                    FoodItem(name: String(localized: "Blueberries"), weight: 100, calories: 57, protein: 0.7, fats: 0.3, carbs: 14, omega3: 0.0, calcium: 6, potassium: 77, magnesium: 6, iron: 0.3, vitaminC: 9.7, vitaminD: 0)
                ],
                cookingTime: 10,
                difficulty: String(localized: "Easy")
            ),
            CustomRecipe(
                name: String(localized: "Protein Smoothie"),
                info: String(localized: "Post-workout protein recovery shake"),
                foodItems: [
                    FoodItem(name: String(localized: "Whey Protein"), weight: 30, calories: 110, protein: 24, fats: 1, carbs: 2, omega3: 0.0, calcium: 150, potassium: 100, magnesium: 20, iron: 0.5, vitaminC: 0, vitaminD: 0),
                    FoodItem(name: String(localized: "Banana"), weight: 100, calories: 89, protein: 1.1, fats: 0.3, carbs: 23, omega3: 0.0, calcium: 5, potassium: 358, magnesium: 27, iron: 0.3, vitaminC: 8.7, vitaminD: 0)
                ],
                cookingTime: 5,
                difficulty: String(localized: "Easy")
            ),
            CustomRecipe(
                name: String(localized: "Salmon Salad"),
                info: String(localized: "Mediterranean-style salmon with mixed greens"),
                foodItems: [
                    FoodItem(name: String(localized: "Salmon"), weight: 120, calories: 208, protein: 22, fats: 13, carbs: 0, omega3: 2.5, calcium: 15, potassium: 450, magnesium: 35, iron: 0.8, vitaminC: 0, vitaminD: 10.0),
                    FoodItem(name: String(localized: "Mixed Greens"), weight: 100, calories: 23, protein: 2.2, fats: 0.4, carbs: 3.7, omega3: 0.0, calcium: 100, potassium: 300, magnesium: 40, iron: 1.5, vitaminC: 25.0, vitaminD: 0)
                ],
                cookingTime: 20,
                difficulty: String(localized: "Medium")
            )
        ]
    }
}
