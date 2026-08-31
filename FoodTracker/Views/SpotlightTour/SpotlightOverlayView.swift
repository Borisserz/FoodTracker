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

// MARK: - Interactive Spotlight Overlay
struct SpotlightOverlayView: View {
    @Bindable var manager: SpotlightTourManager = .shared
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var arrowOffset: CGFloat = 0.0
    
    var body: some View {
        if manager.isTourActive {
            GeometryReader { screenGeo in
                let targetRect = manager.targetFrames[manager.currentStep] ?? CGRect(
                    x: screenGeo.size.width / 2 - 35,
                    y: screenGeo.size.height - 120,
                    width: 70,
                    height: 70
                )
                
                let targetCenter = CGPoint(x: targetRect.midX, y: targetRect.midY)
                let radius = max(targetRect.width, targetRect.height) / 2 + 16
                let isTargetInBottomHalf = targetCenter.y > screenGeo.size.height * 0.55
                
                ZStack {
                    // Darkened Backdrop with Hole Cutout
                    SpotlightMaskBackdrop(center: targetCenter, radius: radius)
                        .ignoresSafeArea()
                        .onTapGesture {
                            // Tapping anywhere advances or handles the step
                            advanceWithHaptic()
                        }
                    
                    // Glowing Pulse Rings Around Highlighted Element
                    Circle()
                        .stroke(Color.swissChartreuse, lineWidth: 3)
                        .frame(width: radius * 2, height: radius * 2)
                        .position(targetCenter)
                        .shadow(color: Color.swissChartreuse.opacity(0.8), radius: 14)
                    
                    Circle()
                        .stroke(Color.swissChartreuse.opacity(0.4), lineWidth: 1.5)
                        .frame(width: radius * 2 * pulseScale, height: radius * 2 * pulseScale)
                        .position(targetCenter)
                        .opacity(2.0 - Double(pulseScale))
                    
                    // Bouncing Glowing Arrow Indicator
                    VStack(spacing: 4) {
                        if isTargetInBottomHalf {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.swissChartreuse)
                                .shadow(color: Color.swissChartreuse, radius: 10)
                                .offset(y: arrowOffset)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundStyle(Color.swissChartreuse)
                                .shadow(color: Color.swissChartreuse, radius: 10)
                                .offset(y: -arrowOffset)
                        }
                    }
                    .position(
                        x: targetCenter.x,
                        y: isTargetInBottomHalf ? targetCenter.y - radius - 28 : targetCenter.y + radius + 28
                    )
                    
                    // Glassmorphic Tooltip Card
                    VStack {
                        if isTargetInBottomHalf {
                            Spacer()
                        }
                        
                        TooltipCard(
                            step: manager.currentStep,
                            onNext: { advanceWithHaptic() },
                            onSkip: {
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.prepare()
                                generator.impactOccurred()
                                manager.finishTour()
                            }
                        )
                        .padding(.horizontal, 22)
                        .padding(isTargetInBottomHalf ? .bottom : .top, isTargetInBottomHalf ? screenGeo.size.height - targetCenter.y + radius + 50 : targetCenter.y + radius + 50)
                        
                        if !isTargetInBottomHalf {
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: manager.currentStep)
            }
            .transition(.opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                    pulseScale = 1.45
                }
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    arrowOffset = 8.0
                }
            }
        }
    }
    
    private func advanceWithHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
        manager.nextStep()
    }
}

// MARK: - Backdrop Mask Shape with Smooth Cutout
private struct SpotlightMaskBackdrop: View {
    let center: CGPoint
    let radius: CGFloat
    
    var body: some View {
        Canvas { context, size in
            // Fill Entire Screen in Dark Glass
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.black.opacity(0.82))
            )
            
            // Cut Out the Circular Transparent Window
            context.blendMode = .destinationOut
            let rect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(Path(ellipseIn: rect), with: .color(.white))
        }
    }
}

// MARK: - Glassmorphic Tooltip Card
private struct TooltipCard: View {
    let step: SpotlightStep
    let onNext: () -> Void
    let onSkip: () -> Void
    
    var isLastStep: Bool {
        step == SpotlightStep.allCases.last
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Pill
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: step.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.swissChartreuse)
                    
                    Text("⚡ \(step.tag) \(step.title.uppercased())")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.swissChartreuse)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.swissChartreuse.opacity(0.12))
                .clipShape(Capsule())
                
                Spacer()
                
                Button(action: onSkip) {
                    Text("SKIP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
            }
            
            // Description
            Text(step.description)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            
            // Action Button
            Button(action: onNext) {
                HStack {
                    Text(isLastStep ? "GOT IT, LET'S GO ⚡" : "NEXT STEP →")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.black)
                    Spacer()
                    Image(systemName: isLastStep ? "checkmark" : "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(Color.black)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.swissChartreuse)
                .clipShape(Capsule())
                .shadow(color: Color.swissChartreuseGlow, radius: 10, y: 3)
            }
            .buttonStyle(BouncyButtonStyle())
        }
        .padding(18)
        .background(Color.swissCardSurface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.swissChartreuse.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.6), radius: 30, y: 15)
    }
}
