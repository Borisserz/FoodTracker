import SwiftUI
import UIKit

struct SwissOnboardingNavBar: View {
    let currentStage: Int
    let totalStages: Int
    let stageNames: [String]
    let onBack: () -> Void
    let onSelectStage: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            // Top Controls Row: Back Button + Step Counter
            HStack(alignment: .center) {
                // Back Button (Visible when stage > 0)
                if currentStage > 0 {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.prepare()
                        generator.impactOccurred()
                        onBack()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("BACK")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.swissCardElevated)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder(Color.swissBorder, lineWidth: 1)
                        )
                    }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    // Placeholder alignment spacer or Brand Mark
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.swissChartreuse)
                            .frame(width: 8, height: 8)
                        Text("SETUP")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.swissChartreuse)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
                
                Spacer()
                
                // Monospaced Stage Badge
                HStack(spacing: 4) {
                    Text("STEP")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    
                    Text("0\(currentStage + 1)")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.swissChartreuse)
                    
                    Text("/ 0\(totalStages)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.swissCardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.swissBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            
            // Interactive Multi-Segment Progress Track
            HStack(spacing: 6) {
                ForEach(0..<totalStages, id: \.self) { idx in
                    let isCompleted = idx < currentStage
                    let isCurrent = idx == currentStage
                    
                    Button(action: {
                        if idx < currentStage {
                            let generator = UISelectionFeedbackGenerator()
                            generator.prepare()
                            generator.selectionChanged()
                            onSelectStage(idx)
                        }
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            // Segment Bar
                            Capsule()
                                .fill(
                                    isCurrent
                                        ? Color.swissChartreuse
                                        : (isCompleted ? Color.swissChartreuse.opacity(0.65) : Color.white.opacity(0.12))
                                )
                                .frame(height: isCurrent ? 5 : 3.5)
                                .shadow(
                                    color: isCurrent ? Color.swissChartreuseGlow : .clear,
                                    radius: 6
                                )
                            
                            // Stage Short Label on Active Step
                            if isCurrent && idx < stageNames.count {
                                Text(stageNames[idx])
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.swissChartreuse)
                                    .lineLimit(1)
                                    .transition(.opacity.combined(with: .scale))
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(idx > currentStage)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentStage)
    }
}
