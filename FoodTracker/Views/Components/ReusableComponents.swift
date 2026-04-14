import SwiftUI
import UIKit // <-- Важно для HapticManager

// MARK: - Haptic Manager
class HapticManager {
    static let shared = HapticManager()
    
    private init() {} // Гарантирует, что будет только один экземпляр
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Macro Battery View
struct MacroBatteryView: View {
    let title: String; let current: Int; let total: Int; let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.caption).foregroundColor(.textGray).bold()
                Spacer()
                let textColor = color == .themeYellow ? Color.themeDarkYellow : color
                Text("\(current)/\(total)g").font(.caption.bold()).foregroundColor(textColor)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                    
                    Capsule()
                        .fill(color)
                        .frame(width: min(geometry.size.width * CGFloat(current) / CGFloat(max(total, 1)), geometry.size.width))
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 10)
        }
    }
}

struct MacroSummaryView: View {
    let protein: Double; let fats: Double; let carbs: Double
    let targetProtein: Double; let targetFats: Double; let targetCarbs: Double
    
    var body: some View {
        HStack(spacing: 15) {
            MacroBatteryView(title: "Protein", current: Int(protein), total: Int(targetProtein), color: .themePeach)
            MacroBatteryView(title: "Fats", current: Int(fats), total: Int(targetFats), color: .themeYellow)
            MacroBatteryView(title: "Carbs", current: Int(carbs), total: Int(targetCarbs), color: .drinkWater)
        }
    }
}

// MARK: - Вспомогательные компоненты для MealDetailView
struct MiniProgressView: View {
    let title: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).bold().foregroundColor(.textGray)
            ProgressView(value: progress).tint(color)
        }
    }
}

struct FoodItemRow: View {
    let name: String
    let weight: String
    let calories: Int
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.themePink.opacity(0.05)).frame(width: 44, height: 44)
                Image(systemName: "fork.knife").foregroundColor(.themePink.opacity(0.6))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline).bold()
                Text(weight).font(.caption).foregroundColor(.textGray)
            }
            Spacer()
            Text("\(calories) kcal").font(.headline).foregroundColor(.themePink)
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color.white)
    }
}

struct EmptyStateView: View {
    let imageName: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: imageName).font(.system(size: 48)).foregroundColor(.gray.opacity(0.3))
            Text(title).font(.headline).foregroundColor(.gray)
            Text(description).font(.subheadline).foregroundColor(.textGray.opacity(0.7)).multilineTextAlignment(.center).padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 🍱 Meal Cards Redesigned
struct MealCardView<Destination: View>: View {
    let title: String
    let calories: Int?
    let recommendedCalories: Int
    let ingredients: String?
    let destination: Destination
    
    var iconAndColor: (String, Color) {
        switch title {
        case "Breakfast": return ("sunrise.fill", .themeYellow)
        case "Lunch":     return ("sun.max.fill", .green)
        case "Dinner":    return ("moon.fill", .themePink)
        case "Snack":     return ("leaf.fill", .themeOrange)
        default:          return ("fork.knife", .gray)
        }
    }
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    let meta = iconAndColor
                    Image(systemName: meta.0)
                        .font(.title2)
                        .foregroundColor(meta.1)
                        .frame(width: 48, height: 48)
                        .background(meta.1.opacity(0.15))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.headline)
                        
                        if let ing = ingredients, !ing.isEmpty {
                            Text(ing).font(.caption).foregroundColor(.textGray).lineLimit(1)
                        } else if (calories ?? 0) == 0 {
                            Text("Log Meal").font(.subheadline).foregroundColor(.gray.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    if let cals = calories, cals > 0 {
                        VStack(alignment: .trailing, spacing: 6) {
                            Text("\(cals) kcal").font(.headline).foregroundColor(.themePink)
                            Image(systemName: "plus.circle.fill").foregroundColor(.themePink.opacity(0.8))
                        }
                    } else {
                        Image(systemName: "plus.circle.fill").foregroundColor(.gray.opacity(0.3)).font(.title)
                    }
                }
                
                if let cals = calories, cals > 0 {
                    ProgressView(value: min(Double(cals) / Double(max(1, recommendedCalories)), 1.0))
                        .tint(cals > recommendedCalories ? .red : iconAndColor.1)
                }
            }
            .foregroundColor(.primary)
            .ultraPremiumCardStyle()
        }
        .buttonStyle(BounceButtonStyle())
    }
}
