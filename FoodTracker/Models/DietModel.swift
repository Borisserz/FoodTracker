import SwiftUI
import FirebaseFirestore
struct FoodItemDetail: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    let name: String
    let calories: Int
    let icon: String
}

struct FoodCategory: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    let title: String
    let items: [FoodItemDetail]
}

struct DietPlan: Identifiable, Hashable, Codable {
    @DocumentID var id: String?
    let key: String
    let name: String
    let tagline: String
    let description: String
    let macroBreakdown: MacroBreakdown
    let bestFoods: [String]
    let contraindications: [String]
    let colorHex: UInt
    let categories: [FoodCategory]

    var color: Color { Color(hex: colorHex) }

    struct MacroBreakdown: Hashable, Codable {
        let fat: Int
        let protein: Int
        let carbs: Int
    }
    
    static let defaultDiets: [DietPlan] = [
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
                    FoodItemDetail(name: String(localized: "Turkey"), calories: 135, icon: "🦃"),
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
        ),
        DietPlan(
            key: "paleo",
            name: String(localized: "Paleo"),
            tagline: String(localized: "Eat like our ancestors"),
            description: String(localized: "Focuses on whole foods like meat, fish, eggs, vegetables, and nuts. Excludes processed foods, grains, and dairy."),
            macroBreakdown: MacroBreakdown(fat: 40, protein: 30, carbs: 30),
            bestFoods: [String(localized: "Grass-fed Meat"), String(localized: "Wild Fish"), String(localized: "Eggs"), String(localized: "Nuts"), String(localized: "Vegetables"), String(localized: "Fruits")],
            contraindications: [String(localized: "Vegetarians/Vegans"), String(localized: "Those needing cheap calories")],
            colorHex: 0x8D6E63,
            categories: [
                FoodCategory(title: String(localized: "Meat & Fish"), items: [
                    FoodItemDetail(name: String(localized: "Beef"), calories: 250, icon: "🥩"),
                    FoodItemDetail(name: String(localized: "Salmon"), calories: 208, icon: "🐟"),
                    FoodItemDetail(name: String(localized: "Eggs"), calories: 155, icon: "🥚")
                ]),
                FoodCategory(title: String(localized: "Fruits & Veggies"), items: [
                    FoodItemDetail(name: String(localized: "Sweet Potato"), calories: 86, icon: "🍠"),
                    FoodItemDetail(name: String(localized: "Broccoli"), calories: 34, icon: "🥦"),
                    FoodItemDetail(name: String(localized: "Apples"), calories: 52, icon: "🍎")
                ]),
                FoodCategory(title: String(localized: "Nuts & Seeds"), items: [
                    FoodItemDetail(name: String(localized: "Almonds"), calories: 579, icon: "🥜"),
                    FoodItemDetail(name: String(localized: "Walnuts"), calories: 654, icon: "🌰"),
                    FoodItemDetail(name: String(localized: "Pumpkin Seeds"), calories: 446, icon: "🎃")
                ])
            ]
        ),
        DietPlan(
            key: "carnivore",
            name: String(localized: "Carnivore"),
            tagline: String(localized: "100% Animal Products"),
            description: String(localized: "An extreme elimination diet consisting entirely of meat, fish, eggs, and some dairy. Zero plant foods."),
            macroBreakdown: MacroBreakdown(fat: 60, protein: 40, carbs: 0),
            bestFoods: [String(localized: "Ribeye Steak"), String(localized: "Ground Beef"), String(localized: "Eggs"), String(localized: "Butter"), String(localized: "Bacon"), String(localized: "Salmon")],
            contraindications: [String(localized: "High cholesterol risk"), String(localized: "Kidney issues"), String(localized: "Digestive issues without fiber")],
            colorHex: 0xE53935,
            categories: [
                FoodCategory(title: String(localized: "Ruminant Meat"), items: [
                    FoodItemDetail(name: String(localized: "Ribeye Steak"), calories: 291, icon: "🥩"),
                    FoodItemDetail(name: String(localized: "Ground Beef"), calories: 250, icon: "🥩"),
                    FoodItemDetail(name: String(localized: "Lamb"), calories: 294, icon: "🍖")
                ]),
                FoodCategory(title: String(localized: "Pork & Poultry"), items: [
                    FoodItemDetail(name: String(localized: "Bacon"), calories: 541, icon: "🥓"),
                    FoodItemDetail(name: String(localized: "Chicken Thighs"), calories: 209, icon: "🍗"),
                    FoodItemDetail(name: String(localized: "Pork Chops"), calories: 231, icon: "🥩")
                ]),
                FoodCategory(title: String(localized: "Animal Fats"), items: [
                    FoodItemDetail(name: String(localized: "Butter"), calories: 717, icon: "🧈"),
                    FoodItemDetail(name: String(localized: "Ghee"), calories: 900, icon: "🧈"),
                    FoodItemDetail(name: String(localized: "Tallow"), calories: 902, icon: "🥩")
                ])
            ]
        ),
        DietPlan(
            key: "pescatarian",
            name: String(localized: "Pescatarian"),
            tagline: String(localized: "Vegetarian plus seafood"),
            description: String(localized: "A plant-based diet that includes fish and seafood. Offers the benefits of a vegetarian diet with added omega-3s."),
            macroBreakdown: MacroBreakdown(fat: 25, protein: 25, carbs: 50),
            bestFoods: [String(localized: "Salmon"), String(localized: "Shrimp"), String(localized: "Leafy Greens"), String(localized: "Quinoa"), String(localized: "Lentils"), String(localized: "Seaweed")],
            contraindications: [String(localized: "Mercury exposure from some fish"), String(localized: "Seafood allergies")],
            colorHex: 0x4FC3F7,
            categories: [
                FoodCategory(title: String(localized: "Seafood"), items: [
                    FoodItemDetail(name: String(localized: "Salmon"), calories: 208, icon: "🐟"),
                    FoodItemDetail(name: String(localized: "Shrimp"), calories: 99, icon: "🦐"),
                    FoodItemDetail(name: String(localized: "Tuna"), calories: 132, icon: "🐠")
                ]),
                FoodCategory(title: String(localized: "Plant Proteins"), items: [
                    FoodItemDetail(name: String(localized: "Tofu"), calories: 144, icon: "🧊"),
                    FoodItemDetail(name: String(localized: "Edamame"), calories: 121, icon: "🫛"),
                    FoodItemDetail(name: String(localized: "Lentils"), calories: 116, icon: "🍲")
                ]),
                FoodCategory(title: String(localized: "Vegetables"), items: [
                    FoodItemDetail(name: String(localized: "Seaweed"), calories: 43, icon: "🌿"),
                    FoodItemDetail(name: String(localized: "Spinach"), calories: 23, icon: "🥬"),
                    FoodItemDetail(name: String(localized: "Broccoli"), calories: 34, icon: "🥦")
                ])
            ]
        ),
        DietPlan(
            key: "dash",
            name: String(localized: "DASH Diet"),
            tagline: String(localized: "Dietary Approaches to Stop Hypertension"),
            description: String(localized: "Designed to help treat or prevent high blood pressure. Emphasizes vegetables, fruits, and low-fat dairy foods."),
            macroBreakdown: MacroBreakdown(fat: 27, protein: 18, carbs: 55),
            bestFoods: [String(localized: "Leafy Greens"), String(localized: "Berries"), String(localized: "Oatmeal"), String(localized: "Low-fat Yogurt"), String(localized: "Chicken"), String(localized: "Nuts")],
            contraindications: [String(localized: "Requires avoiding high sodium")],
            colorHex: 0x5C6BC0,
            categories: [
                FoodCategory(title: String(localized: "Fruits & Veggies"), items: [
                    FoodItemDetail(name: String(localized: "Spinach"), calories: 23, icon: "🥬"),
                    FoodItemDetail(name: String(localized: "Blueberries"), calories: 57, icon: "🫐"),
                    FoodItemDetail(name: String(localized: "Banana"), calories: 89, icon: "🍌")
                ]),
                FoodCategory(title: String(localized: "Lean Proteins"), items: [
                    FoodItemDetail(name: String(localized: "Chicken Breast"), calories: 165, icon: "🍗"),
                    FoodItemDetail(name: String(localized: "Turkey"), calories: 135, icon: "🦃"),
                    FoodItemDetail(name: String(localized: "Lentils"), calories: 116, icon: "🍲")
                ]),
                FoodCategory(title: String(localized: "Low-fat Dairy"), items: [
                    FoodItemDetail(name: String(localized: "Skim Milk"), calories: 83, icon: "🥛"),
                    FoodItemDetail(name: String(localized: "Greek Yogurt"), calories: 100, icon: "🥣")
                ])
            ]
        ),
        DietPlan(
            key: "vegetarian",
            name: String(localized: "Vegetarian"),
            tagline: String(localized: "Plant-based with dairy & eggs"),
            description: String(localized: "Excludes meat, poultry, and seafood, but allows dairy products and eggs. Great for cardiovascular health and sustainability."),
            macroBreakdown: MacroBreakdown(fat: 25, protein: 20, carbs: 55),
            bestFoods: [String(localized: "Eggs"), String(localized: "Cheese"), String(localized: "Legumes"), String(localized: "Whole Grains"), String(localized: "Nuts"), String(localized: "Vegetables")],
            contraindications: [String(localized: "Dairy/egg allergies")],
            colorHex: 0x8BC34A,
            categories: [
                FoodCategory(title: String(localized: "Dairy & Eggs"), items: [
                    FoodItemDetail(name: String(localized: "Eggs"), calories: 155, icon: "🥚"),
                    FoodItemDetail(name: String(localized: "Cheese"), calories: 402, icon: "🧀"),
                    FoodItemDetail(name: String(localized: "Yogurt"), calories: 59, icon: "🥣")
                ]),
                FoodCategory(title: String(localized: "Plant Proteins"), items: [
                    FoodItemDetail(name: String(localized: "Chickpeas"), calories: 164, icon: "🧆"),
                    FoodItemDetail(name: String(localized: "Tofu"), calories: 144, icon: "🧊"),
                    FoodItemDetail(name: String(localized: "Lentils"), calories: 116, icon: "🍲")
                ]),
                FoodCategory(title: String(localized: "Whole Grains"), items: [
                    FoodItemDetail(name: String(localized: "Quinoa"), calories: 120, icon: "🌾"),
                    FoodItemDetail(name: String(localized: "Oats"), calories: 68, icon: "🥣")
                ])
            ]
        ),
        DietPlan(
            key: "intermittent_fasting",
            name: String(localized: "Intermittent Fasting"),
            tagline: String(localized: "Eat whatever, but restrict when"),
            description: String(localized: "Focuses on eating windows rather than specific foods. Naturally reduces calorie intake and improves insulin sensitivity."),
            macroBreakdown: MacroBreakdown(fat: 33, protein: 33, carbs: 33),
            bestFoods: [String(localized: "Black Coffee"), String(localized: "Green Tea"), String(localized: "Lean Proteins"), String(localized: "Vegetables"), String(localized: "Healthy Fats"), String(localized: "Water")],
            contraindications: [String(localized: "Pregnant women"), String(localized: "History of eating disorders"), String(localized: "Diabetes requiring scheduled meals")],
            colorHex: 0x9575CD,
            categories: [
                FoodCategory(title: String(localized: "Fasting Drinks"), items: [
                    FoodItemDetail(name: String(localized: "Black Coffee"), calories: 2, icon: "☕"),
                    FoodItemDetail(name: String(localized: "Green Tea"), calories: 2, icon: "🍵"),
                    FoodItemDetail(name: String(localized: "Water"), calories: 0, icon: "💧")
                ]),
                FoodCategory(title: String(localized: "Break-Fast Foods"), items: [
                    FoodItemDetail(name: String(localized: "Eggs"), calories: 155, icon: "🥚"),
                    FoodItemDetail(name: String(localized: "Avocado"), calories: 160, icon: "🥑"),
                    FoodItemDetail(name: String(localized: "Bone Broth"), calories: 40, icon: "🥣")
                ]),
                FoodCategory(title: String(localized: "Satiating Meals"), items: [
                    FoodItemDetail(name: String(localized: "Chicken & Veggies"), calories: 350, icon: "🥗"),
                    FoodItemDetail(name: String(localized: "Salmon & Quinoa"), calories: 420, icon: "🍲")
                ])
            ]
        )
    ]
}

extension User {
    var activeDietPlan: DietPlan? {
        DietDataLoader.shared.diets.first(where: { $0.key == self.activeDietKey })
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
        case "paleo":
            if name.lowercased().contains("bread") || name.lowercased().contains("rice") || name.lowercased().contains("pasta") { return .avoid }
            if pPct > 20 && cPct < 20 { return .perfect }
        case "carnivore":
            if cPct > 5 { return .avoid }
            if pPct > 30 && fPct > 40 { return .perfect }
        case "pescatarian":
            if name.lowercased().contains("meat") || name.lowercased().contains("chicken") || name.lowercased().contains("beef") { return .avoid }
            if name.lowercased().contains("salmon") || name.lowercased().contains("shrimp") { return .perfect }
        default:
            return .neutral
        }

        return .neutral
    }
}
