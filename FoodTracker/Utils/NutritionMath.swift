import Foundation
import SwiftData

struct ScaledNutritionValues: Equatable {
    let weight: Double
    let calories: Int
    let protein: Double
    let fats: Double
    let carbs: Double
    let fiber: Double
    let sugar: Double
    let omega3: Double
    let calcium: Double
    let potassium: Double
    let magnesium: Double
    let iron: Double
    let vitaminC: Double
    let vitaminD: Double

    var netCarbs: Double {
        max(0.0, carbs - fiber)
    }
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
    let baseFiber: Double
    let baseSugar: Double
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
        baseFiber: Double = 0,
        baseSugar: Double = 0,
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
        self.baseFiber = baseFiber
        self.baseSugar = baseSugar
        self.baseOmega3 = baseOmega3
        self.baseCalcium = baseCalcium
        self.basePotassium = basePotassium
        self.baseMagnesium = baseMagnesium
        self.baseIron = baseIron
        self.baseVitaminC = baseVitaminC
        self.baseVitaminD = baseVitaminD
        self.weight = weight ?? (baseWeight > 0 ? baseWeight : 100.0)
    }

    init(food: FoodItem, isNewMealEntry: Bool = false) {
        self.init(
            id: isNewMealEntry ? UUID() : food.id,
            existingItem: isNewMealEntry ? nil : food,
            name: food.name,
            baseWeight: food.weight,
            baseCalories: food.calories,
            baseProtein: food.protein,
            baseFats: food.fats,
            baseCarbs: food.carbs,
            baseFiber: food.fiber,
            baseSugar: food.sugar,
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
            fiber: baseFiber,
            sugar: baseSugar,
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
    var fiber: Double { scaled.fiber }
    var sugar: Double { scaled.sugar }

    func apply(to item: FoodItem) {
        let s = scaled
        item.name = name
        item.weight = s.weight
        item.calories = s.calories
        item.protein = s.protein
        item.fats = s.fats
        item.carbs = s.carbs
        item.fiber = s.fiber
        item.sugar = s.sugar
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
            fiber: s.fiber,
            sugar: s.sugar,
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
        fiber: Double = 0,
        sugar: Double = 0,
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
            fiber: max(0, fiber * multiplier),
            sugar: max(0, sugar * multiplier),
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
                let minimumGoalCompletion = Int((Double(user.dailyCaloriesGoal) * 0.75).rounded())
                if totalCalories >= minimumGoalCompletion && totalCalories <= user.dailyCaloriesGoal {
                    calorieXP = 150
                } else if totalCalories > user.dailyCaloriesGoal && totalCalories <= user.dailyCaloriesGoal + 200 {
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
    static func claimFinishDayXP(
        for date: Date,
        now: Date = Date(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) -> Bool {
        let dayStart = calendar.startOfDay(for: date)
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        guard dayStart >= yesterdayStart && dayStart <= todayStart else { return false }

        let key = dayKey(for: date)
        var keys = defaults.stringArray(forKey: xpClaimedDateKeysKey) ?? []
        guard !keys.contains(key) else { return false }
        keys.append(key)
        defaults.set(keys, forKey: xpClaimedDateKeysKey)
        return true
    }

    /// Normalizes localized or variant meal slot titles back to canonical SwiftData keys.
    static func canonicalMealType(_ raw: String) -> String {
        DailySummary.canonicalMealSlot(raw)
    }

    struct RemainingMacros: Equatable {
        let calories: Int
        let protein: Int
        let fat: Int
        let carbs: Int
    }

    static func remainingMacros(user: User?, summary: DailySummary?) -> RemainingMacros {
        let calGoal = user?.dailyCaloriesGoal ?? 2000
        let activeBurn = summary?.activeCaloriesBurned ?? 0
        let protGoal = Int(user?.targetProtein ?? 150)
        let fatGoal = Int(user?.targetFats ?? 70)
        let carbGoal = Int(user?.targetCarbs ?? 250)

        let eatenCals = Int(summary?.totalCalories ?? 0)
        let eatenProt = Int(summary?.totalProtein ?? 0)
        let eatenFat = Int(summary?.totalFats ?? 0)
        let eatenCarbs = Int(summary?.totalCarbs ?? 0)

        return RemainingMacros(
            calories: max(0, (calGoal + activeBurn) - eatenCals),
            protein: max(0, protGoal - eatenProt),
            fat: max(0, fatGoal - eatenFat),
            carbs: max(0, carbGoal - eatenCarbs)
        )
    }

    // MARK: - Weight & Achievement Synchronization

    /// Persists a weight entry across WeightLog, DailySummary.weight, User.weight, macro goals, and HealthKit.
    @MainActor
    static func recordWeight(
        _ newWeight: Double,
        date: Date = Date(),
        for user: User?,
        in context: ModelContext,
        recalculateUserGoals: Bool = true,
        syncToHealthKit: Bool = true
    ) {
        guard newWeight > 0 else { return }

        let calendar = Calendar.current
        let existingLogs = (try? context.fetch(FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []

        let activeLog: WeightLog
        if let sameDayLog = existingLogs.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            sameDayLog.weight = newWeight
            sameDayLog.date = date
            activeLog = sameDayLog
        } else {
            let log = WeightLog(date: date, weight: newWeight)
            context.insert(log)
            activeLog = log
        }

        let summary = DailySummary.fetchOrCreate(for: date, in: context)
        summary.weight = newWeight

        if let user {
            let latestOtherDate = existingLogs.first(where: { $0.persistentModelID != activeLog.persistentModelID })?.date

            let isCurrentOrNewest = calendar.isDateInToday(date) || latestOtherDate.map { date >= $0 } ?? true
            if isCurrentOrNewest {
                user.weight = newWeight
                if recalculateUserGoals {
                    let previousCalories = user.dailyCaloriesGoal
                    user.calculateGoals()
                    user.recalculateMacrosPreservingRatios(fromPreviousCalories: previousCalories)
                }
            }
        }

        try? context.save()
        WidgetReloader.reloadAll()

        if syncToHealthKit, user?.isHealthKitEnabled == true {
            let syncDate = calendar.isDateInToday(date) ? Date() : date
            let container = context.container
            Task { @MainActor in
                if let uuid = await HealthKitManager.shared.saveBodyMass(kg: newWeight, date: syncDate) {
                    activeLog.healthKitSampleID = uuid.uuidString
                    try? container.mainContext.save()
                }
            }
        }
    }

    /// Removes a weight log entry and rolls User.weight back to the newest remaining log when present.
    @MainActor
    static func deleteWeightLog(
        _ log: WeightLog,
        for user: User?,
        in context: ModelContext
    ) {
        let logDate = log.date
        let deletedWeight = log.weight
        let deletedID = log.persistentModelID
        let sampleID = log.healthKitSampleID
        let shouldSyncHK = user?.isHealthKitEnabled == true

        let summaries = (try? context.fetch(FetchDescriptor<DailySummary>())) ?? []
        let calendar = Calendar.current
        if let summary = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: logDate) }),
           let summaryWeight = summary.weight,
           abs(summaryWeight - deletedWeight) < 0.01 {
            summary.weight = nil
        }

        context.delete(log)

        let existingLogs = (try? context.fetch(FetchDescriptor<WeightLog>(sortBy: [SortDescriptor(\.date, order: .reverse)]))) ?? []
        if let user,
           let latestRemaining = existingLogs.first(where: { $0.persistentModelID != deletedID }) {
            user.weight = latestRemaining.weight
            let previousCalories = user.dailyCaloriesGoal
            user.calculateGoals()
            user.recalculateMacrosPreservingRatios(fromPreviousCalories: previousCalories)
        }

        try? context.save()
        WidgetReloader.reloadAll()

        if shouldSyncHK {
            Task {
                await HealthKitManager.shared.deleteBodyMassSample(
                    idString: sampleID,
                    kgFallback: deletedWeight,
                    date: logDate
                )
            }
        }
    }

    /// Calculates the consecutive active logging streak ending today or yesterday.
    static func consecutiveStreak(
        from summaries: [DailySummary],
        relativeTo referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        var dayHasCalories: Set<Date> = []
        for summary in summaries where summary.totalCalories > 0 {
            dayHasCalories.insert(calendar.startOfDay(for: summary.date))
        }

        let sortedDays = dayHasCalories.sorted(by: >)
        guard let firstDay = sortedDays.first else { return 0 }

        let today = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        guard firstDay == today || firstDay == yesterday else { return 0 }

        var streak = 1
        var currentDay = firstDay
        for day in sortedDays.dropFirst() {
            if let expected = calendar.date(byAdding: .day, value: -1, to: currentDay), day == expected {
                streak += 1
                currentDay = day
            } else {
                break
            }
        }
        return streak
    }

    /// Updates user.streakDays and unlocks earned achievements without duplicating entries.
    @MainActor
    static func syncStreakAndAchievements(
        for user: User,
        summaries: [DailySummary],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) {
        let streak = consecutiveStreak(from: summaries, relativeTo: referenceDate, calendar: calendar)
        user.streakDays = streak

        var hydrationByDay: [Date: Double] = [:]
        var hasLoggedAnyCalories = false
        for summary in summaries {
            let day = calendar.startOfDay(for: summary.date)
            if summary.totalCalories > 0 {
                hasLoggedAnyCalories = true
            }
            hydrationByDay[day, default: 0] += summary.totalHydrationLiters
        }

        func unlock(_ id: String) {
            if !user.unlockedAchievements.contains(id) {
                user.unlockedAchievements.append(id)
            }
        }

        if hasLoggedAnyCalories { unlock("first_log") }
        if streak >= 3 { unlock("streak_3") }
        if streak >= 7 { unlock("streak_7") }
        if hydrationByDay.values.contains(where: { $0 >= 2.5 }) { unlock("water_pro") }
    }

    // MARK: - Unit Formatting (Metric vs Imperial)

    static func displayWeight(_ kg: Double, useMetric: Bool) -> Double {
        useMetric ? kg : kg * 2.20462262
    }

    static func kgFromDisplayWeight(_ value: Double, useMetric: Bool) -> Double {
        useMetric ? value : value / 2.20462262
    }

    static func weightUnit(useMetric: Bool) -> String {
        useMetric ? "kg" : "lb"
    }

    static func formattedWeight(_ kg: Double, useMetric: Bool) -> String {
        String(format: "%.1f %@", displayWeight(kg, useMetric: useMetric), weightUnit(useMetric: useMetric))
    }

    static func displayHeight(_ cm: Double, useMetric: Bool) -> Int {
        useMetric ? Int(cm.rounded()) : Int((cm / 2.54).rounded())
    }

    static func cmFromDisplayHeight(_ value: Double, useMetric: Bool) -> Double {
        useMetric ? value : value * 2.54
    }

    static func heightUnit(useMetric: Bool) -> String {
        useMetric ? "cm" : "in"
    }

    static func displayFluid(_ liters: Double, useMetric: Bool) -> Double {
        useMetric ? liters : liters * 33.8140227
    }

    static func fluidShortUnit(useMetric: Bool) -> String {
        useMetric ? "L" : "fl oz"
    }

    static func standardWaterGlassMl(useMetric: Bool) -> Double {
        WorkoutSyncManager.standardWaterGlassMl(useMetric: useMetric)
    }

    static func formattedHydration(liters: Double, useMetric: Bool) -> String {
        let converted = displayFluid(liters, useMetric: useMetric)
        if useMetric {
            return String(format: "%.1f %@", converted, fluidShortUnit(useMetric: true))
        } else {
            return String(format: "%.0f %@", converted, fluidShortUnit(useMetric: false))
        }
    }
}
