import SwiftUI
import UIKit

struct SwissOnboardingNavBar: View {
    let currentStage: Int
    let totalStages: Int
    let stageNames: [String]
    let onBack: () -> Void
    let onSelectStage: (Int) -> Void

    var body: some View {
        HStack(spacing: 14) {
            if currentStage > 0 {
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    onBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(EditorialPalette.inkPrimary)
                        .frame(width: 36, height: 36)
                        .background(EditorialPalette.surfaceLight)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                        )
                }
                .accessibilityLabel("Back")
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            } else {
                Text("FoodTracker")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkPrimary)
                    .frame(height: 36, alignment: .leading)
            }

            // Quiet flat step progress segments
            HStack(spacing: 5) {
                ForEach(0..<totalStages, id: \.self) { idx in
                    let isReached = idx <= currentStage
                    Button(action: {
                        guard idx < currentStage else { return }
                        let generator = UISelectionFeedbackGenerator()
                        generator.prepare()
                        generator.selectionChanged()
                        onSelectStage(idx)
                    }) {
                        Capsule()
                            .fill(
                                isReached
                                    ? EditorialPalette.forest
                                    : Color.black.opacity(0.12)
                            )
                            .frame(height: 3.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(idx > currentStage)
                    .accessibilityLabel(idx < stageNames.count ? Text(LocalizedStringKey(stageNames[idx])) : Text("Step \(idx + 1)"))
                }
            }

            Text("\(currentStage + 1) / \(totalStages)")
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(EditorialPalette.inkSecondary)
                .frame(minWidth: 34, alignment: .trailing)
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }
}
