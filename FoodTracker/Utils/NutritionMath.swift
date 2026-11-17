import Foundation

struct ScaledNutritionValues: Equatable {
    let weight: Double
    let calories: Int
    let protein: Double
    let fats: Double
    let carbs: Double
    let omega3: Double
    let calcium: Double
    let potassium: Double
    let magnesium: Double
    let iron: Double
    let vitaminC: Double
    let vitaminD: Double
}

struct EditableFoodDraft: Identifiable {
    let id: UUID
    let existingItem: FoodItem?
    var name: String
    let baseWeight: Double
    let baseCalories: Int
    let baseProtein: Double
    let baseFats: Double
    let baseCarbs: Double
    let baseOmega3: Double
    let baseCalcium: Double
    let basePotassium: Double
    let baseMagnesium: Double
    let baseIron: Double
    let baseVitaminC: Double
    let baseVitaminD: Double
    var weight: Double

    init(
        id: UUID = UUID(),
        existingItem: FoodItem? = nil,
        name: String,
        baseWeight: Double,
        baseCalories: Int,
        baseProtein: Double,
        baseFats: Double,
        baseCarbs: Double,
        baseOmega3: Double = 0,
        baseCalcium: Double = 0,
        basePotassium: Double = 0,
        baseMagnesium: Double = 0,
        baseIron: Double = 0,
        baseVitaminC: Double = 0,
        baseVitaminD: Double = 0,
        weight: Double? = nil
    ) {
        self.id = id
        self.existingItem = existingItem
        self.name = name
        self.baseWeight = baseWeight
        self.baseCalories = baseCalories
        self.baseProtein = baseProtein
        self.baseFats = baseFats
        self.baseCarbs = baseCarbs
        self.baseOmega3 = baseOmega3
        self.baseCalcium = baseCalcium
        self.basePotassium = basePotassium
        self.baseMagnesium = baseMagnesium
        self.baseIron = baseIron
        self.baseVitaminC = baseVitaminC
        self.baseVitaminD = baseVitaminD
        self.weight = weight ?? (baseWeight > 0 ? baseWeight : 100.0)
    }

    init(food: FoodItem) {
        self.init(
            id: food.id,
            existingItem: food,
            name: food.name,
            baseWeight: food.weight,
            baseCalories: food.calories,
            baseProtein: food.protein,
            baseFats: food.fats,
            baseCarbs: food.carbs,
            baseOmega3: food.omega3,
            baseCalcium: food.calcium,
            basePotassium: food.potassium,
            baseMagnesium: food.magnesium,
            baseIron: food.iron,
            baseVitaminC: food.vitaminC,
            baseVitaminD: food.vitaminD,
            weight: food.weight > 0 ? food.weight : 100.0
        )
    }

    var scaled: ScaledNutritionValues {
        NutritionMath.scaledValues(
            baseWeight: baseWeight,
            baseCalories: baseCalories,
            baseProtein: baseProtein,
            baseFats: baseFats,
            baseCarbs: baseCarbs,
            omega3: baseOmega3,
            calcium: baseCalcium,
            potassium: basePotassium,
            magnesium: baseMagnesium,
            iron: baseIron,
            vitaminC: baseVitaminC,
            vitaminD: baseVitaminD,
            targetWeight: weight
        )
    }

    var calories: Int { scaled.calories }
    var protein: Double { scaled.protein }
    var fats: Double { scaled.fats }
    var carbs: Double { scaled.carbs }

    func apply(to item: FoodItem) {
        let s = scaled
        item.name = name
        item.weight = s.weight
        item.calories = s.calories
        item.protein = s.protein
        item.fats = s.fats
        item.carbs = s.carbs
        item.omega3 = s.omega3
        item.calcium = s.calcium
        item.potassium = s.potassium
        item.magnesium = s.magnesium
        item.iron = s.iron
        item.vitaminC = s.vitaminC
        item.vitaminD = s.vitaminD
    }

    func makeFoodItem() -> FoodItem {
        let s = scaled
        return FoodItem(
            name: name,
            weight: s.weight,
            calories: s.calories,
            protein: s.protein,
            fats: s.fats,
            carbs: s.carbs,
            omega3: s.omega3,
            calcium: s.calcium,
            potassium: s.potassium,
            magnesium: s.magnesium,
            iron: s.iron,
            vitaminC: s.vitaminC,
            vitaminD: s.vitaminD
        )
    }
}

enum NutritionMath {
    private static let xpClaimedDateKeysKey = "xpClaimedDateKeys"

    /// Parses a decimal number using either `.` or `,` separator, rejecting non-finite or <= 0 values.
    static func parsePositiveDecimal(_ raw: String) -> Double? {
        guard let value = parseNonNegativeDecimal(raw), value > 0 else { return nil }
        return value
    }

    /// Parses a decimal number using either `.` or `,` separator, rejecting non-finite or negative values.
    static func parseNonNegativeDecimal(_ raw: String) -> Double? {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !trimmed.isEmpty, let value = Double(trimmed), value.isFinite, value >= 0 else {
            return nil
        }
        return value
    }

