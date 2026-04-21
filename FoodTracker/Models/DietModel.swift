import SwiftUI

// MARK: - МОДЕЛИ ДЛЯ КАТЕГОРИЙ
struct FoodItemDetail: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let calories: Int
    let icon: String
}

struct FoodCategory: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let items: [FoodItemDetail]
}

// MARK: - ОСНОВНАЯ МОДЕЛЬ ДИЕТЫ
struct DietPlan: Identifiable, Hashable {
    let id: UUID = UUID()
    let key: String  // Internal identifier (e.g., "keto", "vegan") - NOT localized
    let name: String  // Display name - localized
    let tagline: String
    let description: String
    let macroBreakdown: MacroBreakdown
    let bestFoods: [String]
    let contraindications: [String]
    let colorHex: UInt
    let categories: [FoodCategory]
    
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
            key: "keto",
            name: String(localized: "Keto"),
            tagline: String(localized: "High fat, extremely low carb"),
            description: String(localized: "Forces your body to burn fat for fuel instead of carbohydrates. Effective for rapid fat loss but requires strict adherence."),
            macroBreakdown: MacroBreakdown(fat: 70, protein: 25, carbs: 5),
            bestFoods: [String(localized: "Avocados"), String(localized: "Grass-fed Beef"), String(localized: "Wild Salmon"), String(localized: "Cheese"), String(localized: "Nuts & Seeds"), String(localized: "Coconut Oil")],
            contraindications: [String(localized: "Liver conditions"), String(localized: "Pregnant women"), String(localized: "Gallbladder issues")],
            colorHex: 0xF2CF66,
            categories: [
                FoodCategory(title: String(localized: "Healthy Fats"), items: [
                    FoodItemDetail(name: String(localized: "Avocado"), calories: 160, icon: "🥑"),
                    FoodItemDetail(name: String(localized: "Coconut Oil"), calories: 120, icon: "🥥"),
                    FoodItemDetail(name: String(localized: "Butter"), calories: 100, icon: "🧈")
                ]),
                FoodCategory(title: String(localized: "Proteins"), items: [
                    FoodItemDetail(name: String(localized: "Grass-fed Beef"), calories: 250, icon: "🥩"),
                    FoodItemDetail(name: String(localized: "Wild Salmon"), calories: 208, icon: "🐟"),
                    FoodItemDetail(name: String(localized: "Eggs"), calories: 155, icon: "🥚")
                ]),
                FoodCategory(title: String(localized: "Low-Carb Veggies"), items: [
                    FoodItemDetail(name: String(localized: "Broccoli"), calories: 34, icon: "🥦"),
                    FoodItemDetail(name: String(localized: "Spinach"), calories: 23, icon: "🥬"),
                    FoodItemDetail(name: String(localized: "Zucchini"), calories: 17, icon: "🥒")
                ])
            ]
        ),
        DietPlan(
            key: "vegan",
            name: String(localized: "Vegan"),
            tagline: String(localized: "100% Plant-Based"),
            description: String(localized: "Eliminates all animal products. Excellent for environmental sustainability and can improve digestion."),
            macroBreakdown: MacroBreakdown(fat: 20, protein: 15, carbs: 65),
            bestFoods: [String(localized: "Tofu & Tempeh"), String(localized: "Lentils"), String(localized: "Leafy Greens"), String(localized: "Quinoa"), String(localized: "Nuts"), String(localized: "Seeds")],
            contraindications: [String(localized: "B12 deficiency risk"), String(localized: "Low protein if not planned properly"), String(localized: "Iron absorption concerns")],
            colorHex: 0x66BB6A,
            categories: [
                FoodCategory(title: String(localized: "Plant Proteins"), items: [
                    FoodItemDetail(name: String(localized: "Tofu"), calories: 144, icon: "🧊"),
                    FoodItemDetail(name: String(localized: "Tempeh"), calories: 193, icon: "🍘"),
                    FoodItemDetail(name: String(localized: "Lentils"), calories: 116, icon: "🍲")
                ]),
                FoodCategory(title: String(localized: "Grains & Seeds"), items: [
                    FoodItemDetail(name: String(localized: "Quinoa"), calories: 120, icon: "🍚"),
                    FoodItemDetail(name: String(localized: "Chia Seeds"), calories: 486, icon: "🥄"),
                    FoodItemDetail(name: String(localized: "Oats"), calories: 68, icon: "🥣")
                ]),
                FoodCategory(title: String(localized: "Fruits"), items: [
                    FoodItemDetail(name: String(localized: "Banana"), calories: 89, icon: "🍌"),
                    FoodItemDetail(name: String(localized: "Apple"), calories: 52, icon: "🍎"),
                    FoodItemDetail(name: String(localized: "Berries"), calories: 57, icon: "🫐")
                ])
            ]
        ),
        DietPlan(
            key: "high_protein",
            name: String(localized: "High Protein"),
            tagline: String(localized: "Best for muscle building"),
            description: String(localized: "Maximizes muscle synthesis. Keeps you feeling full longer and supports recovery."),
            macroBreakdown: MacroBreakdown(fat: 30, protein: 40, carbs: 30),
            bestFoods: [String(localized: "Chicken Breast"), String(localized: "Whey Protein"), String(localized: "Eggs"), String(localized: "Greek Yogurt"), String(localized: "Lean Beef"), String(localized: "Fish")],
            contraindications: [String(localized: "Pre-existing kidney conditions"), String(localized: "Gout risk")],
            colorHex: 0xF25C78,
            categories: [
                FoodCategory(title: String(localized: "Animal Protein"), items: [
                    FoodItemDetail(name: String(localized: "Chicken Breast"), calories: 165, icon: "🍗"),
                    FoodItemDetail(name: String(localized: "Turkey"), calories: 135, icon: "🦃"), // ✅ ИСПРАВЛЕНО ЗДЕСЬ (Вернули кавычку)
                    FoodItemDetail(name: String(localized: "Lean Beef"), calories: 250, icon: "🥩")
                ]),
                FoodCategory(title: String(localized: "Dairy & Eggs"), items: [
                    FoodItemDetail(name: String(localized: "Greek Yogurt"), calories: 100, icon: "🥣"),
                    FoodItemDetail(name: String(localized: "Cottage Cheese"), calories: 98, icon: "🧀"),
                    FoodItemDetail(name: String(localized: "Egg Whites"), calories: 52, icon: "🥚")
                ]),
                FoodCategory(title: String(localized: "Supplements"), items: [
                    FoodItemDetail(name: String(localized: "Whey Protein"), calories: 110, icon: "🥤"),
                    FoodItemDetail(name: String(localized: "Protein Bar"), calories: 200, icon: "🍫"),
                    FoodItemDetail(name: String(localized: "Casein"), calories: 120, icon: "🥛")
                ])
            ]
        ),
        DietPlan(
            key: "mediterranean",
            name: String(localized: "Mediterranean"),
            tagline: String(localized: "Heart-healthy and balanced"),
            description: String(localized: "Inspired by traditional eating habits of Italy and Greece. Great for cardiovascular health."),
            macroBreakdown: MacroBreakdown(fat: 35, protein: 15, carbs: 50),
            bestFoods: [String(localized: "Olive Oil"), String(localized: "Fresh Fish"), String(localized: "Whole Grains"), String(localized: "Vegetables"), String(localized: "Legumes"), String(localized: "Wine (moderate)")],
            contraindications: [String(localized: "Iron deficiency if meat avoided"), String(localized: "Higher fat content")],
            colorHex: 0xF2B6A0,
            categories: [
                FoodCategory(title: String(localized: "Healthy Oils & Fats"), items: [
                    FoodItemDetail(name: String(localized: "Olive Oil"), calories: 119, icon: "🫒"),
                    FoodItemDetail(name: String(localized: "Olives"), calories: 115, icon: "🫒"),
                    FoodItemDetail(name: String(localized: "Walnuts"), calories: 654, icon: "🌰")
                ]),
                FoodCategory(title: String(localized: "Whole Grains & Legumes"), items: [
                    FoodItemDetail(name: String(localized: "Chickpeas"), calories: 164, icon: "🧆"),
                    FoodItemDetail(name: String(localized: "Brown Rice"), calories: 112, icon: "🍚"),
                    FoodItemDetail(name: String(localized: "Quinoa"), calories: 120, icon: "🌾")
                ]),
                FoodCategory(title: String(localized: "Fresh Seafood"), items: [
                    FoodItemDetail(name: String(localized: "Salmon"), calories: 208, icon: "🐟"),
                    FoodItemDetail(name: String(localized: "Shrimp"), calories: 99, icon: "🦐"),
                    FoodItemDetail(name: String(localized: "Cod"), calories: 82, icon: "🐠")
                ])
            ]
        )
    ]
}

