import SwiftUI
import SwiftData
import UIKit

// MARK: - Ultra-Premium Glass Hydration Flask Widget
struct HydrationFlaskCardView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    
    @Bindable var summary: DailySummary
    
    let dailyGoalLiters: Double = 2.5
    
    init(summary: DailySummary) {
        self.summary = summary
    }
    
    private var waterBeverages: [Beverage] {
        summary.beverages.filter { $0.name == "Water" }.sorted { $0.date < $1.date }
    }
    
    private var waterLiters: Double {
        waterBeverages.reduce(0) { $0 + $1.volumeMl } / 1000.0
    }
    
    private var progress: Double {
        min(max(waterLiters / dailyGoalLiters, 0.0), 1.0)
    }
    
    private var isGoalReached: Bool {
        waterLiters >= dailyGoalLiters
    }
    
    var body: some View {
        VStack(spacing: 18) {
            // Header Row
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "drop.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.cyan)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ГИДРАТАЦИЯ")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.cyan)
                        Text("Баланс воды")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)
                    }
                }
                
                Spacer()
                
                // Progress Percent Pill
                HStack(spacing: 4) {
                    if isGoalReached {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.green)
                    }
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(isGoalReached ? Color.green : Color.cyan)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isGoalReached ? Color.green.opacity(0.12) : Color.cyan.opacity(0.12))
                .clipShape(Capsule())
            }
            
            // MARK: 🧪 3D Glass Flask with Wave Simulation & Metrics
            ZStack(alignment: .bottom) {
                // Flask Outer Glass Body Container
                FlaskGlassContainer(fillRatio: progress)
                    .frame(height: 220)
                
                // Metrics Overlay etched over the flask
                HStack(alignment: .bottom) {
                    // Metric Markings on the left of flask
                    VStack(alignment: .leading, spacing: 0) {
                        FlaskTickMark(label: "2.5L", isFilled: progress >= 1.0)
                        Spacer()
                        FlaskTickMark(label: "2.0L", isFilled: progress >= 0.8)
                        Spacer()
                        FlaskTickMark(label: "1.5L", isFilled: progress >= 0.6)
                        Spacer()
                        FlaskTickMark(label: "1.0L", isFilled: progress >= 0.4)
                        Spacer()
                        FlaskTickMark(label: "0.5L", isFilled: progress >= 0.2)
                    }
                    .frame(width: 50, height: 160)
                    .padding(.leading, 24)
                    .padding(.bottom, 20)
                    
                    Spacer()
                    
                    // Main Liter Readout in Center-Right
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.2f", waterLiters))
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.primary)
                                .contentTransition(.numericText(value: waterLiters))
                            
                            Text("Л")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.cyan)
                        }
                        
                        Text("из \(dailyGoalLiters, specifier: "%.1f") Л цели")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 24)
                }
            }
            .frame(height: 220)
            
            // MARK: ⚡ Clean Modern Preset Add Buttons
            HStack(spacing: 10) {
                // Glass +250ml Button
                FlaskActionButton(
                    icon: "drop.fill",
                    title: "+250 мл",
                    color: Color.cyan
                ) {
                    addWater(ml: 250)
                }
                
                // Bottle +500ml Button
                FlaskActionButton(
                    icon: "waterbottle.fill",
                    title: "+500 мл",
                    color: Color.blue
                ) {
                    addWater(ml: 500)
                }
                
                // Undo Button (if water logged)
                if !waterBeverages.isEmpty {
                    Button(action: removeLastWaterEntry) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                .frame(width: 48, height: 48)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                            
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.secondary)
                        }
                    }
                    .buttonStyle(BouncyFlaskButtonStyle())
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(isGoalReached ? Color.green.opacity(0.35) : Color.cyan.opacity(0.2), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 15, y: 6)
    }
    
    // MARK: - Actions
    private func addWater(ml: Double) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        let newBeverage = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: ml)
        TrackingManager.shared.track(.waterLogged(volume: ml))
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            if summary.modelContext == nil {
                context.insert(summary)
            }
            context.insert(newBeverage)
            summary.beverages.append(newBeverage)
            try? context.save()
        }
        
        if let user = users.first, user.isHealthKitEnabled {
            Task {
                await HealthKitManager.shared.saveWater(liters: ml / 1000.0, date: Date())
            }
        }
    }
    
    private func removeLastWaterEntry() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        
        guard let lastWater = waterBeverages.last else { return }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            if let index = summary.beverages.firstIndex(of: lastWater) {
                summary.beverages.remove(at: index)
            }
            context.delete(lastWater)
            try? context.save()
        }
    }
}

