import SwiftUI
import UIKit

// MARK: - Gamification XP Celebration & Confetti Burst Overlay
public struct ParticleConfettiBurstView: View {
    public let xpEarned: Int
    public let onDismiss: () -> Void
    
    @State private var particles: [CelebrationParticle] = []
    @State private var cardScale: CGFloat = 0.6
    @State private var cardOpacity: Double = 0
    @State private var ringRotation: Double = 0
    
    public init(xpEarned: Int = 150, onDismiss: @escaping () -> Void) {
        self.xpEarned = xpEarned
        self.onDismiss = onDismiss
    }
    
    public var body: some View {
        ZStack {
            // Dark Frosted Backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissWithAnimation()
                }
            
            // Floating Explosive Particles (Gold coins, stars, neon confetti)
            ForEach(particles) { p in
                Group {
                    if p.isCoin {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: p.size, height: p.size)
                            Text("XP")
                                .font(.system(size: p.size * 0.4, weight: .black))
                                .foregroundStyle(Color.black.opacity(0.8))
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(p.color)
                            .frame(width: p.size, height: p.size * 1.5)
                            .rotationEffect(.degrees(p.rotation))
                    }
                }
                .position(p.position)
                .opacity(p.opacity)
            }
            
            // Central Celebration Trophy Card
            VStack(spacing: 16) {
                // Trophy with animated sunburst
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [.yellow, .orange, .red, .yellow],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 86, height: 86)
                        .rotationEffect(.degrees(ringRotation))
                    
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .orange.opacity(0.6), radius: 10)
                }
                
                VStack(spacing: 6) {
                    Text("ДЕНЬ ЗАВЕРШЁН! 🏆")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Вы закрыли все цели по питанию")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                
                // XP Reward Pill
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.yellow)
                    
                    Text("+\(xpEarned) ОЧКОВ ОПЫТА")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color.yellow)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.yellow.opacity(0.18))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.yellow.opacity(0.5), lineWidth: 1.5)
                )
                
                Button(action: dismissWithAnimation) {
                    Text("ЗАБРАТЬ НАГРАДУ ⚡")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.yellow, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .orange.opacity(0.4), radius: 8, y: 3)
                }
                .padding(.top, 6)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThickMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1.5)
            )
            .padding(.horizontal, 32)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
            .shadow(color: .black.opacity(0.5), radius: 30, y: 15)
        }
        .onAppear {
            triggerExplosion()
        }
    }
    
    private func triggerExplosion() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            cardScale = 1.0
            cardOpacity = 1.0
        }
        
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }
        
        // Spawn 40 confetti particles
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let center = CGPoint(x: screenWidth / 2, y: screenHeight * 0.45)
        
        var newParticles: [CelebrationParticle] = []
        let colors: [Color] = [.yellow, .orange, .cyan, .green, Color(red: 0.18, green: 0.86, blue: 0.38), .pink]
        
        for i in 0..<45 {
            let angle = Double.random(in: 0...2 * .pi)
            let distance = CGFloat.random(in: 80...240)
            let destX = center.x + cos(angle) * distance
            let destY = center.y + sin(angle) * distance + CGFloat.random(in: 20...120)
            
            newParticles.append(
                CelebrationParticle(
                    id: i,
                    position: center,
                    destination: CGPoint(x: destX, y: destY),
                    color: colors.randomElement() ?? .yellow,
                    size: CGFloat.random(in: 8...16),
                    rotation: Double.random(in: 0...360),
                    isCoin: i % 3 == 0,
                    opacity: 1.0
                )
            )
        }
        
        self.particles = newParticles
        
        // Animate particles outward
        withAnimation(.easeOut(duration: 1.2)) {
            for i in particles.indices {
                particles[i].position = particles[i].destination
            }
        }
    }
    
    private func dismissWithAnimation() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        
        withAnimation(.easeIn(duration: 0.25)) {
            cardScale = 0.8
            cardOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

// MARK: - Particle Model
private struct CelebrationParticle: Identifiable {
    let id: Int
    var position: CGPoint
    let destination: CGPoint
    let color: Color
    let size: CGFloat
    let rotation: Double
    let isCoin: Bool
    var opacity: Double
}