    /// Scales nutrition values cleanly from baseline weight, preserving base macros when `baseWeight <= 0`.
    static func scaledValues(
        baseWeight: Double,
        baseCalories: Int,
        baseProtein: Double,
        baseFats: Double,
        baseCarbs: Double,
        omega3: Double = 0,
        calcium: Double = 0,
        potassium: Double = 0,
        magnesium: Double = 0,
        iron: Double = 0,
        vitaminC: Double = 0,
        vitaminD: Double = 0,
        targetWeight: Double
    ) -> ScaledNutritionValues {
        let safeTarget = targetWeight.isFinite && targetWeight > 0 ? targetWeight : max(baseWeight, 0)
        // Quick Entry / weightless items must keep multiplier 1.0 instead of scaling by 100x.
        let multiplier: Double = baseWeight > 0 ? (safeTarget / baseWeight) : 1.0

        return ScaledNutritionValues(
            weight: baseWeight > 0 ? safeTarget : max(baseWeight, 0),
            calories: max(0, Int((Double(baseCalories) * multiplier).rounded())),
            protein: max(0, baseProtein * multiplier),
            fats: max(0, baseFats * multiplier),
            carbs: max(0, baseCarbs * multiplier),
            omega3: max(0, omega3 * multiplier),
            calcium: max(0, calcium * multiplier),
            potassium: max(0, potassium * multiplier),
            magnesium: max(0, magnesium * multiplier),
            iron: max(0, iron * multiplier),
            vitaminC: max(0, vitaminC * multiplier),
            vitaminD: max(0, vitaminD * multiplier)
        )
    }

    /// Computes end-of-day XP while requiring logged calories > 0 to qualify for calorie goal XP.
    static func finishDayXP(for summary: DailySummary, user: User?) -> NutritionXPBreakdown {
        let baseXP = 50
        var proteinXP = 0
        var calorieXP = 0

        if let user = user {
            let totalProtein = Int(summary.totalProtein)
            let totalCalories = Int(summary.totalCalories)

            if totalProtein >= Int(user.targetProtein) {
                proteinXP = 100
            } else if totalProtein >= max(1, Int(user.targetProtein) - 20) {
                proteinXP = 50
            }

            if totalCalories > 0 {
                if totalCalories <= user.dailyCaloriesGoal {
                    calorieXP = 150
                } else if totalCalories <= user.dailyCaloriesGoal + 200 {
                    calorieXP = 50
                }
            }
        }

        return NutritionXPBreakdown(baseXP: baseXP, proteinGoalXP: proteinXP, calorieGoalXP: calorieXP)
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
    }

    static func hasClaimedFinishDayXP(for date: Date, defaults: UserDefaults = .standard) -> Bool {
        let keys = defaults.stringArray(forKey: xpClaimedDateKeysKey) ?? []
        return keys.contains(dayKey(for: date))
    }

    /// Marks the given calendar day as claimed and returns `true` only on the first claim for that day.
    @discardableResult
    static func claimFinishDayXP(for date: Date, defaults: UserDefaults = .standard) -> Bool {
        let key = dayKey(for: date)
        var keys = defaults.stringArray(forKey: xpClaimedDateKeysKey) ?? []
        guard !keys.contains(key) else { return false }
        keys.append(key)
        defaults.set(keys, forKey: xpClaimedDateKeysKey)
        return true
    }

    /// Normalizes localized or variant meal slot titles back to canonical SwiftData keys.
    static func canonicalMealType(_ raw: String) -> String {
        let lower = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["breakfast", "завтрак", "frühstück", "desayuno", "petit-déjeuner", "petit dejeuner", "colazione", "pequeno-almoço", "pequeno almoco"].contains(where: { lower.contains($0) }) {
            return "Breakfast"
        }
        if ["lunch", "обед", "mittagessen", "almuerzo", "comida", "déjeuner", "dejeuner", "pranzo", "almoço", "almoco"].contains(where: { lower.contains($0) }) {
            return "Lunch"
        }
        if ["dinner", "ужин", "abendessen", "cena", "dîner", "diner", "jantar"].contains(where: { lower.contains($0) }) {
            return "Dinner"
        }
        if ["snack", "перекус", "zwischenmahlzeit", "merienda", "collation", "spuntino", "lanche"].contains(where: { lower.contains($0) }) {
            return "Snack"
        }
        return "Snack"
    }

    struct RemainingMacros: Equatable {
        let calories: Int
        let protein: Int
        let fat: Int
        let carbs: Int
    }

    static func remainingMacros(user: User?, summary: DailySummary?) -> RemainingMacros {
        let calGoal = user?.dailyCaloriesGoal ?? 2000
        let protGoal = Int(user?.targetProtein ?? 150)
        let fatGoal = Int(user?.targetFats ?? 70)
        let carbGoal = Int(user?.targetCarbs ?? 250)

        let eatenCals = Int(summary?.totalCalories ?? 0)
        let eatenProt = Int(summary?.totalProtein ?? 0)
        let eatenFat = Int(summary?.totalFats ?? 0)
        let eatenCarbs = Int(summary?.totalCarbs ?? 0)

        return RemainingMacros(
            calories: max(0, calGoal - eatenCals),
            protein: max(0, protGoal - eatenProt),
            fat: max(0, fatGoal - eatenFat),
            carbs: max(0, carbGoal - eatenCarbs)
        )
    }
}
