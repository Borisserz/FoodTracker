//
//  MonetkaOnboarding1.swift
//  FoodTracker
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

// MARK: - 3D Летающий фон (Тематика ЗОЖ)
struct FloatingGlassShapes: View {
    @State private var moveX = false
    @State private var moveY = false
    @State private var floatZ = false
    
    var body: some View {
        ZStack {
            // Фоновое свечение (пульсирующее)
            Circle()
                .fill(Color.green.opacity(0.3))
                .frame(width: 350, height: 350)
                .blur(radius: 80)
                .offset(x: moveX ? 150 : -100, y: moveY ? -250 : 50)
                .scaleEffect(floatZ ? 1.1 : 0.9)
            
            // 3D Бутылка воды
            HyperRealisticWaterBottle()
                .scaleEffect(floatZ ? 0.75 : 0.85)
                .rotationEffect(.degrees(-15))
                .rotation3DEffect(.degrees(moveX ? 7 : -7), axis: (x: 1, y: 0.5, z: 0))
                .offset(x: moveX ? -110 : -50, y: moveY ? -200 : -140)
                .shadow(color: .cyan.opacity(0.2), radius: 30, x: -10, y: 15)
            
            // 3D Сочная долька апельсина
            HyperRealisticOrangeSlice()
                .scaleEffect(floatZ ? 0.95 : 1.1)
                .rotationEffect(.degrees(moveX ? 15 : -10))
                .rotation3DEffect(.degrees(moveY ? 12 : -12), axis: (x: 0.5, y: 1, z: 0.2))
                .offset(x: moveY ? 110 : 160, y: moveX ? -70 : -10)
                .shadow(color: .orange.opacity(0.4), radius: 25, x: -10, y: 15)
            
            // 3D Объемное Зеленое Яблоко
            HyperRealisticApple()
                .scaleEffect(floatZ ? 0.85 : 1.0)
                .rotationEffect(.degrees(-20))
                .rotation3DEffect(.degrees(moveX ? 8 : -8), axis: (x: 1, y: 0.2, z: 0.5))
                .offset(x: moveX ? 30 : 90, y: moveY ? 170 : 230)
                .shadow(color: .black.opacity(0.5), radius: 25, x: -15, y: 20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 7.3).repeatForever(autoreverses: true)) { moveX = true }
            withAnimation(.easeInOut(duration: 9.7).repeatForever(autoreverses: true)) { moveY = true }
            withAnimation(.easeInOut(duration: 11.1).repeatForever(autoreverses: true)) { floatZ = true }
        }
    }
}

// MARK: - ЭКСТРЕМАЛЬНО ДЕТАЛИЗИРОВАННЫЕ ЕДА И ВОДА
struct HyperRealisticWaterBottle: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [.white.opacity(0.1), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 66, height: 190)
            
            Capsule()
                .fill(LinearGradient(colors: [.cyan.opacity(0.6), .blue.opacity(0.9)], startPoint: .top, endPoint: .bottom))
                .frame(width: 58, height: 130)
                .offset(y: 26)
            
            Capsule()
                .fill(LinearGradient(colors: [.white.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom))
                .frame(width: 6, height: 150)
                .offset(x: -20, y: 10)
                .blur(radius: 1)
            
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 12, height: 120)
                .offset(x: 20, y: 20)
                .blur(radius: 3)
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [.gray, .white, .gray], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 46, height: 26)
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 46, height: 8)
                    .offset(y: -9)
            }
            .offset(y: -95)
            
            Capsule()
                .stroke(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.2), .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                .frame(width: 66, height: 190)
        }
    }
}

