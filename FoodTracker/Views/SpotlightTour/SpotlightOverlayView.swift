import SwiftUI
import UIKit

// MARK: - View Modifier for Target Registration
extension View {
    func spotlightTarget(step: SpotlightStep) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: SpotlightFramePreferenceKey.self,
                    value: [step: geo.frame(in: .named("SpotlightCoordinateSpace"))]
                )
            }
        )
    }
}

// MARK: - Interactive Editorial Spotlight Overlay (Calm Warm Oat Focus Ring)
struct SpotlightOverlayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var manager: SpotlightTourManager = .shared
    @State private var ringScale: CGFloat = 0.96

    var body: some View {
        if manager.isTourActive {
            GeometryReader { screenGeo in
                if let targetRect = manager.targetFrames[manager.currentStep],
                   targetRect.width > 0,
                   targetRect.height > 0 {
                    let paddedRect = targetRect.insetBy(dx: -5, dy: -5)
                    let isTargetInBottomHalf = targetRect.midY > screenGeo.size.height * 0.5
                    let cornerRadius = min(22, min(paddedRect.width, paddedRect.height) / 2)

                    ZStack(alignment: .topLeading) {
                        interactiveBackdrop

                        // Clean calm focus ring (replaces spinning neon laser)
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(EditorialPalette.oat, lineWidth: 1.75)
                            .background(
                                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                    .stroke(Color.white.opacity(0.22), lineWidth: 5)
                            )
                            .frame(width: paddedRect.width, height: paddedRect.height)
                            .scaleEffect(reduceMotion ? 1.0 : ringScale)
                            .position(x: paddedRect.midX, y: paddedRect.midY)
                            .onTapGesture {
                                advanceWithHaptic()
                            }

                        VStack {
                            if isTargetInBottomHalf {
                                Spacer()
                            }

                            tourCard
                                .padding(.horizontal, 20)
                                .padding(
                                    isTargetInBottomHalf ? .bottom : .top,
                                    isTargetInBottomHalf
                                        ? max(20, screenGeo.size.height - paddedRect.minY + 14)
                                        : max(20, paddedRect.maxY + 14)
                                )

                            if !isTargetInBottomHalf {
                                Spacer()
                            }
                        }
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                    }
                } else {
                    ZStack {
                        interactiveBackdrop
                        tourCard
                            .padding(.horizontal, 20)
                    }
                }
            }
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.84), value: manager.currentStep)
            .onAppear {
                if !reduceMotion {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        ringScale = 1.0
                    }
                }
            }
            .onChange(of: manager.currentStep) { _, _ in
                guard !reduceMotion else { return }
                ringScale = 0.96
                withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                    ringScale = 1.0
                }
            }
        }
    }

    private var interactiveBackdrop: some View {
        Color.black.opacity(0.56)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .onTapGesture {
                advanceWithHaptic()
            }
    }

    private var tourCard: some View {
        FloatingTourCard(
            step: manager.currentStep,
            onNext: { advanceWithHaptic() },
            onPrev: {
                HapticManager.shared.impact(style: .light)
                manager.previousStep()
            },
            onSkip: {
                HapticManager.shared.impact(style: .light)
                manager.finishTour()
            }
        )
    }

    private func advanceWithHaptic() {
        HapticManager.shared.impact(style: .medium)
        manager.nextStep()
    }
}

// MARK: - Editorial Matte Slate Spotlight Tooltip
private struct FloatingTourCard: View {
    let step: SpotlightStep
    let onNext: () -> Void
    let onPrev: () -> Void
    let onSkip: () -> Void

    var isLastStep: Bool {
        step == SpotlightStep.allCases.last
    }

    var isFirstStep: Bool {
        step == SpotlightStep.allCases.first
    }

    var body: some View {
        EditorialDarkCard(cornerRadius: 20, borderColor: EditorialPalette.cardBorderDarkFocused, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(SpotlightStep.allCases) { item in
                        Capsule()
                            .fill(item.rawValue <= step.rawValue ? EditorialPalette.oat : Color.white.opacity(0.14))
                            .frame(height: 3)
                    }
                }

                HStack(alignment: .center, spacing: 8) {
                    Text(step.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(step.tag)
                        .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(EditorialPalette.oat)

                    Button(action: onSkip) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .accessibilityIdentifier("spotlight_skip_button")
                    .accessibilityLabel("Skip")
                }

                Text(step.description)
                    .font(.system(size: 13.5, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    if !isFirstStep {
                        Button(action: onPrev) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(EditorialPalette.chipDark)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                                )
                        }
                    }

                    Button(action: onNext) {
                        Text(isLastStep ? String(localized: "Done") : String(localized: "Next"))
                    }
                    .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .oat, height: 44, cornerRadius: 12))
                }
            }
        }
    }
}