// MARK: - РАСШИРЕНИЯ (Умная логика совместимости)

extension User {
    var activeDietPlan: DietPlan? {
        DietPlan.allDiets.first(where: { $0.key == self.activeDietKey })
    }
}

extension FoodItem {
    enum DietCompatibility {
        case perfect, neutral, avoid
        
        var icon: String {
            switch self {
            case .perfect: return "checkmark.seal.fill"
            case .neutral: return "minus.circle.fill"
            case .avoid: return "xmark.octagon.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .perfect: return .green
            case .neutral: return .gray
            case .avoid: return .red
            }
        }
    }
    
    // Проверяем, подходит ли продукт под макросы текущей диеты
    func compatibility(with diet: DietPlan?) -> DietCompatibility {
        guard let diet = diet else { return .neutral }
        
        let totalCals = Double(calories > 0 ? calories : 1)
        let cPct = (carbs * 4.0) / totalCals * 100
        let fPct = (fats * 9.0) / totalCals * 100
        let pPct = (protein * 4.0) / totalCals * 100
        
        switch diet.key {
        case "keto":
            if cPct < 10 && fPct > 50 { return .perfect }
            if cPct > 30 { return .avoid }
        case "vegan":
            if name.lowercased().contains("meat") || name.lowercased().contains("chicken") || name.lowercased().contains("beef") { return .avoid }
        case "high_protein":
            if pPct > 30 { return .perfect }
            if pPct < 10 && calories > 200 { return .avoid }
        case "mediterranean":
            if fPct > 20 && pPct > 15 { return .perfect }
        default:
            return .neutral
        }
        
        return .neutral
    }
}
