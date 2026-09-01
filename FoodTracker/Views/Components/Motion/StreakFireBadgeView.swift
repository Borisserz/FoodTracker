import SwiftUI

// MARK: - Animated Streak Flame Badge (Supercell / Duolingo Style)
public struct StreakFireBadgeView: View {
    public let streakDays: Int
    
    @State private var flameScale: CGFloat = 1.0
    @State private var emberOffsets: [(x: CGFloat, y: CGFloat, opacity: Double)] = (0..<6).map { _ in
        (CGFloat.random(in: -10...10), CGFloat.random(in: -15...0), Double.random(in: 0.4...0.9))
    }
    
    public init(streakDays: Int) {
        self.streakDays = streakDays
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            ZStack {
                // Background Flame Glow
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.red.opacity(0.5))
                    .blur(radius: 4)
                    .scaleEffect(flameScale * 1.15)
                
                // Outer Golden-Orange Flame
                Image(systemName: "flame.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange, Color.red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(flameScale)
                
                // Inner Bright Core Flame
                Image(systemName: "flame.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .offset(y: 2)
                
                // Emitting Embers
                ForEach(emberOffsets.indices, id: \.self) { idx in
                    let e = emberOffsets[idx]
                    Circle()
                        .fill(Color.yellow.opacity(e.opacity))
                        .frame(width: 3, height: 3)
                        .offset(x: e.x, y: e.y)
                }
            }
            .frame(width: 24, height: 24)
            
            Text("\(streakDays) ДНЕЙ СТРАЙК")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange, Color(red: 1.0, green: 0.35, blue: 0.15)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.orange.opacity(0.12))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1.0)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                flameScale = 1.12
            }
        }
    }
}
