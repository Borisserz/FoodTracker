import SwiftUI

struct AnalyticsQuickGlanceWidget: View {
    let summary: DailySummary
    let user: User?
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            // Calories
            GlanceCard(
                title: String(localized: "Calories"),
                icon: "flame.fill",
                color: .themeOrange,
                current: Double(summary.totalCalories),
                target: Double(user?.dailyCaloriesGoal ?? 2000),
                unit: "kcal"
            )
            
            // Protein
            GlanceCard(
                title: String(localized: "Protein"),
                icon: "figure.strengthtraining.traditional",
                color: .themePeach,
                current: summary.totalProtein,
                target: user?.targetProtein ?? 150.0,
                unit: "g"
            )
            
            // Fats
            GlanceCard(
                title: String(localized: "Fats"),
                icon: "drop.fill",
                color: .themeYellow,
                current: summary.totalFats,
                target: user?.targetFats ?? 70.0,
                unit: "g"
            )
            
            // Carbs
            GlanceCard(
                title: String(localized: "Carbs"),
                icon: "leaf.fill",
                color: .green,
                current: summary.totalCarbs,
                target: user?.targetCarbs ?? 250.0,
                unit: "g"
            )
        }
        .padding(.horizontal)
    }
}

struct GlanceCard: View {
    let title: String
    let icon: String
    let color: Color
    let current: Double
    let target: Double
    let unit: String
    
    var progress: Double {
        target > 0 ? min(current / target, 1.0) : 0
    }
    
    var percentComplete: Int {
        target > 0 ? Int((current / target) * 100) : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 14, weight: .bold))
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Spacer()
                
                Text("\(percentComplete)%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(progress >= 1.0 ? .green : color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(progress >= 1.0 ? Color.green.opacity(0.1) : color.opacity(0.08))
                    .cornerRadius(8)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(current))")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("/ \(Int(target)) \(String(localized: String.LocalizationValue(unit)))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.gray.opacity(0.7))
            }
            .padding(.top, 2)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.08))
                        .frame(height: 8)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(progress)), height: 8)
                        .shadow(color: color.opacity(0.3), radius: 3, x: 0, y: 1.5)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white)
                
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [.clear, color.opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(progress >= 1.0 ? color.opacity(0.3) : Color.white.opacity(0.5), lineWidth: progress >= 1.0 ? 1.5 : 1)
        )
        .cornerRadius(22)
        .shadow(color: color.opacity(0.12), radius: 10, x: 0, y: 5)
    }
}
