import Foundation

/// Normalizes localized recipe tags across all supported app languages to canonical English keys.
enum RecipeTagCatalog {
    static let allCanonicalTags: [String] = [
        "Breakfast",
        "Lunch",
        "Dinner",
        "Snack",
        "Smoothie",
        "Quickly Prepared",
        "On the Go",
        "Few Ingredients",
        "Baking",
        "Easy",
        "Vegetarian",
        "Vegan",
        "Low Carb",
        "High Protein",
        "Ketogenic"
    ]

    private static let aliasToCanonical: [String: String] = [
        // Breakfast
        "breakfast": "Breakfast",
        "завтрак": "Breakfast",
        "frühstück": "Breakfast",
        "desayuno": "Breakfast",
        "petit-déjeuner": "Breakfast",
        "colazione": "Breakfast",
        "café da manhã": "Breakfast",

        // Lunch
        "lunch": "Lunch",
        "обед": "Lunch",
        "mittagessen": "Lunch",
        "almuerzo": "Lunch",
        "déjeuner": "Lunch",
        "pranzo": "Lunch",
        "almoço": "Lunch",

        // Dinner
        "dinner": "Dinner",
        "ужин": "Dinner",
        "abendessen": "Dinner",
        "cena": "Dinner",
        "dîner": "Dinner",
        "jantar": "Dinner",

        // Snack
        "snack": "Snack",
        "закуска": "Snack",
        "bocadillo": "Snack",
        "collation": "Snack",
        "spuntino": "Snack",
        "lanche": "Snack",

        // Smoothie
        "smoothie": "Smoothie",
        "smoothies": "Smoothie",
        "смузи": "Smoothie",
        "zalamero": "Smoothie",
        "frullato": "Smoothie",
        "batido": "Smoothie",

        // Quickly Prepared
        "quickly prepared": "Quickly Prepared",
        "быстро готовится": "Quickly Prepared",
        "schnell zubereitet": "Quickly Prepared",
        "preparado rápidamente": "Quickly Prepared",
        "rapidement préparé": "Quickly Prepared",
        "preparato rapidamente": "Quickly Prepared",
        "preparado rapidamente": "Quickly Prepared",

        // On the Go
        "on the go": "On the Go",
        "в пути": "On the Go",
        "unterwegs": "On the Go",
        "muy activo": "On the Go",
        "en déplacement": "On the Go",
        "in movimento": "On the Go",
        "em movimento": "On the Go",

        // Few Ingredients
        "few ingredients": "Few Ingredients",
        "немного ингредиентов": "Few Ingredients",
        "wenige zutaten": "Few Ingredients",
        "pocos ingredientes": "Few Ingredients",
        "peu d'ingrédients": "Few Ingredients",
        "pochi ingredienti": "Few Ingredients",
        "poucos ingredientes": "Few Ingredients",

        // Baking
        "baking": "Baking",
        "выпечка": "Baking",
        "backen": "Baking",
        "hornada": "Baking",
        "pâtisserie": "Baking",
        "cottura al forno": "Baking",
        "cozimento": "Baking",

        // Easy
        "easy": "Easy",
        "легкий": "Easy",
        "лёгкий": "Easy",
        "einfach": "Easy",
        "fácil": "Easy",
        "facile": "Easy",

        // Vegetarian
        "vegetarian": "Vegetarian",
        "вегетарианец": "Vegetarian",
        "vegetarier": "Vegetarian",
        "vegetariano": "Vegetarian",
        "végétarien": "Vegetarian",

        // Vegan
        "vegan": "Vegan",
        "веган": "Vegan",
        "vegano": "Vegan",
        "végétalien": "Vegan",

        // Low Carb
        "low carb": "Low Carb",
        "низкоуглеводный": "Low Carb",
        "bajo en carbohidratos": "Low Carb",
        "faible teneur en glucides": "Low Carb",
        "basso contenuto di carboidrati": "Low Carb",
        "baixo teor de carboidratos": "Low Carb",

        // High Protein
        "high protein": "High Protein",
        "высокое содержание белка": "High Protein",
        "hoher proteingehalt": "High Protein",
        "alta proteína": "High Protein",
        "riche en protéines": "High Protein",
        "alto contenuto proteico": "High Protein",

        // Ketogenic
        "ketogenic": "Ketogenic",
        "кетогенный": "Ketogenic",
        "ketogen": "Ketogenic",
        "cetogénico": "Ketogenic",
        "cétogène": "Ketogenic",
        "chetogenico": "Ketogenic",
        "cetogênico": "Ketogenic"
    ]

    static func canonicalTag(for rawTag: String) -> String? {
        let normalized = rawTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return aliasToCanonical[normalized]
    }

    static func canonicalTags(for rawTags: [String]) -> Set<String> {
        Set(rawTags.compactMap { canonicalTag(for: $0) })
    }
}

struct ChefDiscoverSections {
    let highProtein: [PremiumRecipe]
    let ketoLowCarb: [PremiumRecipe]
    let quickEasy: [PremiumRecipe]
    let plantBased: [PremiumRecipe]
    let chefsSpecials: [PremiumRecipe]

    static func partition(_ recipes: [PremiumRecipe]) -> ChefDiscoverSections {
        var highProtein: [PremiumRecipe] = []
        var ketoLowCarb: [PremiumRecipe] = []
        var quickEasy: [PremiumRecipe] = []
        var plantBased: [PremiumRecipe] = []
        var chefsSpecials: [PremiumRecipe] = []

        for recipe in recipes {
            let tags = RecipeTagCatalog.canonicalTags(for: recipe.tags)
            if tags.contains("High Protein") {
                highProtein.append(recipe)
            } else if tags.contains("Low Carb") || tags.contains("Ketogenic") {
                ketoLowCarb.append(recipe)
            } else if tags.contains("Quickly Prepared") || tags.contains("Easy") {
                quickEasy.append(recipe)
            } else if tags.contains("Vegan") || tags.contains("Vegetarian") {
                plantBased.append(recipe)
            } else if chefsSpecials.count < 6 {
                chefsSpecials.append(recipe)
            }
        }
        return ChefDiscoverSections(
            highProtein: highProtein,
            ketoLowCarb: ketoLowCarb,
            quickEasy: quickEasy,
            plantBased: plantBased,
            chefsSpecials: chefsSpecials
        )
    }

    static func filter(_ recipes: [PremiumRecipe], matchingAnyCanonicalTags canonicalTags: [String]) -> [PremiumRecipe] {
        let targets = Set(canonicalTags)
        return recipes.filter { !RecipeTagCatalog.canonicalTags(for: $0.tags).isDisjoint(with: targets) }
    }
}
