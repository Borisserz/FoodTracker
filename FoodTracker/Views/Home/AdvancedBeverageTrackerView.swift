import SwiftUI
import SwiftData

struct AdvancedBeverageTrackerView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    
    @Bindable var summary: DailySummary
    @State private var phase: Double = 0.0
    @State private var splashTriggers: [UUID] = []
    
    let dailyGoalLiters = 2.5
    
    var waterBeverages: [Beverage] {
        summary.beverages.filter { $0.name == "Water" }
    }
    
    var waterLiters: Double {
        waterBeverages.reduce(0) { $0 + $1.volumeMl } / 1000.0
    }
    
    var isGoalReached: Bool { waterLiters >= dailyGoalLiters }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hydration").font(.headline)
                    Text("Daily Goal: \(dailyGoalLiters, specifier: "%.1f")L")
                        .font(.caption)
                        .foregroundColor(.textGray)
                }
                Spacer()
                
                Text("\(waterLiters, specifier: "%.2f") L")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(isGoalReached ? .themeDarkYellow : .drinkWater)
            }
            
            // 🌊 Градиентная волна с эффектом "Golden Goal"
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.drinkWater.opacity(0.1))
                    
                    let progress = min(waterLiters / dailyGoalLiters, 1.0)
                    let fillWidth = geo.size.width * CGFloat(progress)
                    
                    // ИСПРАВЛЕНИЕ: WaveShape теперь определена ниже и доступна
                    WaveShape(phase: phase, waveAmplitude: progress > 0.02 ? 4.5 : 0)
                        .fill(
                            LinearGradient(
                                colors: isGoalReached ? [Color.themeYellow.opacity(0.7), .themeDarkYellow] : [Color.drinkWater.opacity(0.6), Color.drinkWater],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: max(0, fillWidth))
                        // ИСПРАВЛЕНИЕ: Анимация теперь вызывается корректно
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                        .shadow(color: isGoalReached ? Color.themeYellow.opacity(0.6) : Color.clear, radius: 10, x: 0, y: 0) // Свечение при 100%
                    
                    // Анимация брызг
                    ForEach(splashTriggers, id: \.self) { _ in
                        WaterSplashView()
                            .position(x: min(fillWidth, geo.size.width) - 10, y: 30)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .frame(height: 60)
            .onAppear {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    phase = .pi * 2
                }
            }
            
            // Единообразные кнопки
            HStack(spacing: 12) {
                WaterButton(title: "Glass", amount: "250ml", icon: "drop.fill") { addWater(amount: 250) }
                WaterButton(title: "Bottle", amount: "500ml", icon: "drop.fill") { addWater(amount: 500) }
            }
        }
        .ultraPremiumCardStyle()
    }
    
    private func addWater(amount: Double) {
        HapticManager.shared.impact(style: .medium)
        
        // Запуск брызга
        let newId = UUID()
        splashTriggers.append(newId)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            splashTriggers.removeAll { $0 == newId }
        }
        
        let newBeverage = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: amount)
        context.insert(newBeverage)
        summary.beverages.append(newBeverage)
        try? context.save()
        if let user = users.first, user.isHealthKitEnabled {
            HealthKitManager.shared.saveWater(liters: amount / 1000.0, date: Date())
        }
    }
}

// MARK: - Вспомогательные компоненты для AdvancedBeverageTrackerView

// ИСПРАВЛЕНИЕ: Структура WaveShape добавлена в этот файл
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

        for x in stride(from: 0, through: width, by: 2) {
            let relativeX = x / 40.0 // частота волны
            let y = sin(relativeX * .pi * 2 + phase) * waveAmplitude + waveAmplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}


struct WaterButton: View {
    let title: String
    let amount: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("+\(title)").font(.subheadline).bold()
                    Text(amount).font(.caption2).opacity(0.9)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.drinkWater)
            .cornerRadius(16)
            .shadow(color: Color.drinkWater.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

struct WaterSplashView: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.8
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 30, height: 30)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    scale = 2.5
                    opacity = 0
                }
            }
    }
}
