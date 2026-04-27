import SwiftUI
import Combine

// MARK: - РАСШИРЕНИЕ ДЛЯ ЦВЕТОВ (ИСПРАВЛЕНИЕ ОШИБОК SHAPESTYLE)
extension Color {
    static let themeMint = Color.green // Адаптация под твой дизайн
    static let textDark = Color.primary
    static let bgLight = Color.themeBg
}

extension ShapeStyle where Self == Color {
    static var themePink: Color { Color.themePink }
    static var themePeach: Color { Color.themePeach }
    static var themeMint: Color { Color.themeMint }
    static var textDark: Color { Color.textDark }
    static var bgLight: Color { Color.bgLight }
    static var themeBg: Color { Color.themeBg }
    static var themeOrange: Color { Color.themeOrange }
}

// MARK: - МОДЕЛИ ДАННЫХ ПЕЙВОЛЛА
struct PremiumPlan: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let price: String
    let duration: String
    let badge: String?
}

struct PremiumFeature: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let detail: String
}

// MARK: - ГЛАВНЫЙ ЭКРАН ПЕЙВОЛЛА
struct PremiumPaywallScreen: View {
    @AppStorage("isPremiumActivated") var isPremiumActivated: Bool = false
    
    @State private var selectedPlan: String = "Год"
    @State private var selectedFeature: PremiumFeature? = nil
    @State private var showWelcomeOverlay: Bool = false
    
    let plans: [PremiumPlan] = [
        PremiumPlan(name: "Неделя", price: "290 ₽", duration: "/ нед", badge: nil),
        PremiumPlan(name: "Месяц", price: "990 ₽", duration: "/ мес", badge: "БАЗА"),
        PremiumPlan(name: "Год", price: "5 990 ₽", duration: "/ год", badge: "ЛУЧШИЙ ВЫБОР (-60%)")
    ]
    
    var body: some View {
        ZStack {
            WellnessBackgroundView()
            
            VStack(spacing: 0) {
                TopHeaderBar()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 35) {
                        
                        AnalyzingProgressView()
                        WellnessHeaderView()
                        ProfileReadyBadgeView()
                        FeatureCarouselView(selectedFeature: $selectedFeature)
                        WellnessBentoGrid()
                        ProsConsWellnessView()
                        PricingPlansView(plans: plans, selectedPlan: $selectedPlan)
                        SafeTrialTimelineView()
                        
                        Spacer().frame(height: 180)
                    }
                    .padding(.top, 10)
                }
            }
            
            PremiumCTA(selectedPlan: selectedPlan, plans: plans) {
                HapticManager.shared.impact(style: .medium)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showWelcomeOverlay = true
                }
            }
            
            if let feature = selectedFeature {
                FeatureDetailOverlay(feature: feature) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedFeature = nil
                        HapticManager.shared.impact(style: .light)
                    }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(100)
            }
            
            if showWelcomeOverlay {
                WelcomePremiumOverlay {
                    HapticManager.shared.impact(style: .heavy)
                    withAnimation(.easeInOut(duration: 0.5)) {
                        // АКТИВИРУЕМ ПРЕМИУМ! Роутер сразу перебросит нас в ContentView
                        isPremiumActivated = true
                    }
                }
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .zIndex(200)
            }
        }
    }
}

// MARK: - СРАВНЕНИЕ (ДИЕТА VS ИИ-ПОДХОД)
struct ProsConsWellnessView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("ПОЧЕМУ МЫ ЛУЧШЕ?")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.gray)
                .tracking(2)
            
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.gray.opacity(0.6))
                        Text("ОБЫЧНАЯ ДИЕТА").font(.system(size: 12, weight: .bold)).foregroundStyle(.gray)
                    }
                    .padding(.bottom, 4)
                    
                    ComparisonRowLight(icon: "minus", color: .gray, text: "Подсчет вручную")
                    ComparisonRowLight(icon: "minus", color: .gray, text: "Постоянный голод")
                    ComparisonRowLight(icon: "minus", color: .gray, text: "Отказ от любимой еды")
                    ComparisonRowLight(icon: "minus", color: .gray, text: "Срывы через неделю")
                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles").foregroundStyle(.themePink)
                        Text("AI-НУТРИЦИОЛОГ").font(.system(size: 12, weight: .bold)).foregroundStyle(.themePink)
                    }
                    .padding(.bottom, 4)
                    
                    ComparisonRowLight(icon: "checkmark", color: .themePink, text: "Умный скан еды")
                    ComparisonRowLight(icon: "checkmark", color: .themePink, text: "Сытное меню")
                    ComparisonRowLight(icon: "checkmark", color: .themePink, text: "Любимые блюда")
                    ComparisonRowLight(icon: "checkmark", color: .themePink, text: "Результат навсегда")
                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.themePink.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.themePink.opacity(0.3), lineWidth: 1.5))
                .shadow(color: .themePink.opacity(0.1), radius: 15, y: 5)
                .scaleEffect(1.02)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct ComparisonRowLight: View {
    let icon: String
    let color: Color
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(color).padding(.top, 2)
            Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true).lineLimit(2)
        }
    }
}

