import SwiftUI

struct HoloAchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let minX: CGFloat
    let screenWidth: CGFloat

    @State private var isPressed = false

    private var offset: CGFloat {

        let cardMidX = minX + 60
        return cardMidX - screenWidth / 2
    }

    private var rotationAngle: Double {

        let angle = (offset / (screenWidth / 2)) * 15
        return max(-15, min(15, angle))
    }

    private var cardScale: CGFloat {
        let maxOffset = screenWidth / 2
        let fraction = min(1.0, abs(offset) / maxOffset)
        return 1.0 - (fraction * 0.1)
    }

    var body: some View {
        ZStack {
            if isUnlocked {

                ZStack {

                    LinearGradient(
                        colors: [achievement.color.opacity(0.6), achievement.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    VStack(spacing: 12) {
                        Image(systemName: achievement.icon)
                            .font(.system(size: 38))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)

                        VStack(spacing: 6) {
                            Text(achievement.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)

                            Text(achievement.description)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                                .lineLimit(3)
                        }
                    }
                    .padding(12)

                    LinearGradient(
                        colors: [.clear, .white.opacity(0.6), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 250)
                    .offset(x: -offset * 0.8)
                    .blendMode(.plusLighter)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                .shadow(color: achievement.color.opacity(0.4), radius: 8, y: 4)

            } else {

                ZStack {
                    Color.gray.opacity(0.15)

                    Rectangle()
                        .fill(.ultraThinMaterial)

                    VStack(spacing: 12) {
                        Image(systemName: achievement.icon)
                            .font(.system(size: 36))
                            .foregroundColor(.gray.opacity(0.5))
                            .shadow(color: .white.opacity(0.2), radius: 1, y: 1)

                        VStack(spacing: 6) {
                            Text(achievement.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary.opacity(0.5))

                            Text(achievement.description)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    }
                    .padding(12)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                .opacity(0.8)
            }
        }
        .frame(width: 120, height: 160)

        .rotation3DEffect(
            .degrees(rotationAngle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.15
        )

        .scaleEffect(isPressed ? 0.95 : cardScale)
        .onTapGesture {
            HapticManager.shared.impact(style: isUnlocked ? .heavy : .rigid)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }
    }
}
