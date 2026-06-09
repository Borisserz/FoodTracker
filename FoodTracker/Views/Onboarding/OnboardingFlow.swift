import SwiftUI
import SwiftData

struct OnboardingMetrics {
    var age: Int = 25
    var height: Int = 175
    var weight: Int = 75
    var targetWeight: Int = 70
    var goal: String = "Lose Weight"
    var activityLevel: ActivityType = .none
}

struct RootOnboardingView: View {
    let onFinish: (OnboardingMetrics) -> Void
    
    @State private var currentStage = 0
    @State private var metrics = OnboardingMetrics()

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.08, blue: 0.06).ignoresSafeArea() // Deep green/black
            AnimatedBackground()
            
            if currentStage == 0 {
                OnboardingFeaturesView(onNext: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { currentStage = 1 }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStage == 1 {
                MetricsScreen(metrics: $metrics, onNext: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { currentStage = 2 }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStage == 2 {
                ActivityScreen(metrics: $metrics, onNext: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { currentStage = 3 }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStage == 3 {
                OnboardingGoalScreen(metrics: $metrics, onNext: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { currentStage = 4 }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStage == 4 {
                FinishScreen(onCalculationComplete: {
                    onFinish(metrics)
                })
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Welcome Screen
struct OnboardingWelcomeScreen: View {
    let onNext: () -> Void
    
    var body: some View {
        ZStack {
            AuroraBackground()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .themePink], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .themePink.opacity(0.4), radius: 20, y: 8)

                    Text("Welcome 👋")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Your body is a reflection of your nutrition.\nTake control of your diet and achieve your dreams.")
                        .font(.system(size: 15, weight: .medium))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 28)
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.impact(style: .heavy)
                        onNext()
                    }) {
                        Text("Get Started")
                    }
                    .buttonStyle(GlassAuthButtonStyle(width: 320, height: 54, corner: 16))
                }
                .padding(.bottom, 40)
            }
        }
    }
}

private struct GlassAuthButtonStyle: ButtonStyle {
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: width)
            .frame(height: height)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}


// MARK: - Metrics Screen
struct OnboardingMetricsScreen: View {
    @Binding var metrics: OnboardingMetrics
    let onNext: () -> Void

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Digitize yourself")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("We need your baseline to calculate macros.")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 60)
                
                Spacer()
                
                HStack(spacing: 0) {
                    OnboardingWheelColumn(title: "Age", range: 14...100, suffix: "yo", selection: $metrics.age)
                    OnboardingWheelColumn(title: "Height", range: 140...230, suffix: "cm", selection: $metrics.height)
                    OnboardingWheelColumn(title: "Weight", range: 40...200, suffix: "kg", selection: $metrics.weight)
                }
                .frame(height: 220)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                OnboardingButton(title: "Continue", action: onNext)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Goal Screen
struct OnboardingGoalScreen: View {
    @Binding var metrics: OnboardingMetrics
    let onNext: () -> Void
    
    let goals = [
        ("Lose Weight", "flame.fill", Color.themePink),
        ("Maintain", "leaf.fill", Color.green),
        ("Build Muscle", "figure.strengthtraining.traditional", Color.cyan)
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("Your Goal")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("What are we aiming for?")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
                VStack(spacing: 16) {
                    ForEach(goals, id: \.0) { goal in
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            withAnimation { metrics.goal = goal.0 }
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: goal.1)
                                    .font(.system(size: 24))
                                    .frame(width: 44, height: 44)
                                    .background(metrics.goal == goal.0 ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                    .clipShape(Circle())
                                    .foregroundColor(metrics.goal == goal.0 ? .white : goal.2)
                                
                                Text(goal.0)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Spacer()
                                
                                if metrics.goal == goal.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(goal.2)
                                        .transition(.scale)
                                }
                            }
                            .padding(16)
                            .background(metrics.goal == goal.0 ? goal.2.opacity(0.15) : Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(metrics.goal == goal.0 ? goal.2 : Color.white.opacity(0.1), lineWidth: metrics.goal == goal.0 ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
                
                OnboardingButton(title: "Confirm Goal", action: onNext)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Warp Screen (Finish)
struct OnboardingWarpScreen: View {
    let onWarpComplete: () -> Void
    @State private var animateUI = false
    @State private var isWarping = false
    @State private var flashWhite = false
    @State private var isJumping = false
    @State private var hasCompleted = false
    @State private var engine = WarpEngine()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    engine.update(time: timeline.date.timeIntervalSinceReferenceDate)
                    engine.draw(context: &context, size: size)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.themePink.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .blur(radius: 20)
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom))
                }
                
                VStack(spacing: 8) {
                    Text("Your profile is ready")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Calculating your optimal macros...\nPreparing your AI Coach.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }
                
                Spacer()
                
                OnboardingButton(title: "Enter FoodTracker") {
                    startExtendedHyperspaceJump()
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                .disabled(isJumping)
            }
            .scaleEffect(isWarping ? 0.3 : (animateUI ? 1 : 0.9))
            .opacity(isWarping ? 0 : (animateUI ? 1 : 0))

            Color.white.ignoresSafeArea().opacity(flashWhite ? 1 : 0)
        }
        .onAppear {
            HapticManager.shared.impact(style: .medium)
            withAnimation(.spring()) { animateUI = true }
        }
    }

    private func startExtendedHyperspaceJump() {
        guard !isJumping else { return }
        isJumping = true
        HapticManager.shared.impact(style: .heavy)
        
        withAnimation(.easeIn(duration: 3.5)) { isWarping = true }
        engine.startWarp()

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            HapticManager.shared.impact(style: .medium)
            try? await Task.sleep(for: .seconds(1.0))
            HapticManager.shared.impact(style: .heavy)
            withAnimation(.easeIn(duration: 0.2)) { flashWhite = true }
            try? await Task.sleep(for: .seconds(0.3))
            finishWarp()
        }
    }

    private func finishWarp() {
        guard !hasCompleted else { return }
        hasCompleted = true
        onWarpComplete()
    }
}

