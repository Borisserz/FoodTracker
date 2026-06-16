import SwiftUI
import WidgetKit
import Charts

// MARK: - Premium Styling Helpers
extension Color {
    static let widgetWaterStart = Color(red: 0.2, green: 0.8, blue: 0.99)
    static let widgetWaterEnd = Color(red: 0.0, green: 0.5, blue: 0.99)
    
    static let widgetProtein = Color(red: 1.0, green: 0.2, blue: 0.4)
    static let widgetFat = Color(red: 1.0, green: 0.6, blue: 0.0)
    static let widgetCarbs = Color(red: 0.1, green: 0.8, blue: 0.9)
}

struct WidgetPremiumBackground: View {
    var body: some View {
        ZStack {
            // Subtle mesh gradient simulation
            LinearGradient(
                colors: [Color.white.opacity(0.8), Color.white.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Abstract soft shapes
            Circle()
                .fill(Color.widgetWaterStart.opacity(0.1))
                .frame(width: 150)
                .blur(radius: 40)
                .offset(x: -50, y: -50)
            
            Circle()
                .fill(Color.widgetProtein.opacity(0.08))
                .frame(width: 150)
                .blur(radius: 40)
                .offset(x: 50, y: 50)
        }
    }
}

// MARK: - Hydration Interactive Widget
struct HydrationWidgetView: View {
    var entry: FoodTrackerEntry
    
    var body: some View {
        let goal = 2.5
        let progress = min(entry.hydrationLiters / goal, 1.0)
        
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hydration")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary.opacity(0.7))
                    Text(String(format: "%.1f L", entry.hydrationLiters))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(colors: [.widgetWaterStart, .widgetWaterEnd], startPoint: .top, endPoint: .bottom)
                    )
            }
            
            // Premium Wave Progress
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                    
                    Capsule()
                        .fill(
                            LinearGradient(colors: [.widgetWaterStart, .widgetWaterEnd], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: max(16, geo.size.width * CGFloat(progress)))
                        .shadow(color: .widgetWaterEnd.opacity(0.4), radius: 5, y: 3)
                }
            }
            .frame(height: 14)
            
            // Interactive AppIntent Button
            Button(intent: AddWaterIntent()) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("250 ml")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [.widgetWaterEnd, .widgetWaterStart], startPoint: .leading, endPoint: .trailing))
                        .shadow(color: .widgetWaterEnd.opacity(0.3), radius: 4, y: 2)
                )
            }
            .buttonStyle(.plain)
        }
        .containerBackground(for: .widget) {
            WidgetPremiumBackground()
        }
    }
}

// MARK: - Macro Rings Widget
struct MacroRingsWidgetView: View {
    var entry: FoodTrackerEntry
    
    let pGoal = 150.0
    let fGoal = 60.0
    let cGoal = 200.0
    
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Today's Intake")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
                
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(entry.totalCalories)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.primary, .primary.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                        )
                    Text("kcal")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Mini legend
                VStack(alignment: .leading, spacing: 4) {
                    LegendRow(color: .widgetProtein, title: "Protein", value: "\(entry.protein)g")
                    LegendRow(color: .widgetFat, title: "Fat", value: "\(entry.fat)g")
                    LegendRow(color: .widgetCarbs, title: "Carbs", value: "\(entry.carbs)g")
                }
            }
            
            Spacer()
            
            // Premium Concentric Rings
            ZStack {
                ConcentricRing(progress: Double(entry.protein) / pGoal, color: .widgetProtein, radius: 55, width: 12)
                ConcentricRing(progress: Double(entry.fat) / fGoal, color: .widgetFat, radius: 41, width: 12)
                ConcentricRing(progress: Double(entry.carbs) / cGoal, color: .widgetCarbs, radius: 27, width: 12)
            }
            .frame(width: 110, height: 110)
        }
        .containerBackground(for: .widget) {
            WidgetPremiumBackground()
        }
    }
}

struct LegendRow: View {
    let color: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(.primary)
        }
    }
}

struct ConcentricRing: View {
    let progress: Double
    let color: Color
    let radius: CGFloat
    let width: CGFloat
    
    var body: some View {
        let p = min(max(progress, 0), 1.0)
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: width)
                .frame(width: radius * 2, height: radius * 2)
            
            Circle()
                .trim(from: 0, to: CGFloat(p))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color.opacity(0.6), color]),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: width, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
        }
    }
}

// MARK: - Metabolic Score Widget
struct MetabolicScoreWidgetView: View {
    var entry: FoodTrackerEntry
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Metabolic")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
                Spacer()
                Image(systemName: "bolt.heart.fill")
                    .foregroundColor(scoreColor)
            }
            
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.15), lineWidth: 14)
                
                Circle()
                    .trim(from: 0, to: CGFloat(Double(entry.metabolicScore) / 100.0))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [scoreColor.opacity(0.5), scoreColor]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: scoreColor.opacity(0.4), radius: 8, x: 0, y: 2)
                
                VStack(spacing: -2) {
                    Text("\(entry.metabolicScore)")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.primary, .primary.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                        )
                    Text("SCORE")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 4)
        }
        .containerBackground(for: .widget) {
            WidgetPremiumBackground()
        }
    }
    
    var scoreColor: Color {
        if entry.metabolicScore >= 90 { return Color(red: 0.1, green: 0.8, blue: 0.3) }
        if entry.metabolicScore >= 70 { return Color(red: 1.0, green: 0.6, blue: 0.0) }
        return Color(red: 1.0, green: 0.2, blue: 0.4)
    }
}

// MARK: - Shopping List (Sticky Note) Widget
struct ShoppingListWidgetView: View {
    var entry: ShoppingListEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header (Tape effect)
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 40, height: 12)
                    .rotationEffect(.degrees(-2))
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                Spacer()
            }
            .padding(.top, -10)
            
            Text("To Buy")
                .font(.custom("Marker Felt", size: 20))
                .foregroundColor(.black.opacity(0.8))
                .padding(.bottom, 2)
            
            if entry.items.isEmpty {
                Spacer()
                Text("All done! 🎉")
                    .font(.custom("Marker Felt", size: 16))
                    .foregroundColor(.black.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entry.items, id: \.id) { item in
                        HStack(spacing: 8) {
                            Button(intent: ToggleShoppingItemIntent(itemID: item.id)) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color.black.opacity(0.5), lineWidth: 1.5)
                                        .frame(width: 14, height: 14)
                                    
                                    if item.isChecked {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            
                            HStack(spacing: 4) {
                                Text(item.name)
                                    .font(.custom("Marker Felt", size: 14))
                                    .strikethrough(item.isChecked)
                                    .foregroundColor(item.isChecked ? .black.opacity(0.4) : .black.opacity(0.8))
                                    .lineLimit(1)
                                
                                if !item.amount.isEmpty {
                                    Text(item.amount)
                                        .font(.custom("Marker Felt", size: 12))
                                        .foregroundColor(.black.opacity(0.5))
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(for: .widget) {
            ZStack {
                // Sticky Note Yellow background
                Color(red: 1.0, green: 0.95, blue: 0.6)
                
                // Subtle paper texture / gradient
                LinearGradient(
                    colors: [Color.white.opacity(0.3), Color.clear, Color.black.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
}

