import SwiftUI
import UIKit

// MARK: - Ultra-Premium Bento Meal Card
struct BentoMealCardView: View {
    let title: String
    let calories: Int?
    let recommendedCalories: Int
    let protein: Double?
    let fats: Double?
    let carbs: Double?
    let time: Date?
    let onCardTap: () -> Void
    let onQuickAdd: () -> Void
    
    private var iconAndColor: (String, Color, Color) {
        switch title {
        case "Breakfast", "Завтрак":
            return ("cup.and.saucer.fill", Color.themePeach, Color(red: 1.0, green: 0.58, blue: 0.0))
        case "Lunch", "Обед":
            return ("sun.max.fill", Color.green, Color(red: 0.18, green: 0.82, blue: 0.35))
        case "Dinner", "Ужин":
            return ("moon.stars.fill", Color.themePink, Color(red: 0.95, green: 0.25, blue: 0.55))
        case "Snack", "Перекус":
            return ("leaf.fill", Color.themeOrange, Color(red: 1.0, green: 0.45, blue: 0.15))
        default:
            return ("fork.knife", Color.blue, Color.cyan)
        }
    }
    
    private var isLogged: Bool {
        (calories ?? 0) > 0
    }
    
    var body: some View {
        let meta = iconAndColor
        
        VStack(spacing: 14) {
            // Main Top Row
            HStack(spacing: 14) {
                // Circular Glowing Icon / Thumbnail
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [meta.1.opacity(0.22), meta.2.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: meta.0)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(meta.1)
                }
                
                // Meal Title & Time Pill
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)
                        
                        if let logTime = time, isLogged {
                            Text(logTime.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(meta.1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(meta.1.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    
                    if isLogged, let cals = calories {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(cals)")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.primary)
                            
                            Text("ккал")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.secondary)
                        }
                    } else {
                        Text("Не заполнено")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Target info
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Цель")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.8))
                    
                    Text("\(recommendedCalories)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                    
                    Text("ккал")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .padding(.trailing, 6)
                
                // Quick Add + Button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.prepare()
                    generator.impactOccurred()
                    onQuickAdd()
                }) {
                    ZStack {
                        Circle()
                            .fill(meta.1.opacity(0.14))
                            .frame(width: 38, height: 38)
                        
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(meta.1)
                    }
                }
                .buttonStyle(BentoBouncyButtonStyle())
            }
            
            // Macro Pills Row (when food is logged)
            if isLogged {
                HStack(spacing: 8) {
                    BentoMacroPill(
                        label: "Белки",
                        value: "\(Int(protein ?? 0))г",
                        color: Color.themePeach
                    )
                    
                    BentoMacroPill(
                        label: "Жиры",
                        value: "\(Int(fats ?? 0))г",
                        color: Color.themeYellow
                    )
                    
                    BentoMacroPill(
                        label: "Углеводы",
                        value: "\(Int(carbs ?? 0))г",
                        color: Color.drinkWater
                    )
                    
                    Spacer()
                }
                
                // Progress Bar
                if let cals = calories {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(meta.1.opacity(0.12))
                                .frame(height: 5)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [meta.1, meta.2],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * min(Double(cals) / Double(max(recommendedCalories, 1)), 1.0), height: 5)
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isLogged ? meta.1.opacity(0.28) : Color.primary.opacity(0.06), lineWidth: 1.2)
        )
        .shadow(color: isLogged ? meta.1.opacity(0.08) : Color.black.opacity(0.03), radius: 12, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            onCardTap()
        }
    }
}

// MARK: - Bento Macro Pill
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
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.secondary)
            
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }
}

// MARK: - Bento Bouncy Button Style
private struct BentoBouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