struct WelcomePremiumOverlay: View {
    let onStart: () -> Void
    @State private var isPulsing: Bool = false
    
    var body: some View {
        let btnGradient = LinearGradient(colors: [.themePink, .themePeach], startPoint: .leading, endPoint: .trailing)
        
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(Color.themePink.opacity(0.1)).frame(width: 100, height: 100)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.themePink)
                        .shadow(color: .themePink.opacity(0.5), radius: isPulsing ? 20 : 10)
                        .scaleEffect(isPulsing ? 1.05 : 1.0)
                }
                
                VStack(spacing: 12) {
                    Text("ТВОЙ НОВЫЙ ЭТАП")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("ПЕРСОНАЛЬНЫЙ ПЛАН СФОРМИРОВАН")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.themePink)
                        .tracking(1)
                }
                
                Text("Мы проанализировали твои данные. Тебе больше не нужно голодать или считать каждую калорию вручную. AI-трекер берет рутину на себя.\n\nПросто питайся вкусно, а мы доведем тебя до цели.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 8)
                
                Button(action: onStart) {
                    Text("НАЧАТЬ ТРАНСФОРМАЦИЮ")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(btnGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .themePink.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.top, 16)
            }
            .padding(32)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 30)
            .padding(.horizontal, 24)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isPulsing = true }
            }
        }
    }
}

struct SafeTrialTimelineView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("КАК РАБОТАЕТ ПРОБНЫЙ ПЕРИОД:")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.gray)
                .padding(.bottom, 20)
            
            TimelineStepLightView(icon: "lock.open.fill", color: .green, title: "Сегодня", subtitle: "Полный доступ к AI-коучу и трекингу. 0 ₽.", isLast: false)
            TimelineStepLightView(icon: "bell.badge.fill", color: .themeOrange, title: "День 5", subtitle: "Напомним push-уведомлением о скором списании.", isLast: false)
            TimelineStepLightView(icon: "star.fill", color: .themePink, title: "День 7", subtitle: "Старт подписки. Отмена в 1 клик в настройках.", isLast: true)
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }
}

struct TimelineStepLightView: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                    Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
                }
                if !isLast {
                    Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 2, height: 40).padding(.vertical, 4)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(.primary)
                Text(subtitle).font(.system(size: 13, weight: .medium)).foregroundStyle(.gray).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
            Spacer()
        }
    }
}

struct ProfileReadyBadgeView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 20)).foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("АНАЛИЗ МЕТАБОЛИЗМА ЗАВЕРШЕН").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.green)
                Text("Программа адаптирована под ваши цели").font(.system(size: 13, weight: .medium)).foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 20)
    }
}

struct FeatureDetailOverlay: View {
    let feature: PremiumFeature
    let onClose: () -> Void
    @State private var isPulsing: Bool = false
    
    var body: some View {
        let iconGradient = LinearGradient(colors: feature.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        let btnGradient = LinearGradient(colors: feature.colors, startPoint: .leading, endPoint: .trailing)
        
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea().onTapGesture { onClose() }
            
            VStack(spacing: 24) {
                Image(systemName: feature.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(iconGradient)
                    .shadow(color: feature.colors[0].opacity(0.4), radius: isPulsing ? 20 : 10)
                    .scaleEffect(isPulsing ? 1.05 : 1.0)
                
                VStack(spacing: 8) {
                    Text(feature.title).font(.system(size: 26, weight: .black, design: .rounded)).foregroundStyle(.primary).multilineTextAlignment(.center)
                    Text(feature.subtitle).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(feature.colors[0])
                }
                
                Text(feature.detail)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 10)
                
                Button(action: onClose) {
                    Text("ПОНЯТНО")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(btnGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: feature.colors[0].opacity(0.3), radius: 10, y: 5)
                }
                .padding(.top, 10)
            }
            .padding(32)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 30)
            .padding(.horizontal, 24)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { isPulsing = true }
            }
        }
    }
}

