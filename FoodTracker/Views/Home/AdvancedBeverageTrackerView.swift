import SwiftUI
import SwiftData

struct WaterGridTrackerView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]

    @Bindable var summary: DailySummary

    let dailyGoalLiters = 2.5
    let volumePerGridCupMl: Double = 250.0
    let gridColumns = 6

    var waterBeverages: [Beverage] {
        (summary.beverages ?? []).filter { $0.name == "Water" }.sorted { $0.date < $1.date }
    }

    var waterLiters: Double {
        waterBeverages.reduce(0) { $0 + $1.volumeMl } / 1000.0
    }

    var filledGlassesCount: Int {
        Int((waterLiters * 1000) / volumePerGridCupMl)
    }

    var isGoalReached: Bool { waterLiters >= dailyGoalLiters }
    var progress: Double { min(waterLiters / dailyGoalLiters, 1.0) }

    var totalCupsToDraw: Int {
        let baseCups = Int((dailyGoalLiters * 1000) / volumePerGridCupMl)

        let requiredCups = max(baseCups, filledGlassesCount + 1)

        let remainder = requiredCups % gridColumns
        let cupsToCompleteRow = remainder == 0 ? 0 : (gridColumns - remainder)

        return requiredCups + cupsToCompleteRow
    }

    var body: some View {
        VStack(spacing: 24) {

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Water Balance")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(waterLiters, specifier: "%.2f")")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundColor(isGoalReached ? .blue : .cyan)
                            .contentTransition(.numericText(value: waterLiters))

                        Text("L")
                            .font(.title2.bold())
                            .foregroundColor(isGoalReached ? .blue : .cyan)

                        Text("/ \(dailyGoalLiters, specifier: "%.2f") L")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.8))
                            .fontWeight(.medium)
                    }
                }
                Spacer()

                ZStack {
                    Circle().stroke(Color.cyan.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: progress)

                    Image(systemName: isGoalReached ? "checkmark" : "drop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isGoalReached ? .blue : .cyan)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 56, height: 56)
                .shadow(color: Color.cyan.opacity(isGoalReached ? 0.3 : 0.1), radius: 8, x: 0, y: 4)
            }

            HStack(spacing: 12) {
                WaterPresetButton(icon: "drop.fill", title: String(localized: "Glass"), volume: "+250 ml") {
                    addWater(ml: 250)
                }
                WaterPresetButton(icon: "waterbottle.fill", title: String(localized: "Bottle"), volume: "+500 ml") {
                    addWater(ml: 500)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: gridColumns), spacing: 16) {
                ForEach(0..<totalCupsToDraw, id: \.self) { index in
                    let isFilled = index < filledGlassesCount
                    let isNext = index == filledGlassesCount
                    let isLastFilled = isFilled && index == filledGlassesCount - 1

                    WaterGlassItemView(
                        isFilled: isFilled,
                        isNext: isNext,
                        isLastFilled: isLastFilled
                    ) {
                        if isLastFilled {
                            removeLastWaterEntry()
                        } else if isNext {
                            addWater(ml: 250)
                        }
                    }
                }
            }

            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: totalCupsToDraw)
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(28)
        .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(isGoalReached ? Color.cyan.opacity(0.3) : Color.clear, lineWidth: 2)
                .animation(.easeInOut, value: isGoalReached)
        )
    }

    private func addWater(ml: Double) {
           HapticManager.shared.impact(style: .medium)
           let newBeverage = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: ml)

           TrackingManager.shared.track(.waterLogged(volume: ml))

           withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {

               if summary.modelContext == nil {
                   context.insert(summary)
               }
               context.insert(newBeverage)
               summary.beverages = (summary.beverages ?? []) + [newBeverage]
               try? context.save()
           }

           if let user = users.first, user.isHealthKitEnabled {
               Task {
                   await HealthKitManager.shared.saveWater(liters: ml / 1000.0, date: Date())
               }
           }
       }
    private func removeLastWaterEntry() {
        HapticManager.shared.impact(style: .light)
        guard let lastWater = waterBeverages.last else { return }

        withAnimation {
            if let index = (summary.beverages ?? []).firstIndex(of: lastWater) {
                var bevs = summary.beverages ?? []
                bevs.remove(at: index)
                summary.beverages = bevs
                context.delete(lastWater)
                try? context.save()
            }
        }
    }
}

struct WaterPresetButton: View {
    let icon: String
    let title: String
    let volume: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(volume)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 4)

                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.cyan.opacity(0.8))
                    .font(.system(size: 20))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.cyan.opacity(0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.cyan.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(WaterGlassButtonStyle())
    }
}

struct WaterGlassItemView: View {
    let isFilled: Bool
    let isNext: Bool
    let isLastFilled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PremiumGlassContentView(isFilled: isFilled, isNext: isNext, isLastFilled: isLastFilled)
        }
        .buttonStyle(WaterGlassButtonStyle())
        .disabled(!isNext && !isLastFilled)
    }
}

struct PremiumGlassContentView: View {
    let isFilled: Bool
    let isNext: Bool
    let isLastFilled: Bool

    @State private var isPulsing = false

    var body: some View {
        ZStack(alignment: .bottom) {

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.gray.opacity(0.06))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )

            GeometryReader { geo in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.8), Color.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: isFilled ? geo.size.height : 0)
                        .opacity(isFilled ? 1 : 0)
                }
            }
            .padding(2)

            if isNext {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 30, height: 30)
                        .scaleEffect(isPulsing ? 1.2 : 0.8)
                        .opacity(isPulsing ? 0 : 1)

                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.cyan)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
            } else if isLastFilled {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 24, height: 24)

                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 75)
        .contentShape(Rectangle())
    }
}

struct WaterGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
