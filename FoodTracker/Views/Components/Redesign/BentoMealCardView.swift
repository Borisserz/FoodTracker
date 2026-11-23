import SwiftUI
import UIKit

// MARK: - Ultra-Premium Bento Meal Card (Apple HIG HUD Standard with Food Photography)
struct BentoMealCardView: View {
    let title: String
    let calories: Int?
    let recommendedCalories: Int
    let protein: Double?
    let fats: Double?
    let carbs: Double?
    let time: Date?
    var foodItems: [FoodItem]? = nil
    var quickAddSlot: String = "Breakfast"
    let onCardTap: () -> Void
    let onQuickAdd: () -> Void
    
    @AppStorage("useMetricSystem") private var useMetricSystem = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFloating = false
    
    private var coverImageName: String {
        switch DailySummary.canonicalMealSlot(title) {
        case "Breakfast": return "meal_cover_breakfast"
        case "Lunch": return "meal_cover_lunch"
        case "Dinner": return "meal_cover_dinner"
        case "Snack": return "meal_cover_snack"
        default: return "meal_cover_breakfast"
        }
    }
    
    private var slotMeta: (icon: String, accent: Color, secondaryAccent: Color) {
        switch DailySummary.canonicalMealSlot(title) {
        case "Breakfast":
            return ("sunrise.fill", Color(red: 1.0, green: 0.65, blue: 0.20), Color(red: 1.0, green: 0.45, blue: 0.15))
        case "Lunch":
            return ("sun.max.fill", Color(red: 0.18, green: 0.82, blue: 0.45), Color(red: 0.10, green: 0.65, blue: 0.35))
        case "Dinner":
            return ("moon.stars.fill", Color(red: 0.95, green: 0.40, blue: 0.50), Color(red: 0.75, green: 0.20, blue: 0.40))
        case "Snack":
            return ("leaf.fill", Color(red: 0.45, green: 0.75, blue: 1.0), Color(red: 0.25, green: 0.55, blue: 0.95))
        default:
            return ("fork.knife", Color.white, Color.secondary)
        }
    }
    
    private var isLogged: Bool {
        (calories ?? 0) > 0
    }
    
    var body: some View {
        let meta = slotMeta
        
        ZStack {
            // MARK: - 1. Gourmet Food Photography Background
            GeometryReader { geo in
                ZStack {
                    Image(coverImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                    
                    // Cinematic Dark Gradient Scrim for 100% Text Legibility
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.70),
                            Color.black.opacity(0.45),
                            Color.black.opacity(0.85)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            
            // MARK: - 2. Content Stack
            VStack(spacing: 14) {
                // Top Header Row
                HStack(alignment: .center, spacing: 10) {
                    // Category Slot Pill
                    HStack(spacing: 6) {
                        Image(systemName: meta.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(meta.accent)
                        
                        Text(LocalizedStringKey(title))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        if let logTime = time, isLogged {
                            Text(logTime.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(meta.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.40))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.50))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    
                    Spacer()
                    
                    // Calories & Goal HUD
                    if isLogged, let cals = calories {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(cals)")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                            Text("kcal")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.50))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(meta.accent.opacity(0.4), lineWidth: 1)
                        )
                    } else {
                        HStack(spacing: 4) {
                            Text("\(recommendedCalories)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("kcal goal")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                    }
                }
                
                // MARK: - Center Floating Action Button (Swaying / Breathing)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                    onQuickAdd()
                }) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 34, height: 34)
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(Color(red: 0.08, green: 0.09, blue: 0.11))
                        }
                        .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(LocalizedStringKey(title))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(isLogged ? String(localized: "Add more food") : String(localized: "Tap to log"))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.leading, 2)
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, 14)
                    .padding(.vertical, 7)
                    .background(
                        ZStack {
                            Color.black.opacity(0.40)
                            Rectangle().fill(.ultraThinMaterial)
                        }
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(BentoBouncyButtonStyle())
                .offset(y: isFloating ? -2.5 : 2.5)
                .rotationEffect(.degrees(isFloating ? -1.0 : 1.0))
                .animation(
                    reduceMotion
                        ? nil
                        : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                    value: isFloating
                )
                .padding(.vertical, isLogged ? 4 : 12)
                
                // MARK: - Bottom Details (Logged Chips or Macros)
                if isLogged {
                    VStack(spacing: 8) {
                        // Food Chips
                        if let items = foodItems, !items.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(Array(items.prefix(4).enumerated()), id: \.offset) { _, item in
                                        HStack(spacing: 4) {
                                            Text(item.name)
                                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                            if item.weight > 0 {
                                                Text(NutritionMath.formattedFoodWeight(item.weight, useMetric: useMetricSystem))
                                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(.white.opacity(0.75))
                                            }
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.45))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                                    }
                                    if items.count > 4 {
                                        Text("+\(items.count - 4)")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.9))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 4)
                                            .background(Color.black.opacity(0.45))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                                    }
                                }
                            }
                        }
                        
                        // Macro Badges & Progress Bar
                        HStack(spacing: 8) {
                            if let p = protein {
                                BentoMacroPill(label: "P", value: String(format: "%.0fg", p), color: Color(red: 1.0, green: 0.60, blue: 0.40))
                            }
                            if let f = fats {
                                BentoMacroPill(label: "F", value: String(format: "%.0fg", f), color: Color(red: 1.0, green: 0.82, blue: 0.25))
                            }
                            if let c = carbs {
                                BentoMacroPill(label: "C", value: String(format: "%.0fg", c), color: Color(red: 0.40, green: 0.75, blue: 1.0))
                            }
                            
                            Spacer()
                            
                            // Mini Progress Line
                            if let cals = calories {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.20))
                                            .frame(height: 5)
                                        
                                        Capsule()
                                            .fill(meta.accent)
                                            .frame(width: geo.size.width * min(Double(cals) / Double(max(recommendedCalories, 1)), 1.0), height: 5)
                                    }
                                }
                                .frame(width: 80, height: 5)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(minHeight: isLogged ? 180 : 150)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isLogged ? meta.accent.opacity(0.35) : Color.white.opacity(0.12), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            onCardTap()
        }
        .onAppear {
            guard !reduceMotion else { return }
            isFloating = true
        }
    }
}

// MARK: - Bento Macro Pill (Glassmorphic White Label)
private struct BentoMacroPill: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.45))
        .clipShape(Capsule())
        .overlay(
            Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.8)
        )
    }
}

// MARK: - Bento Bouncy Button Style
private struct BentoBouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
