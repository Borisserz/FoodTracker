import SwiftUI

struct WaveShape: Shape {
    var offset: Double
    var waveHeight: CGFloat = 5.0
    var fillRatio: CGFloat = 0.75
    
    var animatableData: Double {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let baseHeight = rect.height * (1.0 - fillRatio)
        
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: baseHeight))
        
        let width = rect.width
        let step: CGFloat = 4.0
        
        for x in stride(from: 0, through: width, by: step) {
            let relativeX = x / width
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
    var fillPercentage: Double = 0.75
    var currentAmount: Double = 1.875
    var targetAmount: Double = 2.5
    
    @State private var wavePhase: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("HYDRATION")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.swissChartreuse)
                    Text("Wave liquid")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "drop.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.swissChartreuse)
            }
            
            // Wave Container
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.swissCardElevated)
                
                // Animated Liquid Wave
                WaveShape(offset: wavePhase, waveHeight: 6.0, fillRatio: CGFloat(fillPercentage))
                    .fill(Color.swissChartreuse)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Value text overlay
                VStack {
                    Spacer()
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(Int(fillPercentage * 100))%")
                            .font(.system(size: 28, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.black)
                        Spacer()
                        Text(String(format: "%.1fL", currentAmount))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.black.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            }
            .frame(height: 110)
        }
        .padding(16)
        .background(Color.swissCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.swissBorder, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }
}