struct HyperRealisticOrangeSlice: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.orange, Color(red: 0.9, green: 0.3, blue: 0.0)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 140, height: 140)
                .shadow(color: .black.opacity(0.3), radius: 10, x: -5, y: 5)
            
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 128, height: 128)
            
            Circle()
                .fill(RadialGradient(gradient: Gradient(colors: [Color.yellow, Color.orange]), center: .center, startRadius: 10, endRadius: 60))
                .frame(width: 120, height: 120)
            
            ForEach(0..<8, id: \.self) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: 2.5, height: 120)
                    .rotationEffect(.degrees(Double(i) * (180.0 / 8.0)))
            }
            
            Circle()
                .fill(Color.white)
                .frame(width: 16, height: 16)
                .shadow(color: .orange.opacity(0.5), radius: 3)
            
            ZStack {
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 10, height: 24)
                Capsule()
                    .stroke(Color.white, lineWidth: 1)
                    .frame(width: 10, height: 24)
            }
            .rotationEffect(.degrees(45))
            .offset(x: 28, y: -28)
            
            Circle()
                .stroke(LinearGradient(colors: [.white.opacity(0.8), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                .frame(width: 138, height: 138)
        }
    }
}

struct HyperRealisticApple: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [Color.green.opacity(0.8), Color(red: 0.2, green: 0.7, blue: 0.1), Color(red: 0.05, green: 0.3, blue: 0.05)]),
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 100
                ))
                .frame(width: 110, height: 110)
            
            Circle()
                .trim(from: 0.1, to: 0.35)
                .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 95, height: 95)
                .rotationEffect(.degrees(-160))
                .blur(radius: 2)
            
            Ellipse()
                .fill(Color.black.opacity(0.4))
                .frame(width: 35, height: 12)
                .offset(y: -48)
                .blur(radius: 3)
            
            Capsule()
                .fill(LinearGradient(colors: [Color.brown, Color.black], startPoint: .leading, endPoint: .trailing))
                .frame(width: 6, height: 28)
                .rotationEffect(.degrees(15))
                .offset(x: 5, y: -55)
            
            ZStack {
                Ellipse()
                    .fill(LinearGradient(colors: [Color.green, Color.mint], startPoint: .top, endPoint: .bottom))
                    .frame(width: 40, height: 18)
                Capsule()
                    .fill(Color.black.opacity(0.2))
                    .frame(width: 36, height: 1)
            }
            .rotationEffect(.degrees(30))
            .offset(x: 30, y: -50)
            .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
        }
    }
}

// MARK: - ОСНОВНОЙ ЭКРАН И КНОПКИ
struct OnboardingView: View {
    var onSuccess: () -> Void

    @State private var showGuestModal = false
    @State private var isAuthenticating = false
    @State private var authErrorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.25, blue: 0.22), Color(red: 0.15, green: 0.35, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            FloatingGlassShapes()

            WelcomeStepView(
                onAppleRequest: { request in
                    SocialAuthService.shared.prepareAppleRequest(request)
                },
                onAppleCompletion: { result in
                    Task {
                        await authenticate {
                            try await SocialAuthService.shared.handleAppleAuthorization(result)
                        }
                    }
                },
                onGoogleTap: {
                    Task {
                        await authenticate {
                            try await SocialAuthService.shared.signInWithGoogle()
                        }
                    }
                },
                onGuestTap: { showGuestModal = true },
                isAuthenticating: isAuthenticating
            )
        }
        .sheet(isPresented: $showGuestModal) {
            GuestWarningView(
                onStayGuest: {
                    showGuestModal = false
                    TrackingManager.shared.track(.onboardingCompleted(goal: "guest", diet: "none"))
                    onSuccess()
                },
                onSignIn: { showGuestModal = false }
            )
            .presentationDetents([.fraction(0.48), .medium])
            .presentationDragIndicator(.visible)
            .background(Color(red: 0.12, green: 0.20, blue: 0.18).ignoresSafeArea())
        }
        .alert("Couldn't log in",
               isPresented: Binding(get: { authErrorMessage != nil },
                                    set: { if !$0 { authErrorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(authErrorMessage ?? "")
        }
        .onAppear {
            TrackingManager.shared.track(.appOpened(source: "onboarding"))
        }
    }

    @MainActor
    private func authenticate(_ action: @escaping () async throws -> Void) async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }
        do {
            try await action()
            onSuccess()
        } catch {
            if !SocialAuthService.isCancellationError(error) {
                authErrorMessage = error.localizedDescription
            }
        }
    }
}

