import SwiftUI

struct CircadianFastingClock: View {
    var protocolName: String = "16:8 Intermittent"
    var hoursFasted: Int = 11
    var minutesRemaining: Int = 48
    
    @State private var pulseGlow: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FASTING PROTOCOL")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.swissChartreuse)
                    Text(protocolName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "timer")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.swissChartreuse)
            }
            
            // Fasting Arc Display
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.swissBorder, lineWidth: 8)
                
                // Active Fasting Progress Arc
                Circle()
                    .trim(from: 0.0, to: CGFloat(hoursFasted) / 16.0)
                    .stroke(
                        Color.swissChartreuse,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.swissChartreuseGlow, radius: pulseGlow ? 10 : 4)
                
                // Central Time Remaining Ticker
                VStack(spacing: 2) {
                    Text("\(16 - hoursFasted)h \(minutesRemaining)m")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    Text("REMAINING")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.swissChartreuse)
                }
            }
            .frame(height: 90)
            .padding(.vertical, 4)
        }
        .padding(16)
        .background(Color.swissCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.swissBorder, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseGlow = true
            }
        }
    }
}
