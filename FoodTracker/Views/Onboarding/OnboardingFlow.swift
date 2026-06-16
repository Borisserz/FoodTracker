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
                MetricsScreen(metrics: $metrics, onNext: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { currentStage = 1 }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStage == 1 {
                OnboardingGoalScreen(metrics: $metrics, onNext: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { currentStage = 2 }
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else if currentStage == 2 {
                OnboardingFeaturesView(onNext: {
                    onFinish(metrics)
                })
                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
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
                    OnboardingWheelColumn(title: String(localized: "Age"), range: 14...100, suffix: String(localized: "yo"), selection: $metrics.age)
                    OnboardingWheelColumn(title: String(localized: "Height"), range: 140...230, suffix: String(localized: "cm"), selection: $metrics.height)
                    OnboardingWheelColumn(title: String(localized: "Weight"), range: 40...200, suffix: String(localized: "kg"), selection: $metrics.weight)
                }
                .frame(height: 220)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.1), lineWidth: 1))
                )
                .padding(.horizontal, 20)
                
                Spacer()
                
                OnboardingButton(title: String(localized: "Continue"), action: onNext)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Goal Screen Custom Shapes and Illustrations

struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.5, y: h))
        
        // Left curve up to tip
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: -w * 0.1, y: h * 0.7),
            control2: CGPoint(x: w * 0.2, y: h * 0.3)
        )
        
        // Right curve down to base
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w * 0.8, y: h * 0.3),
            control2: CGPoint(x: w * 1.1, y: h * 0.7)
        )
        
        path.closeSubpath()
        return path
    }
}

struct FlameIllustration: View {
    @State private var isFlickering = false
    @State private var animateEmbers = false
    
    private let embers: [(x: CGFloat, size: CGFloat, duration: Double, delay: Double)] = [
        (x: -12, size: 3.0, duration: 1.8, delay: 0.0),
        (x: 8, size: 2.0, duration: 2.2, delay: 0.3),
        (x: -4, size: 3.5, duration: 1.5, delay: 0.6),
        (x: 12, size: 2.5, duration: 2.5, delay: 0.2),
        (x: -16, size: 2.5, duration: 2.0, delay: 0.8),
        (x: 2, size: 4.0, duration: 1.7, delay: 0.5),
        (x: -8, size: 2.0, duration: 2.4, delay: 1.1),
        (x: 10, size: 3.0, duration: 1.9, delay: 0.7)
    ]
    
    var body: some View {
        ZStack {
            // Underglow
            Circle()
                .fill(Color.themePink.opacity(0.25))
                .frame(width: 50, height: 50)
                .blur(radius: 8)
            
            // Embers rising
            ForEach(0..<embers.count, id: \.self) { idx in
                let emb = embers[idx]
                Circle()
                    .fill(
                        LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom)
                    )
                    .frame(width: emb.size, height: emb.size)
                    .offset(x: emb.x, y: animateEmbers ? -55 : 25)
                    .opacity(animateEmbers ? 0 : 0.8)
                    .animation(
                        .linear(duration: emb.duration)
                        .repeatForever(autoreverses: false)
                        .delay(emb.delay),
                        value: animateEmbers
                    )
            }
            
            // Outer Flame Shape (Pulsing)
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [Color.themePink.opacity(0.45), Color.themeOrange.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 44, height: 54)
                .scaleEffect(isFlickering ? 1.08 : 0.95, anchor: .bottom)
                .offset(y: isFlickering ? -1 : 1)
                .blur(radius: 1)
            
            // Inner Flame Shape (Core)
            FlameShape()
                .fill(
                    LinearGradient(
                        colors: [Color.themeOrange, Color.themeYellow],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 28, height: 38)
                .scaleEffect(isFlickering ? 0.92 : 1.05, anchor: .bottom)
                .offset(y: isFlickering ? 1 : -1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.15).repeatForever(autoreverses: true)) {
                isFlickering = true
            }
            // Trigger ember animation
            DispatchQueue.main.async {
                animateEmbers = true
            }
        }
    }
}

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: 0, y: h))
        path.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w * 0.1, y: 0))
        path.addQuadCurve(to: CGPoint(x: 0, y: h), control: CGPoint(x: w, y: h * 0.9))
        
        path.closeSubpath()
        return path
    }
}

