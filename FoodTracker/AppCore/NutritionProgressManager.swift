import Foundation

struct NutritionXPBreakdown {
    var baseXP: Int
    var proteinGoalXP: Int
    var calorieGoalXP: Int

    var totalXP: Int {
        baseXP + proteinGoalXP + calorieGoalXP
    }
}

struct NutritionProgressManager {
    static let maxLevel = 100

    let user: User
    
    private let baseXP = 1000.0
    private let multiplier = 1.2
    
    init(user: User) {
        self.user = user
    }

    func syncLevel() {
        recalculateLevel()
    }
    
    var currentTitle: String {
        switch user.level {
        case 1...4: return String(localized: "Nutrition Rookie")
        case 5...9: return String(localized: "Macro Trainee")
        case 10...19: return String(localized: "Diet Regular")
        case 20...29: return String(localized: "Dedicated Eater")
        case 30...49: return String(localized: "Nutrition Master")
        default: return String(localized: "Diet Titan")
        }
    }
    
    func cumulativeXPRequired(forLevel n: Int) -> Int {
        guard n > 1 else { return 0 }
        let clampedLevel = min(n, Self.maxLevel)
        let power = pow(multiplier, Double(clampedLevel - 1))
        let total = baseXP * (power - 1) / (multiplier - 1)
        guard total.isFinite, total >= 0, total < Double(Int.max) else { return Int.max }
        return Int(total.rounded())
    }
    
    var xpToNextLevel: Int {
        return cumulativeXPRequired(forLevel: user.level + 1)
    }
    
    var currentXPInLevel: Int {
        let startOfLevelXP = cumulativeXPRequired(forLevel: user.level)
        let val = user.totalXP - startOfLevelXP
        return max(val, 0)
    }
    
    var progressPercentage: Double {
        if user.level >= Self.maxLevel { return 1.0 }
        let startOfLevelXP = cumulativeXPRequired(forLevel: user.level)
        let nextLevelXP = cumulativeXPRequired(forLevel: user.level + 1)
        
        let xpNeededForThisLevel = Double(nextLevelXP - startOfLevelXP)
        let xpGainedInThisLevel = Double(user.totalXP - startOfLevelXP)
        
        if xpNeededForThisLevel <= 0 { return 0 }
        
        let progress = xpGainedInThisLevel / xpNeededForThisLevel
        return min(max(progress, 0.0), 1.0)
    }
    
    func addXP(from breakdown: NutritionXPBreakdown) {
        user.totalXP += breakdown.totalXP
        recalculateLevel()
    }
    
    private func recalculateLevel() {
        var calculatedLevel = 1
        while calculatedLevel < Self.maxLevel && user.totalXP >= cumulativeXPRequired(forLevel: calculatedLevel + 1) {
            calculatedLevel += 1
        }
        
        if user.level != calculatedLevel {
            user.level = calculatedLevel
        }
    }
}
