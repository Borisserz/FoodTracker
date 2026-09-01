import SwiftUI
import Charts

// MARK: - Metabolic TDEE & Goal Archetype Card View
struct MetabolicTDEEGaugeView: View {
    @Bindable var user: User
    let currentWeight: Double
    let targetWeight: Double?
    
    @State private var selectedArchetype: GoalArchetype = .cut
    
    enum GoalArchetype: String, CaseIterable, Identifiable {
        case cut = "Cut"
        case leanBulk = "Lean Bulk"
        case longevity = "Longevity"
        
        var id: String { rawValue }
        
        var localizedTitle: String {
            switch self {
            case .cut: return "Сушка / Cut"
            case .leanBulk: return "Набор / Bulk"
            case .longevity: return "Баланс"
            }
        }
        
        var icon: String {
            switch self {
            case .cut: return "flame.fill"
            case .leanBulk: return "dumbbell.fill"
            case .longevity: return "heart.circle.fill"
            }
        }
        
        var subtitle: String {
            switch self {
            case .cut: return "Дефицит -300 ккал"
            case .leanBulk: return "Профицит +250 ккал"
            case .longevity: return "Поддержание"
            }
        }
        
        var color: Color {
            switch self {
            case .cut: return Color.cyan
            case .leanBulk: return Color.green
            case .longevity: return Color.themePink
            }
        }
    }
    
    private var tdeeValue: Int {
        // Base Mifflin-St Jeor TDEE estimate
        let bmr: Double
        let weight = currentWeight > 0 ? currentWeight : 75.0
        let height = user.height > 0 ? user.height : 178.0
        let age = user.age > 0 ? Double(user.age) : 28.0
        
        if user.gender == "Female" {
            bmr = 10 * weight + 6.25 * height - 5 * age - 161
        } else {
            bmr = 10 * weight + 6.25 * height - 5 * age + 5
        }
        return Int(bmr * 1.45) // moderate activity factor
    }
    
    private var targetCalorieRecommendation: Int {
        switch selectedArchetype {
        case .cut: return max(1200, tdeeValue - 350)
        case .leanBulk: return tdeeValue + 250
        case .longevity: return tdeeValue
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("МЕТАБОЛИЧЕСКИЙ ДВИЖОК")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(selectedArchetype.color)
                    Text("Целевая стратегия")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                }
                Spacer()
            }
            
            // Goal Archetypes Grid
            HStack(spacing: 10) {
                ForEach(GoalArchetype.allCases) { archetype in
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.prepare()
                        generator.impactOccurred()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            selectedArchetype = archetype
                            user.weightGoalType = archetype == .cut ? "lose" : (archetype == .leanBulk ? "gain" : "maintain")
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(archetype.color.opacity(0.18))
                                    .frame(width: 32, height: 32)
                                Image(systemName: archetype.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(archetype.color)
                            }
                            
                            Text(archetype.localizedTitle)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.primary)
                            
                            Text(archetype.subtitle)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(selectedArchetype == archetype ? archetype.color.opacity(0.12) : Color(UIColor.tertiarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(selectedArchetype == archetype ? archetype.color : Color.clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // TDEE & Deficit Gauge Display
            VStack(spacing: 12) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Базовый расход (TDEE)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(tdeeValue)")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.primary)
                            Text("ккал/день")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Рекомендация")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(selectedArchetype.color)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("\(targetCalorieRecommendation)")
                                .font(.system(size: 28, weight: .heavy, design: .rounded))
                                .foregroundStyle(selectedArchetype.color)
                            Text("ккал")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(selectedArchetype.color)
                        }
                    }
                }
                
                // Visual Gauge Bar
                GeometryReader { geo in
                    let width = geo.size.width
                    let ratio = min(max(Double(targetCalorieRecommendation) / Double(max(tdeeValue + 500, 1)), 0.1), 1.0)
                    
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [selectedArchetype.color.opacity(0.7), selectedArchetype.color],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width * CGFloat(ratio), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(selectedArchetype.color.opacity(0.25), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 15, y: 6)
    }
}
