import SwiftUI
import UIKit

// MARK: - View Modifier for Target Registration
extension View {
    func spotlightTarget(step: SpotlightStep) -> some View {
        self.background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: SpotlightFramePreferenceKey.self,
                    value: [step: geo.frame(in: .global)]
                )
            }
        )
    }
}

// MARK: - Interactive Clean Green Spotlight Overlay (No Dimming, No Arrows)
struct SpotlightOverlayView: View {
    @Bindable var manager: SpotlightTourManager = .shared
    
    @State private var pulseGlow = false
    
    var body: some View {
        if manager.isTourActive {
            GeometryReader { screenGeo in
                let targetRect = manager.targetFrames[manager.currentStep] ?? CGRect(
                    x: screenGeo.size.width / 2 - 30,
                    y: screenGeo.size.height - 110,
                    width: 60,
                    height: 60
                )
                
                let paddedRect = targetRect.insetBy(dx: -6, dy: -6)
                let isTargetInBottomHalf = targetRect.midY > screenGeo.size.height * 0.52
                let cornerRadius = min(20, min(paddedRect.width, paddedRect.height) / 2)
                
                ZStack {
                    // Transparent interactive background (no dark mask)
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            advanceWithHaptic()
                        }
                    
                    // MARK: 🟢 Clean Vibrant Green Highlight Outline
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color(red: 0.18, green: 0.86, blue: 0.38), lineWidth: 2.5)
                        .frame(width: paddedRect.width, height: paddedRect.height)
                        .position(x: paddedRect.midX, y: paddedRect.midY)
                        .shadow(color: Color(red: 0.18, green: 0.86, blue: 0.38).opacity(pulseGlow ? 0.75 : 0.35), radius: pulseGlow ? 12 : 5)
                        .onTapGesture {
                            advanceWithHaptic()
                        }
                    
                    // Subtle outer pulse border
                    RoundedRectangle(cornerRadius: cornerRadius + 3, style: .continuous)
                        .stroke(Color(red: 0.18, green: 0.86, blue: 0.38).opacity(pulseGlow ? 0.4 : 0.1), lineWidth: 1.5)
                        .frame(width: paddedRect.width + 6, height: paddedRect.height + 6)
                        .position(x: paddedRect.midX, y: paddedRect.midY)
                        .scaleEffect(pulseGlow ? 1.04 : 0.98)
                    
                    // MARK: 📋 Clean Floating Explanation Card
                    VStack {
                        if isTargetInBottomHalf {
                            Spacer()
                        }
                        
                        FloatingTourCard(
                            step: manager.currentStep,
                            onNext: { advanceWithHaptic() },
                            onSkip: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.prepare()
                                generator.impactOccurred()
                                manager.finishTour()
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(isTargetInBottomHalf ? .bottom : .top, isTargetInBottomHalf ? (screenGeo.size.height - paddedRect.minY + 16) : (paddedRect.maxY + 16))
                        
                        if !isTargetInBottomHalf {
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.8), value: manager.currentStep)
            }
            .transition(.opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulseGlow = true
                }
            }
        }
    }
    
    private func advanceWithHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        manager.nextStep()
    }
}

// MARK: - Floating Explanation Card
private struct FloatingTourCard: View {
    let step: SpotlightStep
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var isLastStep: Bool {
        step == SpotlightStep.allCases.last
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Row: Step badge and Skip button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: step.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.35))
                    
                    Text(step.tag)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.35))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(red: 0.15, green: 0.85, blue: 0.35).opacity(0.15))
                .clipShape(Capsule())
                
                Spacer()
                
                Button(action: onSkip) {
                    Text("Пропустить")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
            }
            
            // "Нажмите, чтобы..." Title
            Text(step.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
            
            // Description / Explanation
            Text(step.description)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Color.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // Action button
            Button(action: onNext) {
                HStack {
                    Spacer()
                    Text(isLastStep ? "Понятно, начать! 🚀" : "Далее →")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.82, blue: 0.35), Color(red: 0.10, green: 0.70, blue: 0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(red: 0.15, green: 0.82, blue: 0.35).opacity(0.3), radius: 6, y: 3)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(red: 0.18, green: 0.86, blue: 0.38).opacity(0.45), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 20, y: 10)
    }
}
