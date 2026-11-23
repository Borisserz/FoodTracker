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

    private var slotMeta: (icon: String, accent: Color) {
        switch DailySummary.canonicalMealSlot(title) {
        case "Breakfast":
            return ("sunrise.fill", Color(red: 1.0, green: 0.65, blue: 0.20))
        case "Lunch":
            return ("sun.max.fill", Color(red: 0.18, green: 0.82, blue: 0.45))
        case "Dinner":
            return ("moon.stars.fill", Color(red: 0.95, green: 0.40, blue: 0.50))
        case "Snack":
            return ("leaf.fill", Color(red: 0.45, green: 0.75, blue: 1.0))
        default:
            return ("fork.knife", Color.white)
        }
    }

    private var isLogged: Bool {
        (calories ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 14) {
            headerButton
            quickAddButton
            if isLogged {
                loggedDetails
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: isLogged ? 180 : 150, alignment: .top)
        .background { coverBackground }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isLogged ? slotMeta.accent.opacity(0.35) : Color.white.opacity(0.22), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)
        .onAppear {
            guard !reduceMotion, !isFloating else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }

    private var coverBackground: some View {
        ZStack {
            Image(coverImageName)
                .resizable()
                .scaledToFill()
            LinearGradient(
                colors: [
                    Color.black.opacity(0.62),
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.78)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var headerButton: some View {
        Button(action: onCardTap) {
            HStack(alignment: .center, spacing: 10) {
                slotPill
                Spacer()
                caloriePill
            }
        }
        .buttonStyle(.plain)
    }

    private var slotPill: some View {
        HStack(spacing: 6) {
            Image(systemName: slotMeta.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(slotMeta.accent)
            Text(LocalizedStringKey(title))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            if let logTime = time, isLogged {
                Text(logTime.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(slotMeta.accent)
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
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
    }

    @ViewBuilder
    private var caloriePill: some View {
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
            .overlay(Capsule().strokeBorder(slotMeta.accent.opacity(0.4), lineWidth: 1))
        } else {
            HStack(spacing: 4) {
                Text("\(recommendedCalories)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                Text(String(localized: "kcal goal"))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    private var quickAddButton: some View {
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

                Text(isLogged ? String(localized: "Add more food") : String(localized: "Tap to log"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.62))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1.2))
        }
        .buttonStyle(BentoBouncyButtonStyle())
        .offset(y: reduceMotion ? 0 : (isFloating ? -2 : 2))
        .padding(.vertical, isLogged ? 4 : 12)
        .accessibilityLabel(String(localized: "Add food"))
        .accessibilityIdentifier("meal_card_quick_add_\(quickAddSlot)")
    }

    private var loggedDetails: some View {
        VStack(spacing: 8) {
            if let items = foodItems, !items.isEmpty {
                foodChips(items)
            }
            macroRow
        }
        .onTapGesture {
            onCardTap()
        }
    }

    private func foodChips(_ items: [FoodItem]) -> some View {
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

    private var macroRow: some View {
        HStack(spacing: 8) {
            if let protein {
                BentoMacroPill(label: "P", value: String(format: "%.0fg", protein), color: Color(red: 1.0, green: 0.60, blue: 0.40))
            }
            if let fats {
                BentoMacroPill(label: "F", value: String(format: "%.0fg", fats), color: Color(red: 1.0, green: 0.82, blue: 0.25))
            }
            if let carbs {
                BentoMacroPill(label: "C", value: String(format: "%.0fg", carbs), color: Color(red: 0.40, green: 0.75, blue: 1.0))
            }
            Spacer()
            if let calories {
                progressLine(calories: calories)
            }
        }
    }

    private func progressLine(calories: Int) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.20))
                    .frame(height: 5)
                Capsule()
                    .fill(slotMeta.accent)
                    .frame(width: geo.size.width * min(Double(calories) / Double(max(recommendedCalories, 1)), 1.0), height: 5)
            }
        }
        .frame(width: 80, height: 5)
    }
}

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
        .overlay(Capsule().strokeBorder(color.opacity(0.35), lineWidth: 0.8))
    }
}

private struct BentoBouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
