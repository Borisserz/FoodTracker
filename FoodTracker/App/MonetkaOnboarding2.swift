//
//  MonetkaOnboarding2.swift
//  FoodTracker
//

import SwiftUI

// MARK: - Модель данных
struct UserMetrics {
    var age: Int = 25
    var height: Int = 175
    var weight: Int = 75
    var activityLevel: ActivityType = .none
}

enum ActivityType: String, CaseIterable {
    case none = "Пока не выбрано"
    case office = "Офисный дзен"
    case light = "Легкий тонус"
    case active = "Активный метаболизм"
    case beast = "Турбо-режим"
    
    var emoji: String {
        switch self {
        case .none: return "😶"
        case .office: return "👨‍💻"
        case .light: return "🚶‍♂️"
        case .active: return "⚡️"
        case .beast: return "🔥"
        }
    }
    
    var description: String {
        switch self {
        case .none: return ""
        case .office: return "Сидячая работа, минимум шагов"
        case .light: return "Прогулки, йога 1-2 раза в неделю"
        case .active: return "Спорт 3-4 раза, регулярное движение"
        case .beast: return "Ежедневные нагрузки, высокий расход калорий"
        }
    }
}

// MARK: - Родительский View
struct OnboardingNutritionMode: View {
    // ЗАМЫКАНИЕ ДЛЯ ПЕРЕХОДА
    var onFinish: () -> Void
    
    enum Step {
        case welcome
        case metrics
        case activity
        case finish
    }
    
    @State private var step: Step = .welcome
    @State private var metrics = UserMetrics()
    
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.08, blue: 0.06).ignoresSafeArea()
            
            if step == .welcome || step == .metrics || step == .activity {
                AnimatedBackground()
            }
            
            VStack {
                switch step {
                case .welcome:
                    WelcomeScreenMetrics(onNext: { navigate(to: .metrics) })
                        .transition(pushTransition)
                case .metrics:
                    MetricsScreen(metrics: $metrics, onNext: { navigate(to: .activity) })
                        .transition(pushTransition)
                case .activity:
                    ActivityScreen(metrics: $metrics, onNext: { navigate(to: .finish) })
                        .transition(pushTransition)
                case .finish:
                    // При завершении вызываем onFinish, который перебросит нас в главное приложение
                    FinishScreen(onCalculationComplete: onFinish)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)
        }
        .preferredColorScheme(.dark)
    }
    
    private var pushTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    private func navigate(to nextStep: Step) {
        OnboardingHapticManager.playLightImpact()
        step = nextStep
    }
}

// MARK: - 1. Экран Приветствия
struct WelcomeScreenMetrics: View {
    let onNext: () -> Void
    @State private var isVisible = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            
            Text("Твое\nЧистое\nТопливо.")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, .green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                .lineSpacing(-5)
                .offset(y: isVisible ? 0 : 20)
                .opacity(isVisible ? 1 : 0)
            
            Text("Твой персональный нутрициолог. Никаких жестких диет и голодовок — только умный подход к телу и балансу энергии.\n\nГотов изменить себя изнутри?")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineSpacing(4)
                .offset(y: isVisible ? 0 : 20)
                .opacity(isVisible ? 1 : 0)
            
            Spacer()
            
            GodModeButton(title: "Начать", action: onNext)
                .offset(y: isVisible ? 0 : 30)
                .opacity(isVisible ? 1 : 0)
        }
        .padding(30)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8).delay(0.2)) { isVisible = true }
        }
    }
}

// MARK: - 2. Экран Метрик
struct MetricsScreen: View {
    @Binding var metrics: UserMetrics
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Оцифруй себя")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Базовые параметры для старта")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 60)
            
            Spacer()
            
            HStack(spacing: 0) {
                WheelColumn(title: "Возраст", range: 14...100, suffix: "лет", selection: $metrics.age)
                WheelColumn(title: "Рост", range: 140...230, suffix: "см", selection: $metrics.height)
                WheelColumn(title: "Вес", range: 40...200, suffix: "кг", selection: $metrics.weight)
            }
            .frame(height: 220)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
            )
            .padding(.horizontal, 20)
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.mint)
                
                Text("Алгоритм использует эти данные для точного расчета BMR (базового обмена веществ) и твоей дневной нормы макронутриентов.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineSpacing(2)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 30)
            
            Spacer()
            
            GodModeButton(title: "Продолжить", action: onNext)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
        }
    }
}