struct SproutRippleView: View {
    @State private var animate = false
    let delay: Double
    
    var body: some View {
        Circle()
            .stroke(Color.green.opacity(0.35), lineWidth: 1.5)
            .frame(width: 44, height: 44)
            .scaleEffect(animate ? 1.8 : 0.6)
            .opacity(animate ? 0.0 : 0.6)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.4)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    animate = true
                }
            }
    }
}

struct SproutIllustration: View {
    @State private var isSwaying = false
    
    var body: some View {
        ZStack {
            // Ripple Waves
            ForEach(0..<3, id: \.self) { i in
                SproutRippleView(delay: Double(i) * 0.8)
            }
            
            // Stem and Leaf
            ZStack(alignment: .bottom) {
                // Background glow
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .blur(radius: 8)
                
                // Sprout Stem
                Path { path in
                    path.move(to: CGPoint(x: 25, y: 45))
                    path.addQuadCurve(to: CGPoint(x: 25, y: 15), control: CGPoint(x: 22, y: 30))
                }
                .stroke(
                    LinearGradient(colors: [.green, .themeYellow], startPoint: .bottom, endPoint: .top),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 50, height: 50)
                
                // Left Leaf
                LeafShape()
                    .fill(
                        LinearGradient(colors: [.green, .themeYellow], startPoint: .bottomLeading, endPoint: .topTrailing)
                    )
                    .frame(width: 20, height: 14)
                    .rotationEffect(.degrees(-35), anchor: .bottomTrailing)
                    .offset(x: -8, y: -26)
                
                // Right Leaf
                LeafShape()
                    .fill(
                        LinearGradient(colors: [.green, .themeYellow], startPoint: .bottomTrailing, endPoint: .topLeading)
                    )
                    .frame(width: 20, height: 14)
                    .rotationEffect(.degrees(35), anchor: .bottomLeading)
                    .scaleEffect(x: -1, y: 1) // Flip horizontally
                    .offset(x: 8, y: -30)
            }
            .frame(width: 50, height: 50)
            .rotationEffect(.degrees(isSwaying ? 6 : -6), anchor: .bottom)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isSwaying = true
            }
        }
    }
}

struct PowerRingView: View {
    @State private var animate = false
    let delay: Double
    
    var body: some View {
        Ellipse()
            .stroke(Color.cyan.opacity(0.4), lineWidth: 1.5)
            .frame(width: 60, height: 26)
            .scaleEffect(animate ? 1.6 : 0.6)
            .opacity(animate ? 0.0 : 0.7)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.0)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    animate = true
                }
            }
    }
}

struct DumbbellView: View {
    var body: some View {
        HStack(spacing: 0) {
            // Left weight plate 1 (small)
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                .frame(width: 4, height: 16)
            
            // Left weight plate 2 (large)
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                .frame(width: 6, height: 28)
            
            // Bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.8))
                .frame(width: 18, height: 5)
            
            // Right weight plate 2 (large)
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                .frame(width: 6, height: 28)
            
            // Right weight plate 1 (small)
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                .frame(width: 4, height: 16)
        }
    }
}

struct DumbbellIllustration: View {
    @State private var isLifting = false
    
    var body: some View {
        ZStack {
            // Cyan glow behind
            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 50, height: 50)
                .blur(radius: 8)
            
            // Power rings expanding
            ForEach(0..<2, id: \.self) { i in
                PowerRingView(delay: Double(i) * 1.0)
            }
            
            // Dumbbell structure oscillating
            DumbbellView()
                .shadow(color: .cyan.opacity(0.4), radius: 6)
                .offset(y: isLifting ? -8 : 6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isLifting = true
            }
        }
    }
}

struct GoalCard: View {
    let title: String
    let description: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    let motion: MotionManager
    
    @State private var dragOffset = CGSize.zero
    
    private var rollDegrees: Double {
        let baseRoll = max(-12, min(12, motion.roll * 180 / .pi))
        let dragRoll = Double(dragOffset.width) / 8.0
        return max(-15, min(15, baseRoll + dragRoll))
    }
    