struct FeatureCarouselView: View {
    @Binding var selectedFeature: PremiumFeature?
    
    let features = [
        PremiumFeature(title: "AI-Коуч", subtitle: "Твой личный нутрициолог", icon: "sparkles", colors: [.themePink, .themePeach], detail: "Задавай вопросы голосом или текстом. ИИ-помощник подскажет, что съесть на ужин, чтобы закрыть белок, и как не сорваться на сладкое."),
        PremiumFeature(title: "Smart Трекинг", subtitle: "Сканируй еду и штрихкоды", icon: "viewfinder", colors: [.blue, .cyan], detail: "Забудь про долгий поиск продуктов. Просто наведи камеру на тарелку или штрихкод, и нейросеть сама посчитает КБЖУ с точностью 98%."),
        PremiumFeature(title: "Health Sync", subtitle: "Связь с твоим телом", icon: "heart.text.square.fill", colors: [.green, .mint], detail: "Прямая интеграция с Apple Health. Мы учитываем твои тренировки, шаги и сон, чтобы динамически корректировать норму калорий на день."),
        PremiumFeature(title: "Рецепты", subtitle: "Вкусно и по макросам", icon: "fork.knife", colors: [.themeOrange, .yellow], detail: "Сотни рецептов, которые подстраиваются под твои остатки калорий. Ешь пиццу, бургеры и десерты — мы расскажем, как вписать их в план.")
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(features) { feature in
                    FeatureCardLight(feature: feature) {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { selectedFeature = feature }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }
}

struct FeatureCardLight: View {
    let feature: PremiumFeature
    let action: () -> Void
    
    var body: some View {
        let bgGradient = LinearGradient(colors: feature.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: feature.icon)
                    .font(.system(size: 32))
                    .foregroundStyle(bgGradient)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(feature.title).font(.system(size: 16, weight: .bold)).foregroundStyle(.primary)
                    Text(feature.subtitle).font(.system(size: 12, weight: .medium)).foregroundStyle(.gray)
                }
            }
            .padding(20)
            .frame(width: 200, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct WellnessBackgroundView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            Circle()
                .fill(Color.themePink.opacity(0.15))
                .frame(width: 300)
                .blur(radius: 60)
                .offset(x: isAnimating ? 100 : -50, y: isAnimating ? -100 : -200)
            
            Circle()
                .fill(Color.themePeach.opacity(0.15))
                .frame(width: 350)
                .blur(radius: 80)
                .offset(x: isAnimating ? -100 : 150, y: isAnimating ? 200 : 100)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

struct TopHeaderBar: View {
    var body: some View {
        HStack {
            Spacer()
            Button("Восстановить") {
                // Экшен восстановления
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.gray)
            .padding(.trailing, 20)
            .padding(.top, 10)
        }
    }
}

struct AnalyzingProgressView: View {
    @State private var progress: CGFloat = 0.0
    var body: some View {
        HStack {
            Text("ПОДГОТОВКА ПЛАНА").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.gray)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2))
                    Capsule().fill(LinearGradient(colors: [.themePink, .themePeach], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
            Text("\(Int(progress * 100))%").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .onAppear { withAnimation(.easeInOut(duration: 2.0)) { progress = 1.0 } }
    }
}

struct WellnessHeaderView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("AI NUTRITION COACH")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.themePink)
                .tracking(2)
            
            Text("Ешь что любишь.\nХудей без стресса.")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            
            Text("Научный подход к питанию. Нейросеть составит рацион, который работает именно для твоего тела.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }
}

struct WellnessBentoGrid: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                BentoCardLight(icon: "fork.knife", title: "Ешь и худей", color: .themePeach)
                BentoCardLight(icon: "brain.head.profile", title: "100% ИИ", color: .themePink)
            }
            HStack(spacing: 12) {
                BentoCardLight(icon: "chart.pie.fill", title: "Макросы", color: .green)
                BentoCardLight(icon: "applewatch", title: "Health Sync", color: .blue)
            }
        }
        .padding(.horizontal, 20)
    }
}

struct BentoCardLight: View {
    let icon: String; let title: String; let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(.primary)
            Spacer()
        }
        .padding(16).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
    }
}