struct WelcomeStepView: View {
    let onAppleRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onAppleCompletion: (Result<ASAuthorization, Error>) -> Void
    let onGoogleTap: () -> Void
    let onGuestTap: () -> Void
    var isAuthenticating: Bool

    private let controlWidth: CGFloat = 320
    private let controlHeight: CGFloat = 54
    private let corner: CGFloat = 16

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            Spacer(minLength: 8)

            VStack(alignment: .center, spacing: 10) {
                ZStack(alignment: .center) {
                    Text("Наполни себя энергией 🌱")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .blur(radius: 6)
                        .opacity(0.6)

                    Text("Наполни себя энергией 🌱")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.3), radius: 2, x: 0, y: 0)
                }
                .minimumScaleFactor(0.7)
                .lineLimit(1)

                Text("Мы — это то, что мы едим и пьем. Начни свой путь к осознанному питанию, следи за водным балансом и наполняй тело витаминами каждый день. Твое здоровье — твоя главная инвестиция!")
                    .font(.system(size: 14, weight: .medium))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.6)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.continue,
                                      onRequest: onAppleRequest,
                                      onCompletion: onAppleCompletion)
                    .signInWithAppleButtonStyle(.white)
                    .frame(maxWidth: controlWidth)
                    .frame(height: controlHeight)
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))

                Button(action: onGoogleTap) {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Продолжить с Google")
                    }
                }
                .buttonStyle(OnboardingGlassAuthButtonStyle(width: controlWidth, height: controlHeight, corner: corner))

                Button("Остаться гостем", action: onGuestTap)
                    .buttonStyle(OnboardingGhostAuthButtonStyle(width: controlWidth, height: controlHeight, corner: corner))
            }
            .disabled(isAuthenticating)
            .opacity(isAuthenticating ? 0.6 : 1)
            .overlay {
                if isAuthenticating {
                    ProgressView().tint(.white)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

private struct OnboardingGlassAuthButtonStyle: ButtonStyle {
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: width)
            .frame(height: height)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct OnboardingGhostAuthButtonStyle: ButtonStyle {
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: width)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct GuestWarningView: View {
    let onStayGuest: () -> Void
    let onSignIn: () -> Void
    
    var body: some View {
        ZStack {
            Color.clear
            
            VStack(alignment: .leading, spacing: 14) {
                Text("Войти как гость?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .shadow(color: .white.opacity(0.2), radius: 2)
                
                Text("Если остаться гостем, данные о вашем питании, калориях и водном балансе не будут сохраняться в облаке. При смене устройства вы потеряете дневник.")
                    .font(.system(size: 13))
                    .lineSpacing(1)
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.8)
                
                Text("Почему лучше зарегистрироваться:")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.8)
                
                VStack(alignment: .leading, spacing: 6) {
                    bullet("Сохранение дневника питания")
                    bullet("Трекинг выпитой воды на всех устройствах")
                    bullet("Персональные рецепты и рекомендации")
                }
                
                Spacer(minLength: 8)
                
                HStack(spacing: 12) {
                    Button(action: onStayGuest) {
                        Text("Гость")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    
                    Button(action: onSignIn) {
                        Text("Войти")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LinearGradient(colors: [.white, Color(white: 0.9)], startPoint: .top, endPoint: .bottom))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .white.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.orange)
                .frame(width: 4, height: 4)
                .padding(.top, 6)
                .shadow(color: .orange, radius: 3)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.92))
                .minimumScaleFactor(0.8)
        }
    }
}