    private var pitchDegrees: Double {
        let basePitch = max(-12, min(12, motion.pitch * 180 / .pi))
        let dragPitch = Double(dragOffset.height) / 8.0
        return max(-15, min(15, basePitch + dragPitch))
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            action()
        }) {
            HStack(spacing: 20) {
                // Left Column: Custom animated micro-illustration
                ZStack {
                    if title == "Lose Weight" {
                        FlameIllustration()
                    } else if title == "Maintain" {
                        SproutIllustration()
                    } else {
                        DumbbellIllustration()
                    }
                }
                .frame(width: 64, height: 64)
                .offset(x: CGFloat(-rollDegrees * 1.2), y: CGFloat(-pitchDegrees * 1.2))
                
                // Middle Column: Text info
                VStack(alignment: .leading, spacing: 6) {
                    Text(title.uppercased())
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .tracking(1.0)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, isSelected ? color : color.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text(description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(isSelected ? 0.8 : 0.55))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .offset(x: CGFloat(-rollDegrees * 0.6), y: CGFloat(-pitchDegrees * 0.6))
                
                Spacer()
                
                // Right Column: Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? color : Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(color)
                            .frame(width: 14, height: 14)
                            .shadow(color: color, radius: 4)
                            .transition(.scale)
                    }
                }
                .offset(x: CGFloat(-rollDegrees * 0.3), y: CGFloat(-pitchDegrees * 0.3))
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(isSelected ? 0.55 : 0.35))
                    .background(.ultraThinMaterial)
            )
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                isSelected ? color : Color.white.opacity(0.15),
                                isSelected ? color.opacity(0.5) : Color.white.opacity(0.05),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isSelected ? 2.0 : 1.0
                    )
            )
            .shadow(
                color: isSelected ? color.opacity(0.3) : Color.black.opacity(0.2),
                radius: isSelected ? 18 : 8,
                x: CGFloat(rollDegrees * 0.8),
                y: CGFloat(pitchDegrees * 0.8) + (isSelected ? 6 : 2)
            )
        }
        .buttonStyle(.plain)
        .rotation3DEffect(
            .degrees(rollDegrees),
            axis: (x: 0.0, y: 1.0, z: 0.0),
            perspective: 0.3
        )
        .rotation3DEffect(
            .degrees(pitchDegrees),
            axis: (x: -1.0, y: 0.0, z: 0.0),
            perspective: 0.3
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                        dragOffset = value.translation
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        dragOffset = .zero
                    }
                }
        )
    }
}

// MARK: - Goal Screen
struct OnboardingGoalScreen: View {
    @Binding var metrics: OnboardingMetrics
    let onNext: () -> Void
    
    @State private var motionManager = MotionManager.shared
    
    let goals = [
        (title: String(localized: "Lose Weight"), id: "Lose Weight", desc: String(localized: "Burn fat, optimize metabolism, and feel lighter"), color: Color.themePink),
        (title: String(localized: "Maintain"), id: "Maintain", desc: String(localized: "Keep your current shape, feel active, and sustain energy"), color: Color.green),
        (title: String(localized: "Build Muscle"), id: "Build Muscle", desc: String(localized: "Build strength, increase density, and grow lean muscle"), color: Color.cyan)
    ]

    var selectedGoalColor: Color {
        if metrics.goal == "Lose Weight" {
            return .themePink
        } else if metrics.goal == "Maintain" {
            return .green
        } else {
            return .cyan
        }
    }

    var body: some View {
        ZStack {
            // Cosmic background that shifts color according to selected goal
            CosmicStarfieldView(themeColor: selectedGoalColor, motion: motionManager)
            
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("YOUR GOAL")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, selectedGoalColor, selectedGoalColor.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("What are we aiming for?")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 60)
                .padding(.bottom, 30)
                
                VStack(spacing: 18) {
                    ForEach(goals, id: \.title) { goal in
                        GoalCard(
                            title: goal.title,
                            description: goal.desc,
                            color: goal.color,
                            isSelected: metrics.goal == goal.id,
                            action: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    metrics.goal = goal.id
                                }
                            },
                            motion: motionManager
                        )
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                CosmicContinueButton(
                    title: String(localized: "Confirm Goal"),
                    themeColor: selectedGoalColor,
                    action: onNext
                )
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
                
                OnboardingButton(title: String(localized: "Enter FoodTracker")) {
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