struct WheelColumn: View {
    let title: String
    let range: ClosedRange<Int>
    let suffix: String
    @Binding var selection: Int
    
    var body: some View {
        VStack(spacing: -10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 10)
            
            Picker(title, selection: $selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value) \(suffix)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 3. Экран Активности
struct ActivityScreen: View {
    @Binding var metrics: UserMetrics
    let onNext: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Твой ритм")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Сколько энергии ты тратишь в течение дня?")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 30)
            .padding(.top, 60)
            .padding(.bottom, 30)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach([ActivityType.office, .light, .active, .beast], id: \.self) { type in
                        ActivityCard(type: type, isSelected: metrics.activityLevel == type) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                metrics.activityLevel = type
                                OnboardingHapticManager.playSelection()
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)
            }
            
            Spacer()
            
            GodModeButton(title: "Синтезировать план", action: onNext, isDisabled: metrics.activityLevel == .none)
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
        }
    }
}

struct ActivityCard: View {
    let type: ActivityType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(type.emoji)
                    .font(.system(size: 28))
                    .frame(width: 46, height: 46)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.rawValue).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Text(type.description).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 20)).foregroundStyle(.mint).transition(.scale)
                }
            }
            .padding(14)
            .background(isSelected ? Color.mint.opacity(0.15) : Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(isSelected ? Color.mint : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1))
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 4. ЭКРАН ЗАВЕРШЕНИЯ (УЛЬТРА-ПЛАВНЫЙ И БЕЗОПАСНЫЙ)
struct FinishScreen: View {
    let onCalculationComplete: () -> Void
    
    @State private var animateUI = false
    @State private var isAbsorbing = false
    @State private var fadeOutToNext = false
    @State private var engine = MetabolicSynthesisEngine()
    
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
            .opacity(animateUI ? 1 : 0)
            
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(Color.mint.opacity(0.2)).frame(width: 100, height: 100).blur(radius: 20)
                    Image(systemName: "leaf.arrow.triangle.circlepath")
                        .font(.system(size: 46))
                        .foregroundStyle(LinearGradient(colors: [.mint, .yellow], startPoint: .top, endPoint: .bottom))
                }
                
                VStack(spacing: 8) {
                    Text("План сгенерирован")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("Твоя суточная норма калорий и макронутриентов успешно рассчитана.\n\nДобро пожаловать в лучшую версию себя.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .lineSpacing(4)
                }
                
                Spacer()
                
                GodModeButton(title: "Запустить синтез") {
                    startEnergySynthesis()
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 30)
            }
            .scaleEffect(isAbsorbing ? 0.001 : (animateUI ? 1 : 0.9))
            .opacity(isAbsorbing ? 0 : (animateUI ? 1 : 0))
            
            Rectangle()
                .fill(Color(red: 0.05, green: 0.08, blue: 0.06))
                .ignoresSafeArea()
                .opacity(fadeOutToNext ? 1 : 0)
        }
        .onAppear {
            OnboardingHapticManager.playSuccess()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { animateUI = true }
        }
    }
    
    private func startEnergySynthesis() {
        OnboardingHapticManager.playLightImpact()
        
        withAnimation(.easeIn(duration: 1.5)) {
            isAbsorbing = true
        }
        
        engine.startSynthesis()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { OnboardingHapticManager.playLightImpact() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { OnboardingHapticManager.playMediumImpact() }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            OnboardingHapticManager.playHeavyImpact()
            withAnimation(.easeInOut(duration: 1.0)) {
                fadeOutToNext = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            onCalculationComplete() // Вызов перехода в MainApp
        }
    }
}