// MARK: - 3D Glass Flask Container with Fluid Waves
private struct FlaskGlassContainer: View {
    let fillRatio: Double
    
    @State private var bubbleStates: [FlaskBubble] = (0..<10).map { _ in
        FlaskBubble(
            xNorm: Double.random(in: 0.15...0.85),
            yNorm: Double.random(in: 0.2...0.9),
            size: CGFloat.random(in: 4...8),
            speed: Double.random(in: 1.8...3.2)
        )
    }
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let fillHeight = height * CGFloat(max(0.04, min(0.96, fillRatio)))
                let baseWaterLevel = height - fillHeight
                
                ZStack {
                    // Flask Background Ambient Gradient
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.04),
                                    Color.blue.opacity(0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Back Deep Ocean Wave Layer
                    FlaskWaveShape(
                        phase: time * 1.5,
                        amplitude: 6.0,
                        waterLevel: baseWaterLevel + 4
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.55, blue: 0.90).opacity(0.55),
                                Color(red: 0.0, green: 0.35, blue: 0.75).opacity(0.75)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Front Bright Turquoise Wave Layer
                    FlaskWaveShape(
                        phase: time * 2.2,
                        amplitude: 8.0,
                        waterLevel: baseWaterLevel
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.85, blue: 0.98).opacity(0.90),
                                Color(red: 0.0, green: 0.65, blue: 0.92).opacity(0.95),
                                Color(red: 0.0, green: 0.45, blue: 0.82)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Ascending Bubbles
                    ForEach(bubbleStates.indices, id: \.self) { idx in
                        let b = bubbleStates[idx]
                        let bubbleY = baseWaterLevel + (fillHeight * CGFloat(b.yNorm)) - CGFloat(time * 24 * b.speed).truncatingRemainder(dividingBy: max(fillHeight, 1))
                        
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: b.size, height: b.size)
                            .position(
                                x: width * CGFloat(b.xNorm) + sin(time * 3 + Double(idx)) * 5,
                                y: max(baseWaterLevel + 6, bubbleY)
                            )
                    }
                    
                    // Glass Refraction & Specular Highlights
                    HStack {
                        // Left Specular Reflection
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 8)
                            .padding(.leading, 8)
                            .padding(.vertical, 16)
                        
                        Spacer()
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.6),
                                    Color.cyan.opacity(0.3),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
            }
        }
    }
}

// MARK: - Bubble Model
private struct FlaskBubble {
    let xNorm: Double
    let yNorm: Double
    let size: CGFloat
    let speed: Double
}

// MARK: - Harmonic Wave Shape
private struct FlaskWaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var waterLevel: CGFloat
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: waterLevel))
        
        let wavelength = width * 0.75
        for x in stride(from: 0, through: width + 6, by: 4) {
            let relativeX = x / wavelength
            let sine = sin(relativeX * 2 * .pi + phase)
            let y = waterLevel + amplitude * CGFloat(sine)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}

// MARK: - Flask Metric Tick Mark
private struct FlaskTickMark: View {
    let label: String
    let isFilled: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(isFilled ? Color.white.opacity(0.9) : Color.primary.opacity(0.3))
                .frame(width: 14, height: 1.5)
            
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isFilled ? Color.white : Color.secondary)
        }
    }
}

// MARK: - Clean Modern Preset Action Button
private struct FlaskActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1.2)
            )
        }
        .buttonStyle(BouncyFlaskButtonStyle())
    }
}

// MARK: - Button Press Style
private struct BouncyFlaskButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