struct PricingPlansView: View {
    let plans: [PremiumPlan]
    @Binding var selectedPlan: String
    var body: some View {
        VStack(spacing: 16) {
            ForEach(plans) { plan in
                PlanRowLightView(plan: plan, isSelected: selectedPlan == plan.name) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        selectedPlan = plan.name
                        HapticManager.shared.impact(style: .light)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct PlanRowLightView: View {
    let plan: PremiumPlan
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        let strokeCol: Color = isSelected ? .themePink : .gray.opacity(0.2)
        let bgCol: Color = isSelected ? .themePink.opacity(0.1) : .clear
        let innerCol: Color = isSelected ? .themePink : .clear
        let badgeBg: Color = isSelected ? .themePink : .gray.opacity(0.1)
        let badgeFg: Color = isSelected ? .white : .gray
        let rowBg: Color = isSelected ? .themePink.opacity(0.05) : .white
        let shadowCol: Color = isSelected ? .themePink.opacity(0.15) : .black.opacity(0.02)
        let borderCol: Color = isSelected ? .themePink : .white
        let scaleVal: CGFloat = isSelected ? 1.02 : 1.0
        
        Button(action: action) {
            HStack {
                Circle()
                    .strokeBorder(strokeCol, lineWidth: 2)
                    .background(Circle().fill(bgCol))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().fill(innerCol).frame(width: 10, height: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.name).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundStyle(.primary)
                    if let badge = plan.badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(badgeBg)
                            .foregroundStyle(badgeFg)
                            .clipShape(Capsule())
                    }
                }
                .padding(.leading, 10)
                Spacer()
                VStack(alignment: .trailing) {
                    Text(plan.price).font(.system(size: 20, weight: .black, design: .rounded)).foregroundStyle(.primary)
                    Text(plan.duration).font(.system(size: 12, weight: .medium)).foregroundStyle(.gray)
                }
            }
            .padding(20)
            .background(rowBg)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: shadowCol, radius: 15, y: 5)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(borderCol, lineWidth: isSelected ? 2 : 0))
            .scaleEffect(scaleVal)
        }
        .buttonStyle(.plain)
    }
}

struct PremiumCTA: View {
    let selectedPlan: String
    let plans: [PremiumPlan]
    let onActivate: () -> Void
    
    @State private var shimmerOffset: CGFloat = -200
    @State private var buttonPulse: Bool = false
    @State private var timeRemaining = 899
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let btnBgGradient = LinearGradient(colors: [.themePink, .themePeach], startPoint: .topLeading, endPoint: .bottomTrailing)
        let shimmerGradient = LinearGradient(colors: [.clear, .white.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
        let bottomBgGradient = LinearGradient(colors: [.themeBg.opacity(0), .themeBg, .themeBg], startPoint: .top, endPoint: .bottom)
        
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(.themePink)
                    Text("СКИДКА СГОРИТ ЧЕРЕЗ: \(timeString(timeRemaining))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.themePink)
                }
                .padding(.horizontal, 12).padding(.vertical, 6).background(Color.themePink.opacity(0.1)).clipShape(Capsule())
                .onReceive(timer) { _ in if timeRemaining > 0 { timeRemaining -= 1 } }
                
                Button(action: onActivate) {
                    ZStack {
                        btnBgGradient
                        shimmerGradient.rotationEffect(.degrees(30)).offset(x: shimmerOffset)
                        
                        Text("ПОПРОБОВАТЬ 7 ДНЕЙ")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(height: 60).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .themePink.opacity(0.4), radius: buttonPulse ? 15 : 8, y: 5)
                    .scaleEffect(buttonPulse ? 1.02 : 1.0)
                }
                .buttonStyle(.plain)
                .onAppear {
                    withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { shimmerOffset = 400 }
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) { buttonPulse = true }
                }
                
                Text("Потом \(getPriceForSelectedPlan()). Отменишь в 1 клик.")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.gray)
                
                HStack(spacing: 30) {
                    Text("Условия").underline()
                    Text("Восстановить").underline()
                    Text("Политика").underline()
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.gray.opacity(0.5))
            }
            .padding(.horizontal, 20).padding(.top, 40).padding(.bottom, 20)
            .background(bottomBgGradient)
        }
    }
    
    private func getPriceForSelectedPlan() -> String { plans.first(where: { $0.name == selectedPlan })?.price ?? "" }
    private func timeString(_ time: Int) -> String { String(format: "%02d:%02d", time / 60, time % 60) }
}
