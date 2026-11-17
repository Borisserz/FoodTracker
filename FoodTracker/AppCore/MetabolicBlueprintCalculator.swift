import Foundation
import SwiftData

/// Activity intensity levels selectable during onboarding.
enum ActivityType: String, CaseIterable {
    case none = "Пока не выбрано"
    case office = "Офисный дзен"
    case light = "Легкий тонус"
    case active = "Активный метаболизм"
    case beast = "Турбо-режим"

    var emoji: String {
        switch self {
        case .none: return "😶"
        case .office: return "👨‍💻"
        case .light: return "🚶‍♂️"
        case .active: return "⚡️"
        case .beast: return "🔥"
        }
    }

    var description: String {
        switch self {
        case .none: return ""
        case .office: return "Сидячая работа, минимум шагов"
        case .light: return "Прогулки, йога 1-2 раза в неделю"
        case .active: return "Спорт 3-4 раза, регулярное движение"
        case .beast: return "Ежедневные нагрузки, высокий расход калорий"
        }
    }
}

/// Computed daily energy and macro targets shared between onboarding preview UI and user persistence.
struct MetabolicBlueprint: Equatable {
    let bmr: Int
    let dailyCalories: Int
    let proteinGrams: Int
    let fatGrams: Int
    let carbsGrams: Int
    let weightGoalType: String
    let targetWeightKg: Double
}

enum MetabolicBlueprintCalculator {
    static func activityMultiplier(for activityLevel: ActivityType) -> Double {
        switch activityLevel {
        case .none, .office: return 1.2
        case .light: return 1.375
        case .active: return 1.55
        case .beast: return 1.725
        }
    }

    static func weightGoalType(for goal: String) -> String {
        switch goal {
        case "Lose Weight": return "lose"
        case "Build Muscle": return "gain"
        default: return "maintain"
        }
    }

    static func calculate(for metrics: OnboardingMetrics) -> MetabolicBlueprint {
        let genderConstant = metrics.gender == "Female" ? -161.0 : 5.0
        let rawBMR = Double(10 * metrics.weight) + (6.25 * Double(metrics.height)) - Double(5 * metrics.age) + genderConstant
        let bmr = max(1200, Int(rawBMR))
        let tdee = Double(bmr) * activityMultiplier(for: metrics.activityLevel)

        let dailyCalories: Int
        switch metrics.goal {
        case "Lose Weight":
            dailyCalories = max(1200, Int(tdee - 450))
        case "Build Muscle":
            dailyCalories = Int(tdee + 350)
        default:
            dailyCalories = max(1200, Int(tdee))
        }

        let proteinGrams = Int(Double(metrics.weight) * 2.1)
        let fatGrams = Int(Double(dailyCalories) * 0.25 / 9.0)
        let carbsGrams = max(100, (dailyCalories - (proteinGrams * 4) - (fatGrams * 9)) / 4)

        let goalType = weightGoalType(for: metrics.goal)
        let targetWeightKg = goalType == "maintain" ? Double(metrics.weight) : Double(metrics.targetWeight)

        return MetabolicBlueprint(
            bmr: bmr,
            dailyCalories: dailyCalories,
            proteinGrams: proteinGrams,
            fatGrams: fatGrams,
            carbsGrams: carbsGrams,
            weightGoalType: goalType,
            targetWeightKg: targetWeightKg
        )
    }
}

enum OnboardingPersistence {
    @MainActor
    static func save(metrics: OnboardingMetrics, existingUser: User?, in context: ModelContext) {
        let blueprint = MetabolicBlueprintCalculator.calculate(for: metrics)

        let targetUser: User
        if let existingUser {
            existingUser.age = metrics.age
            existingUser.height = Double(metrics.height)
            existingUser.weight = Double(metrics.weight)
            existingUser.gender = metrics.gender
            targetUser = existingUser
        } else {
            let newUser = User(
                name: "Champion",
                weight: Double(metrics.weight),
                height: Double(metrics.height),
                age: metrics.age,
                gender: metrics.gender
            )
            context.insert(newUser)
            targetUser = newUser
        }

        NutritionMath.recordWeight(
            Double(metrics.weight),
            date: Date(),
            for: targetUser,
            in: context,
            recalculateUserGoals: false
        )

        targetUser.dailyCaloriesGoal = blueprint.dailyCalories
        targetUser.targetProtein = Double(blueprint.proteinGrams)
        targetUser.targetFats = Double(blueprint.fatGrams)
        targetUser.targetCarbs = Double(blueprint.carbsGrams)
        targetUser.targetWeight = blueprint.targetWeightKg
        targetUser.weightGoalType = blueprint.weightGoalType
        targetUser.activityMultiplier = MetabolicBlueprintCalculator.activityMultiplier(for: metrics.activityLevel)

        try? context.save()
        WidgetReloader.reloadAll()
    }
}