// MARK: - Движок Сборки
class MetabolicSynthesisEngine {
    struct Particle {
        var angle: Double
        var radius: Double
        var angularSpeed: Double
        var radialSpeed: Double
        var color: Color
        var size: Double
    }
    
    var particles: [Particle] = []
    var startTime: TimeInterval = 0
    var currentTime: TimeInterval = 0
    var isSynthesizing = false
    var synthesisProgress: Double = 0.0
    
    init() {
        let colors: [Color] = [.mint, .green, .yellow, .white, .cyan]
        for _ in 0..<120 {
            particles.append(Particle(
                angle: Double.random(in: 0...2 * .pi),
                radius: Double.random(in: 150...900),
                angularSpeed: Double.random(in: 0.1...0.4),
                radialSpeed: Double.random(in: 3...8),
                color: colors.randomElement()!,
                size: Double.random(in: 1.0...3.0)
            ))
        }
    }
    
    func startSynthesis() { isSynthesizing = true }
    
    func update(time: TimeInterval) {
        if startTime == 0 { startTime = time }
        currentTime = time
        let dt = 0.016
        
        if isSynthesizing {
            let elapsed = time - startTime
            synthesisProgress = min(elapsed / 3.5, 1.0)
        }
        
        let spinMultiplier = 1.0 + (synthesisProgress * 3.0)
        let suckMultiplier = 1.0 + (synthesisProgress * 5.0)
        
        for i in 0..<particles.count {
            particles[i].angle += particles[i].angularSpeed * spinMultiplier * dt
            
            if isSynthesizing {
                particles[i].radius -= particles[i].radialSpeed * suckMultiplier * dt
                if particles[i].radius < 10 && synthesisProgress < 0.8 {
                    particles[i].radius = Double.random(in: 400...800)
                    particles[i].angle = Double.random(in: 0...2 * .pi)
                }
            } else {
                particles[i].angle += particles[i].angularSpeed * 0.2 * dt
            }
        }
    }
    
