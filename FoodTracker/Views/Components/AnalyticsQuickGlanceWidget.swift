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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 14, weight: .bold))
                }
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(current))")
                    .font(.title3.weight(.bold))
                    .foregroundColor(.primary)
                
                Text("/ \(Int(target)) \(unit)")
                    .font(.caption)
                    .foregroundColor(.textGray)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: color.opacity(0.1), radius: 8, y: 4)
    }
}
