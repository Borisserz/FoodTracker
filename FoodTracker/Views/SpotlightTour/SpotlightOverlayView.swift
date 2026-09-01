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

// MARK: - Interactive Clean Apple Intelligence Spotlight Overlay (Laser Glow & Multi-Step Tour)
struct SpotlightOverlayView: View {
    @Bindable var manager: SpotlightTourManager = .shared
    @State private var laserAngle: Double = 0
    @State private var pulseGlow = false
    
    var body: some View {
        if manager.isTourActive {
            GeometryReader { screenGeo in
                if let targetRect = manager.targetFrames[manager.currentStep], targetRect.width > 0, targetRect.height > 0 {
                    let paddedRect = targetRect.insetBy(dx: -4, dy: -4)
                    let isTargetInBottomHalf = targetRect.midY > screenGeo.size.height * 0.5
                    let cornerRadius = min(22, min(paddedRect.width, paddedRect.height) / 2)
                    let activeColor = manager.currentStep.accentColor
                    
                    ZStack(alignment: .topLeading) {
                        // Transparent interactive backdrop (no dimming)
                        Color.black.opacity(0.001)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .ignoresSafeArea()
                            .onTapGesture {
                                advanceWithHaptic()
                            }
                        
                        // MARK: 🟢 Travelling Apple Intelligence Style Laser Beam
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        activeColor,
                                        activeColor.opacity(0.9),
                                        activeColor.opacity(0.15),
                                        activeColor
                                    ]),
                                    center: .center,
                                    startAngle: .degrees(laserAngle),
                                    endAngle: .degrees(laserAngle + 360)
                                ),
                                lineWidth: 3.2
                            )
                            .frame(width: paddedRect.width, height: paddedRect.height)
                            .position(x: paddedRect.midX, y: paddedRect.midY)
                            .shadow(color: activeColor.opacity(pulseGlow ? 0.85 : 0.35), radius: pulseGlow ? 12 : 5)
                            .onTapGesture {
                                advanceWithHaptic()
                            }
                        
                        // MARK: 📋 Clean Floating Interactive Explanation Card
                        VStack {
                            if isTargetInBottomHalf {
                                Spacer()
                            }
                            
                            FloatingTourCard(
                                step: manager.currentStep,
                                onNext: { advanceWithHaptic() },
                                onPrev: {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.prepare()
                                    generator.impactOccurred()
                                    manager.previousStep()
                                },
                                onSkip: {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.prepare()
                                    generator.impactOccurred()
                                    manager.finishTour()
                                }
                            )
                            .padding(.horizontal, 20)
                            .padding(isTargetInBottomHalf ? .bottom : .top, isTargetInBottomHalf ? (screenGeo.size.height - paddedRect.minY + 14) : (paddedRect.maxY + 14))
                            
                            if !isTargetInBottomHalf {
                                Spacer()
                            }
                        }
                        .frame(width: screenGeo.size.width, height: screenGeo.size.height)
                    }
                }
            }
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(.spring(response: 0.38, dampingFraction: 0.8), value: manager.currentStep)
            .onAppear {
                withAnimation(.linear(duration: 2.8).repeatForever(autoreverses: false)) {
                    laserAngle = 360
                }
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
    let onPrev: () -> Void
    let onSkip: () -> Void
    
    var isLastStep: Bool {
        step == SpotlightStep.allCases.last
    }
    
    var isFirstStep: Bool {
        step == SpotlightStep.allCases.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Segmented Progress Bar
            HStack(spacing: 4) {
                ForEach(SpotlightStep.allCases) { item in
                    Capsule()
                        .fill(item.rawValue <= step.rawValue ? step.accentColor : Color.primary.opacity(0.12))
                        .frame(height: 3)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
                }
            }
            
            // Header Row: Category pill and Skip button
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: step.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(step.accentColor)
                    
                    Text(step.category)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(step.accentColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(step.accentColor.opacity(0.15))
                .clipShape(Capsule())
                
                Spacer()
                
                Text(step.tag)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.secondary)
                
                Button(action: onSkip) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .padding(.leading, 4)
            }
            
            // Title
            Text(step.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
            
            // Description
            Text(step.description)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(Color.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            
            // Action buttons row (Back / Next)
            HStack(spacing: 10) {
                if !isFirstStep {
                    Button(action: onPrev) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.secondary)
                            .frame(width: 44, height: 44)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                
                Button(action: onNext) {
                    HStack {
                        Spacer()
                        Text(isLastStep ? "Завершить тур 🚀" : "Далее →")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [step.accentColor, step.accentColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: step.accentColor.opacity(0.35), radius: 8, y: 3)
                }
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(step.accentColor.opacity(0.4), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 24, y: 12)
    }
}
