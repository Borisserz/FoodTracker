import SwiftUI

// MARK: - Macro Battery View
struct MacroBatteryView: View {
    let title: String
    let current: Int
    let total: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("\(current)/\(total)g")
                    .font(.caption.bold())
                    .foregroundColor(color)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.05))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(current) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Mini Progress View
struct MiniProgressView: View {
    let title: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .bold()
                .foregroundColor(.gray)
            
            ProgressView(value: progress)
                .tint(color)
        }
    }
}

// MARK: - Meal Card View
struct MealCardView<Destination: View>: View {
    let title: String
    let calories: Int?
    let isBalanced: Bool
    let destination: Destination
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    
                    if let calories = calories {
                        Text("\(calories) kcal")
                            .font(.title3.bold())
                            .foregroundColor(.themePink)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Log Meal")
                        }
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .foregroundColor(.primary)
            .premiumCardStyle()
        }
    }
}

// MARK: - Macro Summary View
struct MacroSummaryView: View {
    let protein: Double
    let fats: Double
    let carbs: Double
    let targetProtein: Double
    let targetFats: Double
    let targetCarbs: Double
    
    var body: some View {
        HStack(spacing: 15) {
            MacroBatteryView(title: "Protein", current: Int(protein), total: Int(targetProtein), color: .themePeach)
            MacroBatteryView(title: "Fats", current: Int(fats), total: Int(targetFats), color: .themeYellow)
            MacroBatteryView(title: "Carbs", current: Int(carbs), total: Int(targetCarbs), color: .themeOrange)
        }
        .premiumCardStyle()
    }
}

// MARK: - Food Item Row
struct FoodItemRow: View {
    let name: String
    let weight: String
    let calories: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .bold()
                
                Text(weight)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text("\(calories) kcal")
                .font(.headline)
                .foregroundColor(.themePink)
        }
        .padding()
        .background(Color.white)
    }
}

// MARK: - Custom Recipe Card
struct CustomRecipeCard: View {
    let title: String
    let calories: String
    let items: String
    let cookingTime: Int?
    let difficulty: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
            
            Text(items)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack(spacing: 12) {
                if let cookingTime = cookingTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text("\(cookingTime)m")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
                
                if let difficulty = difficulty {
                    Text(difficulty)
                        .font(.caption2.bold())
                        .foregroundColor(.themeOrange)
                }
                
                Spacer()
            }
            
            Spacer()
            
            Text(calories)
                .font(.headline)
                .foregroundColor(.themePink)
        }
        .padding()
        .frame(height: 140)
        .background(Color.white)
        .cornerRadius(12)
    }
}


// MARK: - Available Beverages Selector
struct BeverageSelectorView: View {
    @State private var selectedBeverage: String = "6BB8F2" // Water hex
    let onBeverageSelected: (String) -> Void
    
    let beverages = [
        ("Water", "6BB8F2", "drop.fill", 0),
        ("Coffee", "8D6E63", "cup.and.saucer.fill", 40),
        ("Milk", "CFD8DC", "mug.fill", 150),
        ("Juice", "FFB74D", "orange.fill", 110),
        ("Wine", "9C27B0", "wineglass.fill", 180)
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(beverages, id: \.0) { name, hex, icon, calories in
                    Button(action: {
                        withAnimation {
                            selectedBeverage = hex
                            onBeverageSelected(hex)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: icon)
                            Text(name)
                                .font(.subheadline)
                                .bold()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedBeverage == hex ? Color(hex: UInt(hex, radix: 16) ?? 0) : Color.gray.opacity(0.1))
                        .foregroundColor(selectedBeverage == hex ? .white : .primary)
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let imageName: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: imageName)
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.3))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBg)
    }
}

// MARK: - Haptic Manager
class HapticManager {
    static let shared = HapticManager()
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Liquid Wave Shape
struct WaveShape: Shape {
    var phase: Double
    var waveAmplitude: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: waveAmplitude))

        // Draw the sine wave on the top edge
        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / 40.0 // frequency width
            let y = sin(relativeX * .pi * 2 + phase) * waveAmplitude + waveAmplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}
