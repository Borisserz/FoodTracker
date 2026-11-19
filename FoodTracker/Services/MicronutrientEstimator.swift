import Foundation

struct MicronutrientProfile: Equatable {
    let omega3: Double      // g
    let calcium: Double     // mg
    let potassium: Double   // mg
    let magnesium: Double   // mg
    let iron: Double        // mg
    let vitaminC: Double    // mg
    let vitaminD: Double    // mcg

    static let zero = MicronutrientProfile(
        omega3: 0, calcium: 0, potassium: 0, magnesium: 0, iron: 0, vitaminC: 0, vitaminD: 0
    )

    var isAllZero: Bool {
        omega3 <= 0 && calcium <= 0 && potassium <= 0 && magnesium <= 0 && iron <= 0 && vitaminC <= 0 && vitaminD <= 0
    }

    func scaled(by factor: Double) -> MicronutrientProfile {
        guard factor.isFinite, factor > 0 else { return .zero }
        return MicronutrientProfile(
            omega3: (omega3 * factor * 100).rounded() / 100,
            calcium: (calcium * factor * 10).rounded() / 10,
            potassium: (potassium * factor * 10).rounded() / 10,
            magnesium: (magnesium * factor * 10).rounded() / 10,
            iron: (iron * factor * 100).rounded() / 100,
            vitaminC: (vitaminC * factor * 10).rounded() / 10,
            vitaminD: (vitaminD * factor * 100).rounded() / 100
        )
    }
}

/// Estimates realistic per-portion micronutrients (`omega3` g, `calcium`/`potassium`/`magnesium`/`iron`/`vitaminC` mg, `vitaminD` mcg)
/// when upstream APIs or bundled local catalogs omit micronutrient columns.
enum MicronutrientEstimator {
    static func estimate(
        id: String = "",
        name: String,
        category: String = "",
        calories: Int,
        protein: Double,
        fat: Double,
        carbs: Double,
        weight: Double = 100.0
    ) -> MicronutrientProfile {
        let key = "\(id) \(name)".lowercased()
        let cat = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Pure water / zero-calorie plain drinks have no micronutrients.
        if calories <= 2 && protein <= 0.1 && fat <= 0.1 && carbs <= 0.2 {
            return .zero
        }
        if key.contains("water") || key.contains("вода") || key.contains("wasser") || key.contains("agua") || key.contains("eau") || key.contains("acqua") || key.contains("água") {
            if calories <= 5 { return .zero }
        }

        let per100g = per100gProfile(key: key, category: cat, protein: protein, fat: fat, carbs: carbs)
        let safeWeight = weight > 0 ? weight : 100.0
        return per100g.scaled(by: safeWeight / 100.0)
    }

