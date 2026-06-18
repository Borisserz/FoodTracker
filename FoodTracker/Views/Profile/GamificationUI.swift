import SwiftUI

struct ProfileBreathingBackground: View {
    @State private var phase = false
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color(red: 0.05, green: 0.05, blue: 0.07) : Color.themeBg).edgesIgnoringSafeArea(.all)

            Circle()
                .fill(Color.themeOrange.opacity(colorScheme == .dark ? 0.08 : 0.05))
                .frame(width: 350, height: 350)
                .blur(radius: 120)
                .offset(x: phase ? 40 : -40, y: phase ? -30 : 30)
                .scaleEffect(phase ? 1.2 : 0.8)
                .animation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true), value: phase)
                .onAppear { phase = true }
        }
    }
}

struct NutritionLevelProgressBar: View {
    let progressManager: NutritionProgressManager
    @Environment(\.colorScheme) private var colorScheme 

    var body: some View {
        let progress = CGFloat(progressManager.progressPercentage)

        VStack(spacing: 12) {
            HStack {
                Text(String(format: String(localized: "Level %d"), progressManager.user.level))
                    .font(.caption).bold()
                    .foregroundColor(progress > 0 ? .themeOrange : .gray)
                Spacer()
                Text(String(format: String(localized: "%d XP"), progressManager.currentXPInLevel))
                    .font(.subheadline).bold()
                    .foregroundColor(.themePink)
                Spacer()
                Text(String(format: String(localized: "Level %d"), progressManager.user.level + 1))
                    .font(.caption).bold()
                    .foregroundColor(.gray)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05)) 
                        .frame(height: 12)
                    Capsule()
                        .fill(LinearGradient(colors: [.themeOrange, .themePink, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 12)
                        .shadow(color: .themePink.opacity(0.5), radius: 8, x: 0, y: 0)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(colorScheme == .dark ? Color.white.opacity(0.03) : Color.white) 
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.05), lineWidth: 1)) 
        .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.05), radius: 5, y: 2) 
        .padding(.horizontal, 20)
    }
}

struct NutritionAchievementsCarousel: View {
    let user: User
    let achievements: [Achievement] = Achievement.all
    @Environment(\.colorScheme) private var colorScheme 

    @State private var currentIndex: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        let total = CGFloat(achievements.count)
        let current = currentIndex - (dragOffset / 250)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                Text("Your trophies (Swipe)")
                    .font(.title3).bold()
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                Spacer()
            }
            .padding(.horizontal, 20)

            ZStack {
                ForEach(0..<achievements.count, id: \.self) { i in
                    let distance = shortestDistance(from: current, to: CGFloat(i), total: total)
                    let angle = distance * (360.0 / total)
                    let angleRad = angle * .pi / 180

                    let x = sin(angleRad) * 280
                    let z = cos(angleRad)

                    let scale = 0.75 + 0.25 * z
                    let opacity = max(0, 0.1 + 0.9 * z)
                    
                    let achievement = achievements[i]
                    let isUnlocked = user.unlockedAchievements.contains(achievement.id)

                    NutritionAchievementDesignerCard(
                        achievement: achievement,
                        isUnlocked: isUnlocked
                    )
                    .offset(x: x)
                    .scaleEffect(scale)
                    .opacity(z > -0.3 ? opacity : 0)
                    .zIndex(z)
                    .rotation3DEffect(.degrees(angle * 0.7), axis: (x: 0, y: 1, z: 0))
                }
            }
            .frame(height: 240)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($dragOffset) { val, state, _ in
                        state = val.translation.width
                    }
                    .onEnded { val in
                        let moved = val.translation.width / 250
                        let target = round(currentIndex - moved)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            currentIndex = target
                        }
                    }
            )
        }
    }

    func shortestDistance(from current: CGFloat, to target: CGFloat, total: CGFloat) -> CGFloat {
        let diff = target - current
        var wrapped = diff.truncatingRemainder(dividingBy: total)
        if wrapped < 0 { wrapped += total }
        if wrapped > total / 2.0 { wrapped -= total }
        return wrapped
    }
}

struct NutritionAchievementDesignerCard: View {
    let achievement: Achievement
    let isUnlocked: Bool
    @Environment(\.colorScheme) private var colorScheme 

    @State private var isBreathing = false
    @State private var showCloud = false

    private var glowColor: Color {
        guard isUnlocked else { return colorScheme == .dark ? Color.white.opacity(0.1) : Color.gray.opacity(0.4) }
        return achievement.color
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 12) {
                Image(systemName: achievement.icon)
                    .font(.system(size: 40))
                    .foregroundStyle(isUnlocked
                                     ? AnyShapeStyle(LinearGradient(colors: [.white, glowColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                                     : AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.3) : Color.gray))

                VStack(spacing: 4) {
                    Text(achievement.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : (isUnlocked ? .black : .gray)) 
                        .multilineTextAlignment(.center)
                        .lineLimit(3).minimumScaleFactor(0.8).allowsTightening(true)
                        .minimumScaleFactor(0.7)

                    Text(isUnlocked ? "Unlocked" : "Locked")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2).minimumScaleFactor(0.8).allowsTightening(true)
                }
            }
            .frame(width: 130, height: 160)
            .background(colorScheme == .dark ? Color.black.opacity(0.6) : Color(UIColor.secondarySystemGroupedBackground))
            .background(glowColor.opacity(isUnlocked ? 0.15 : 0.0))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1), lineWidth: 1))
            .shadow(color: glowColor.opacity(isBreathing && isUnlocked ? 0.6 : (colorScheme == .dark ? 0.1 : 0.05)), radius: isBreathing ? 20 : 5)
            .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 50, perform: {}, onPressingChanged: { isPressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    showCloud = isPressing
                    if isPressing { HapticManager.shared.impact(style: .soft) }
                }
            })
            .onAppear {
                if isUnlocked {
                    withAnimation(.easeInOut(duration: .random(in: 1.5...2.5)).repeatForever(autoreverses: true)) {
                        isBreathing = true
                    }
                }
            }

            if showCloud {
                VStack(spacing: 0) {
                    Text(achievement.description)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .black.opacity(0.8) : .white) 
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.8)) 
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)

                    BubbleTail()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.95) : Color.black.opacity(0.8)) 
                        .frame(width: 14, height: 8)
                }
                .offset(y: -175)
                .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
    }
}

struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
