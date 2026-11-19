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
    static func sanitizedTargetWeight(for goal: String, weight: Double, targetWeight: Double) -> Double {
        let goalType = weightGoalType(for: goal)
        switch goalType {
        case "maintain":
            return weight
        case "lose":
            if targetWeight > 0 && targetWeight < weight {
                return targetWeight
            }
            return max(35.0, (weight - 4.0).rounded())
        case "gain":
            if targetWeight > weight {
                return targetWeight
            }
            return (weight + 4.0).rounded()
        default:
            return targetWeight > 0 ? targetWeight : weight
        }
    }

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
        let rawBMR = (10.0 * metrics.weight) + (6.25 * Double(metrics.height)) - Double(5 * metrics.age) + genderConstant
        let bmrDouble = max(1200.0, rawBMR)
        let bmr = Int(bmrDouble)
        let tdee = bmrDouble * activityMultiplier(for: metrics.activityLevel)

        let dailyCalories: Int
        switch metrics.goal {
        case "Lose Weight":
            dailyCalories = max(1200, Int(tdee - 450))
        case "Build Muscle":
            dailyCalories = Int(tdee + 350)
        default:
            dailyCalories = max(1200, Int(tdee))
        }

        let rawProtein = Int(metrics.weight * 2.1)
        let fatGrams = Int(Double(dailyCalories) * 0.25 / 9.0)
        let fatCalories = fatGrams * 9
        let minCarbGrams = min(100, max(0, Int(Double(dailyCalories) * 0.25 / 4.0)))
        let maxProteinGrams = max(0, (dailyCalories - fatCalories - (minCarbGrams * 4)) / 4)
        let proteinGrams = min(rawProtein, maxProteinGrams)
        let carbsGrams = max(minCarbGrams, (dailyCalories - (proteinGrams * 4) - fatCalories) / 4)

        let goalType = weightGoalType(for: metrics.goal)
        let targetWeightKg = sanitizedTargetWeight(
            for: metrics.goal,
            weight: metrics.weight,
            targetWeight: metrics.targetWeight
        )

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
            recalculateUserGoals: false,
            syncToHealthKit: false
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
