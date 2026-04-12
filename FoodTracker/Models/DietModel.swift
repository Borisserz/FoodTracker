import SwiftUI


struct DietPlan: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let tagline: String
    let description: String
    let macroBreakdown: MacroBreakdown // Изменено на struct для корректного Hashable
    let bestFoods: [String] // Оставлено для совместимости с DietDetailView
    let contraindications: [String]
    let colorHex: UInt
    let categories: [FoodCategory] // НОВОЕ ПОЛЕ
    
    var color: Color {
        Color(hex: colorHex)
    }
    
    struct MacroBreakdown: Hashable {
        let fat: Int
        let protein: Int
        let carbs: Int
    }
    
    // Статическая база данных
    static let allDiets: [DietPlan] = [
        DietPlan(
            name: "Keto",
            tagline: "High fat, extremely low carb",
            description: "Forces your body to burn fat for fuel instead of carbohydrates. Effective for rapid fat loss but requires strict adherence.",
            macroBreakdown: MacroBreakdown(fat: 70, protein: 25, carbs: 5),
            bestFoods: ["Avocados", "Grass-fed Beef", "Wild Salmon", "Cheese", "Nuts & Seeds", "Coconut Oil"],
            contraindications: ["Liver conditions", "Pregnant women", "Gallbladder issues"],
            colorHex: 0xF2CF66,
            categories: [
                FoodCategory(title: "Healthy Fats", items: [
                    FoodItemDetail(name: "Avocado", calories: 160, icon: "🥑"),
                    FoodItemDetail(name: "Coconut Oil", calories: 120, icon: "🥥"),
                    FoodItemDetail(name: "Butter", calories: 100, icon: "🧈")
                ]),
                FoodCategory(title: "Proteins", items: [
                    FoodItemDetail(name: "Grass-fed Beef", calories: 250, icon: "🥩"),
                    FoodItemDetail(name: "Wild Salmon", calories: 208, icon: "🐟"),
                    FoodItemDetail(name: "Eggs", calories: 155, icon: "🥚")
                ]),
                FoodCategory(title: "Low-Carb Veggies", items: [
                    FoodItemDetail(name: "Broccoli", calories: 34, icon: "🥦"),
                    FoodItemDetail(name: "Spinach", calories: 23, icon: "🥬"),
                    FoodItemDetail(name: "Zucchini", calories: 17, icon: "🥒")
                ])
            ]
        ),
        DietPlan(
            name: "Vegan",
            tagline: "100% Plant-Based",
            description: "Eliminates all animal products. Excellent for environmental sustainability and can improve digestion.",
            macroBreakdown: MacroBreakdown(fat: 20, protein: 15, carbs: 65),
            bestFoods: ["Tofu & Tempeh", "Lentils", "Leafy Greens", "Quinoa", "Nuts", "Seeds"],
            contraindications: ["B12 deficiency risk", "Low protein if not planned properly", "Iron absorption concerns"],
            colorHex: 0x66BB6A,
            categories: [
                FoodCategory(title: "Plant Proteins", items: [
                    FoodItemDetail(name: "Tofu", calories: 144, icon: "🧊"),
                    FoodItemDetail(name: "Tempeh", calories: 193, icon: "🍘"),
                    FoodItemDetail(name: "Lentils", calories: 116, icon: "🍲")
                ]),
                FoodCategory(title: "Grains & Seeds", items: [
                    FoodItemDetail(name: "Quinoa", calories: 120, icon: "🍚"),
                    FoodItemDetail(name: "Chia Seeds", calories: 486, icon: "🥄"),
                    FoodItemDetail(name: "Oats", calories: 68, icon: "🥣")
                ]),
                FoodCategory(title: "Fruits", items: [
                    FoodItemDetail(name: "Banana", calories: 89, icon: "🍌"),
                    FoodItemDetail(name: "Apple", calories: 52, icon: "🍎"),
                    FoodItemDetail(name: "Berries", calories: 57, icon: "🫐")
                ])
            ]
        ),
        DietPlan(
            name: "High Protein",
            tagline: "Best for muscle building",
            description: "Maximizes muscle synthesis. Keeps you feeling full longer and supports recovery.",
            macroBreakdown: MacroBreakdown(fat: 30, protein: 40, carbs: 30),
            bestFoods: ["Chicken Breast", "Whey Protein", "Eggs", "Greek Yogurt", "Lean Beef", "Fish"],
            contraindications: ["Pre-existing kidney conditions", "Gout risk"],
            colorHex: 0xF25C78,
            categories: [
                FoodCategory(title: "Animal Protein", items: [
                    FoodItemDetail(name: "Chicken Breast", calories: 165, icon: "🍗"),
                    FoodItemDetail(name: "Turkey", calories: 135, icon: "🦃"),
                    FoodItemDetail(name: "Lean Beef", calories: 250, icon: "🥩")
                ]),
                FoodCategory(title: "Dairy & Eggs", items: [
                    FoodItemDetail(name: "Greek Yogurt", calories: 100, icon: "🥣"),
                    FoodItemDetail(name: "Cottage Cheese", calories: 98, icon: "🧀"),
                    FoodItemDetail(name: "Egg Whites", calories: 52, icon: "🥚")
                ]),
                FoodCategory(title: "Supplements", items: [
                    FoodItemDetail(name: "Whey Protein", calories: 110, icon: "🥤"),
                    FoodItemDetail(name: "Protein Bar", calories: 200, icon: "🍫"),
                    FoodItemDetail(name: "Casein", calories: 120, icon: "🥛")
                ])
            ]
        ),
        DietPlan(
            name: "Mediterranean",
            tagline: "Heart-healthy and balanced",
            description: "Inspired by traditional eating habits of Italy and Greece. Great for cardiovascular health.",
            macroBreakdown: MacroBreakdown(fat: 35, protein: 15, carbs: 50),
            bestFoods: ["Olive Oil", "Fresh Fish", "Whole Grains", "Vegetables", "Legumes", "Wine (moderate)"],
            contraindications: ["Iron deficiency if meat avoided", "Higher fat content"],
            colorHex: 0xF2B6A0,
            categories: [
                FoodCategory(title: "Healthy Oils & Fats", items: [
                    FoodItemDetail(name: "Olive Oil", calories: 119, icon: "🫒"),
                    FoodItemDetail(name: "Olives", calories: 115, icon: "🫒"),
                    FoodItemDetail(name: "Walnuts", calories: 654, icon: "🌰")
                ]),
                FoodCategory(title: "Whole Grains & Legumes", items: [
                    FoodItemDetail(name: "Chickpeas", calories: 164, icon: "🧆"),
                    FoodItemDetail(name: "Brown Rice", calories: 112, icon: "🍚"),
                    FoodItemDetail(name: "Quinoa", calories: 120, icon: "🌾")
                ]),
                FoodCategory(title: "Fresh Seafood", items: [
                    FoodItemDetail(name: "Salmon", calories: 208, icon: "🐟"),
                    FoodItemDetail(name: "Shrimp", calories: 99, icon: "🦐"),
                    FoodItemDetail(name: "Cod", calories: 82, icon: "🐠")
                ])
            ]
        )
    ]
}