// MARK: - Warp Engine
class WarpEngine {
    struct Star { var x, y, z, pz: Double; var color: Color }
    var stars: [Star] = []
    var lastTime: TimeInterval = 0
    var speed: Double = 0.2
    var isWarping = false

    init() {
        let colors: [Color] = [.white, .themePink, .themeOrange, .white.opacity(0.8)]
        for _ in 0..<400 {
            stars.append(Star(
                x: Double.random(in: -2000...2000),
                y: Double.random(in: -2000...2000),
                z: Double.random(in: 10...2000),
                pz: 0,
                color: colors.randomElement()!
            ))
        }
    }
    
    func startWarp() { isWarping = true }
    
    func update(time: TimeInterval) {
        if lastTime == 0 { lastTime = time }
        let dt = time - lastTime
        lastTime = time
        
        if isWarping { speed = min(speed * 1.02, 250.0) }
        
        for i in 0..<stars.count {
            stars[i].pz = stars[i].z
            stars[i].z -= speed * dt * 60
            if stars[i].z <= 1 {
                stars[i].x = Double.random(in: -2000...2000)
                stars[i].y = Double.random(in: -2000...2000)
                stars[i].z = 2000
                stars[i].pz = 2000
            }
        }
    }
    
    func draw(context: inout GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        let cy = size.height / 2
        let fov: Double = 300
        
        for star in stars {
            let px = cx + (star.x / star.pz) * fov
            let py = cy + (star.y / star.pz) * fov
            let nx = cx + (star.x / star.z) * fov
            let ny = cy + (star.y / star.z) * fov
            
            if star.pz == 2000 { continue }
            
            var path = Path()
            path.move(to: CGPoint(x: px, y: py))
            path.addLine(to: CGPoint(x: nx, y: ny))
            
            let depthFactor = 1.0 - (star.z / 2000.0)
            context.stroke(path, with: .color(star.color.opacity(depthFactor)), lineWidth: CGFloat(max(0.5, 3.0 * depthFactor)))
        }
    }
}
