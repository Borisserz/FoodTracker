import SwiftUI

struct WaveShape: Shape {
    var offset: Double
    var waveHeight: CGFloat = 4.0
    var fillRatio: CGFloat = 0.72

    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let clampedFill = min(max(fillRatio, 0.15), 0.92)
        let baseHeight = rect.height * (1.0 - clampedFill)

        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: baseHeight))

        let width = rect.width
        let step: CGFloat = 4.0

        for x in stride(from: 0, through: width, by: step) {
            let relativeX = x / max(width, 1)
            let sine = sin(relativeX * 2 * .pi + offset)
            let y = baseHeight + CGFloat(sine) * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct WaveLiquidHydrationView: View {
    var fillPercentage: Double = 0.72
    var currentAmount: Double = 1.75
    var targetAmount: Double = 2.4

    @AppStorage("useMetricSystem") private var useMetricSystem = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var wavePhase: Double = 0.0

    var body: some View {
        EditorialDarkCard(cornerRadius: 20, padding: 15) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Water")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Daily water guide")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                    Spacer()
                    Image(systemName: "drop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(EditorialPalette.oceanSlate)
                }

                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(EditorialPalette.chipDark)

                    WaveShape(offset: wavePhase, waveHeight: 4.0, fillRatio: CGFloat(fillPercentage))
                        .fill(EditorialPalette.oceanSlate.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Spacer()
                        HStack(alignment: .firstTextBaseline) {
                            Text(NutritionMath.formattedHydration(liters: targetAmount, useMetric: useMetricSystem))
                                .font(.system(size: 20, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(Int(fillPercentage * 100))%")
                                .font(.system(size: 12, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 11)
                        .padding(.bottom, 10)
                    }
                }
                .frame(height: 102)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }
}