    private static func per100gProfile(
        key: String,
        category: String,
        protein: Double,
        fat: Double,
        carbs: Double
    ) -> MicronutrientProfile {
        // High-precision food keyword matches first
        if containsAny(key, ["salmon", "лосос", "семг", "форел", "trout", "mackerel", "скумбр", "sardine", "сардин", "herring", "сельд", "lachs", "salmón", "saumon", "salmone", "salmão"]) {
            return MicronutrientProfile(omega3: 2.1, calcium: 15, potassium: 380, magnesium: 30, iron: 0.8, vitaminC: 1.0, vitaminD: 11.0)
        }
        if containsAny(key, ["tuna", "тунец", "cod", "треск", "tilapia", "shrimp", "кревет", "fish", "рыб", "fisch", "pescado", "poisson", "pesce", "peixe"]) || category == "fish" {
            return MicronutrientProfile(omega3: 0.6, calcium: 20, potassium: 310, magnesium: 32, iron: 0.9, vitaminC: 0.5, vitaminD: 3.5)
        }
        if containsAny(key, ["chia", "flax", "лен", "льнян", "walnut", "грецк"]) {
            return MicronutrientProfile(omega3: 6.5, calcium: 220, potassium: 420, magnesium: 240, iron: 4.5, vitaminC: 1.0, vitaminD: 0)
        }
        if containsAny(key, ["spinach", "шпинат", "kale", "кейл", "broccoli", "броккол", "arugula", "рукол"]) {
            return MicronutrientProfile(omega3: 0.1, calcium: 85, potassium: 420, magnesium: 62, iron: 2.4, vitaminC: 55, vitaminD: 0)
        }
        if containsAny(key, ["orange", "апельсин", "lemon", "лимон", "kiwi", "киви", "strawberry", "клубник", "berry", "ягод", "pepper", "перец", "citrus"]) {
            return MicronutrientProfile(omega3: 0.03, calcium: 30, potassium: 210, magnesium: 14, iron: 0.4, vitaminC: 65, vitaminD: 0)
        }
        if containsAny(key, ["avocado", "авокадо"]) {
            return MicronutrientProfile(omega3: 0.11, calcium: 12, potassium: 485, magnesium: 29, iron: 0.55, vitaminC: 10, vitaminD: 0)
        }
        if containsAny(key, ["banana", "банан", "potato", "картоф"]) {
            return MicronutrientProfile(omega3: 0.02, calcium: 8, potassium: 390, magnesium: 27, iron: 0.5, vitaminC: 12, vitaminD: 0)
        }
        if containsAny(key, ["liver", "печень", "beef", "говядин", "steak", "стейк", "lamb", "баранин", "pork", "свинин"]) {
            return MicronutrientProfile(omega3: 0.08, calcium: 12, potassium: 320, magnesium: 22, iron: 2.8, vitaminC: 0, vitaminD: 0.4)
        }
        if containsAny(key, ["egg", "яйц", "яич", "omelet", "омлет", "ei", "huevo", "oeuf", "uovo", "ovo"]) || category == "eggs" {
            return MicronutrientProfile(omega3: 0.12, calcium: 56, potassium: 138, magnesium: 12, iron: 1.8, vitaminC: 0, vitaminD: 2.0)
        }
        if containsAny(key, ["milk", "молок", "yogurt", "йогурт", "kefir", "кефир", "cottage", "творог", "cheese", "сыр", "milch", "leche", "lait", "latte", "leite"]) || category == "dairy" {
            return MicronutrientProfile(omega3: 0.04, calcium: 160, potassium: 155, magnesium: 14, iron: 0.15, vitaminC: 0.5, vitaminD: 1.1)
        }
        if containsAny(key, ["oat", "овся", "quinoa", "киноа", "buckwheat", "греч", "lentil", "чечевиц", "bean", "фасол", "chickpea", "нут"]) || category == "legumes" {
            return MicronutrientProfile(omega3: 0.08, calcium: 38, potassium: 340, magnesium: 95, iron: 3.1, vitaminC: 1.0, vitaminD: 0)
        }
        if containsAny(key, ["almond", "миндал", "cashew", "кешью", "peanut", "арахис", "seed", "семеч", "nut", "орех"]) || category == "nuts" {
            return MicronutrientProfile(omega3: 0.25, calcium: 110, potassium: 580, magnesium: 210, iron: 3.2, vitaminC: 0.5, vitaminD: 0)
        }

        // Category fallbacks
        switch category {
        case "meat":
            return MicronutrientProfile(omega3: 0.06, calcium: 11, potassium: 310, magnesium: 24, iron: 1.4, vitaminC: 0, vitaminD: 0.2)
        case "vegetables":
            return MicronutrientProfile(omega3: 0.04, calcium: 35, potassium: 280, magnesium: 22, iron: 0.9, vitaminC: 24, vitaminD: 0)
        case "fruits":
            return MicronutrientProfile(omega3: 0.02, calcium: 18, potassium: 185, magnesium: 12, iron: 0.3, vitaminC: 28, vitaminD: 0)
        case "grains", "cereals", "bread":
            return MicronutrientProfile(omega3: 0.03, calcium: 28, potassium: 160, magnesium: 42, iron: 1.8, vitaminC: 0, vitaminD: 0)
        case "fats":
            return MicronutrientProfile(omega3: fat > 20 ? 0.5 : 0.1, calcium: 4, potassium: 10, magnesium: 2, iron: 0.1, vitaminC: 0, vitaminD: 0.2)
        case "meals", "ready", "fast_food":
            return MicronutrientProfile(omega3: 0.08, calcium: 55, potassium: 220, magnesium: 24, iron: 1.3, vitaminC: 5, vitaminD: 0.3)
        case "snacks", "sweets":
            return MicronutrientProfile(omega3: 0.02, calcium: 32, potassium: 140, magnesium: 28, iron: 1.1, vitaminC: 0.5, vitaminD: 0)
        case "beverages", "drinks":
            return MicronutrientProfile(omega3: 0, calcium: 15, potassium: 95, magnesium: 8, iron: 0.1, vitaminC: carbs > 5 ? 12 : 0, vitaminD: 0)
        case "supplements":
            return MicronutrientProfile(omega3: fat > 5 ? 0.4 : 0, calcium: 80, potassium: 120, magnesium: 25, iron: 1.0, vitaminC: 5, vitaminD: 1.0)
        default:
            // Generic macro-informed baseline for meals/unknown items
            return MicronutrientProfile(
                omega3: fat > 10 ? 0.1 : 0.02,
                calcium: protein > 10 ? 35 : 15,
                potassium: 160,
                magnesium: 20,
                iron: protein > 10 ? 1.1 : 0.5,
                vitaminC: carbs > 15 ? 4.0 : 1.0,
                vitaminD: protein > 15 ? 0.3 : 0.0
            )
        }
    }

    private static func containsAny(_ text: String, _ terms: [String]) -> Bool {
        terms.contains { text.contains($0) }
    }
}
