//
//  MonetkaOnboarding1.swift
//  FoodTracker
//

import SwiftUI
import AuthenticationServices
import GoogleSignIn

// MARK: - Editorial Welcome & Auth Screen
struct OnboardingView: View {
    var onSuccess: () -> Void

    @State private var showGuestModal = false
    @State private var isAuthenticating = false
    @State private var authErrorMessage: String?

    var body: some View {
        ZStack {
            EditorialPalette.canvasDark.ignoresSafeArea()

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
                onGuestTap: {
                    HapticManager.shared.impact(style: .light)
                    showGuestModal = true
                },
                isAuthenticating: isAuthenticating
            )
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showGuestModal) {
            GuestWarningView(
                onStayGuest: {
                    showGuestModal = false
                    onSuccess()
                },
                onSignIn: {
                    showGuestModal = false
                }
            )
            .presentationDetents([.fraction(0.48), .medium])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "Couldn't Sign In",
            isPresented: Binding(
                get: { authErrorMessage != nil },
                set: { if !$0 { authErrorMessage = nil } }
            )
        ) {
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

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-bleed vertical editorial slate photography + calm top Forest Sage wash
            GeometryReader { geo in
                ZStack(alignment: .top) {
                    Image("onboarding_welcome_hero")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height * 0.72)
                        .clipped()

                    // Spotify-style subtle top tonal anchor
                    LinearGradient(
                        stops: [
                            .init(color: EditorialPalette.forest.opacity(0.32), location: 0.0),
                            .init(color: Color.clear, location: 0.34)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Seamless transition into matte basalt bottom dock
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.08), location: 0.0),
                            .init(color: EditorialPalette.canvasDark.opacity(0.38), location: 0.42),
                            .init(color: EditorialPalette.canvasDark.opacity(0.92), location: 0.62),
                            .init(color: EditorialPalette.canvasDark, location: 0.74)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Spacer(minLength: 24)

                // Asymmetric left-aligned editorial intro over negative slate space
                VStack(alignment: .leading, spacing: 10) {
                    Text("FoodTracker")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(EditorialPalette.oat)

                    Text("Daily nutrition and water log")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xF5F2EB))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Log meals by photo, track calories and macros, and keep daily water balanced.")
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .lineSpacing(3)
                        .foregroundStyle(Color.white.opacity(0.76))
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Auth action stack
                VStack(spacing: 12) {
                    SignInWithAppleButton(.continue, onRequest: onAppleRequest, onCompletion: onAppleCompletion)
                        .signInWithAppleButtonStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button(action: onGoogleTap) {
                        HStack(spacing: 10) {
                            GoogleLogoMark(size: 18)
                            Text("Continue with Google")
                        }
                    }
                    .buttonStyle(EditorialSecondaryDarkButtonStyle(height: 52, cornerRadius: 16))

                    Button(action: onGuestTap) {
                        Text("Continue as Guest")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.74))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding_guest_button")
                }
                .disabled(isAuthenticating)
                .opacity(isAuthenticating ? 0.6 : 1)
                .overlay {
                    if isAuthenticating {
                        ProgressView().tint(.white)
                    }
                }
            }
            .frame(maxWidth: 420, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Calm Guest Clarification Sheet
struct GuestWarningView: View {
    let onStayGuest: () -> Void
    let onSignIn: () -> Void

    var body: some View {
        ZStack {
            DynamicAuroraBackgroundView(pinnedPaletteIndex: 2, darkCanvas: true)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(EditorialPalette.warmAmber)
                        .frame(width: 34, height: 34)
                        .background(EditorialPalette.chipDark)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.75)
                        )

                    Text("Continue as Guest?")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: 0xF5F2EB))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text("Your meals, custom recipes, and health logs stay saved on this device and in your private iCloud. Signing in simply links your Apple or Google identity.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .lineSpacing(3)
                    .foregroundStyle(Color.white.opacity(0.80))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("With an account you get:")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(EditorialPalette.oat)

                    benefitRow(icon: "person.badge.shield.checkmark", text: "Link your Apple or Google identity")
                    benefitRow(icon: "arrow.triangle.2.circlepath", text: "Manage and delete your account anytime")
                    benefitRow(icon: "fork.knife", text: "Keep full access to AI Chef, Coach & Scanner")
                }

                Spacer(minLength: 4)

                HStack(spacing: 12) {
                    Button(action: onStayGuest) {
                        Text("Continue as Guest")
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(EditorialSecondaryDarkButtonStyle(height: 50, cornerRadius: 14, fillColor: EditorialPalette.cardElevatedDark))
                    .accessibilityIdentifier("onboarding_stay_guest_button")

                    Button(action: onSignIn) {
                        Text("Sign In")
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .oat, height: 50, cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(.dark)
    }

    private func benefitRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(EditorialPalette.emerald)
                .frame(width: 18, alignment: .center)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