    func draw(context: inout GraphicsContext, size: CGSize) {
        let cx = Double(size.width / 2)
        let cy = Double(size.height / 2)
        
        for p in particles {
            if p.radius < 10 { continue }
            
            let tailLength = isSynthesizing ? (0.01 * (1.0 + synthesisProgress * 3)) : 0.005
            let prevAngle = p.angle - (p.angularSpeed * tailLength)
            let prevRadius = p.radius + (p.radialSpeed * tailLength)
            
            let px = cx + cos(prevAngle) * prevRadius
            let py = cy + sin(prevAngle) * prevRadius
            let nx = cx + cos(p.angle) * p.radius
            let ny = cy + sin(p.angle) * p.radius
            
            var path = Path()
            path.move(to: CGPoint(x: px, y: py))
            path.addLine(to: CGPoint(x: nx, y: ny))
            
            let fadeOut = synthesisProgress > 0.8 ? (1.0 - synthesisProgress) * 5.0 : 1.0
            let alpha = (isSynthesizing ? min(1.0, 0.4 + synthesisProgress) : 0.4) * fadeOut
            
            context.stroke(path, with: .color(p.color.opacity(alpha)), style: StrokeStyle(lineWidth: CGFloat(p.size), lineCap: .round))
        }
        
        if synthesisProgress > 0.05 {
            let scale = easeOutBack(synthesisProgress) * 1.5
            var coreContext = context
            coreContext.translateBy(x: CGFloat(cx), y: CGFloat(cy))
            coreContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
            
            let geometryOpacity = synthesisProgress > 0.8 ? (1.0 - synthesisProgress) * 5.0 : 1.0
            coreContext.opacity = geometryOpacity
            
            if synthesisProgress > 0.1 {
                var starCtx = coreContext
                starCtx.rotate(by: Angle.degrees(currentTime * 15))
                let p1 = max(0, (synthesisProgress - 0.1) * 1.2)
                var star = Path()
                for i in 0..<8 {
                    let angle = Double(i) * (.pi / 4)
                    let r1: Double = 20 * p1; let r2: Double = 60 * p1
                    if i == 0 { star.move(to: CGPoint(x: r2, y: 0)) }
                    else { star.addLine(to: CGPoint(x: cos(angle) * r2, y: sin(angle) * r2)) }
                    star.addLine(to: CGPoint(x: cos(angle + .pi/8) * r1, y: sin(angle + .pi/8) * r1))
                }
                star.closeSubpath()
                starCtx.fill(star, with: .color(.mint.opacity(0.6)))
            }
            
            if synthesisProgress > 0.3 {
                let p2 = max(0, (synthesisProgress - 0.3) * 1.4)
                var ringContext = coreContext
                ringContext.rotate(by: Angle.degrees(-currentTime * 20))
                var ring = Path()
                ring.addArc(center: .zero, radius: CGFloat(80 * p2), startAngle: Angle.zero, endAngle: Angle.degrees(360), clockwise: true)
                ringContext.stroke(ring, with: .color(.yellow.opacity(0.8)), style: StrokeStyle(lineWidth: 3, dash: [10, 15]))
            }
            
            if synthesisProgress > 0.5 {
                let p3 = max(0, (synthesisProgress - 0.5) * 2.0)
                var orbitContext = coreContext
                orbitContext.rotate(by: Angle.degrees(currentTime * 25))
                for i in 0..<3 {
                    var orbit = Path()
                    orbit.addEllipse(in: CGRect(x: -120 * p3, y: -40 * p3, width: 240 * p3, height: 80 * p3))
                    var transform = CGAffineTransform(rotationAngle: CGFloat(Double(i) * .pi / 3))
                    if let transformedOrbit = orbit.applying(transform).cgPath as CGPath? {
                        orbitContext.stroke(Path(transformedOrbit), with: .color(.white.opacity(0.4)), style: StrokeStyle(lineWidth: 2))
                        let nodeCenter = CGPoint(x: cos(Double(i) * .pi / 3) * 120 * p3, y: sin(Double(i) * .pi / 3) * 120 * p3)
                        var node = Path()
                        node.addArc(center: nodeCenter, radius: CGFloat(6 * p3), startAngle: Angle.zero, endAngle: Angle.degrees(360), clockwise: true)
                        orbitContext.fill(node, with: .color(.cyan.opacity(0.7)))
                    }
                }
            }
            
            if synthesisProgress > 0.7 {
                let flashP = max(0, (synthesisProgress - 0.7) * 3.3)
                var halo = Path()
                halo.addArc(center: .zero, radius: CGFloat(200 * flashP), startAngle: Angle.zero, endAngle: Angle.degrees(360), clockwise: true)
                var haloContext = coreContext
                haloContext.addFilter(.blur(radius: 40))
                haloContext.fill(halo, with: .color(.mint.opacity(0.2 * flashP)))
            }
        }
    }
    
    private func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }
}

// MARK: - Универсальный UI
struct GodModeButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isDisabled ? Color.white.opacity(0.3) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isDisabled ? AnyShapeStyle(Color.white.opacity(0.1)) : AnyShapeStyle(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom)))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: isDisabled ? .clear : .mint.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(isDisabled)
        .buttonStyle(BouncyButtonStyle())
    }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct AnimatedBackground: View {
    @State private var move1 = false
    @State private var move2 = false
    
    var body: some View {
        ZStack {
            Circle().fill(Color.mint.opacity(0.15)).frame(width: 300, height: 300).blur(radius: 80).offset(x: move1 ? 100 : -100, y: move1 ? -150 : 0)
            Circle().fill(Color.green.opacity(0.12)).frame(width: 350, height: 350).blur(radius: 100).offset(x: move2 ? -150 : 150, y: move2 ? 200 : 50)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) { move1 = true }
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) { move2 = true }
        }
    }
}

class OnboardingHapticManager {
    static func playLightImpact() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func playMediumImpact() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    static func playHeavyImpact() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    static func playSelection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    static func playSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
