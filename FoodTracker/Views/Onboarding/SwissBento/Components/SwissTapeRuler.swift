import SwiftUI
import UIKit

struct SwissTapeRuler: View {
    let title: String
    let unit: String
    let range: ClosedRange<Int>
    @Binding var value: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat = 0.0
    @State private var initialValueOnDrag: Int = 0

    private let stepWidth: CGFloat = 15.0

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkSecondary)

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(value)")
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(EditorialPalette.inkPrimary)
                        .contentTransition(reduceMotion ? .identity : .numericText())

                    Text(LocalizedStringKey(unit))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(EditorialPalette.inkSecondary)
                }
            }

            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.04))
                    .frame(height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                    )

                GeometryReader { geo in
                    let center = geo.size.width / 2

                    HStack(spacing: stepWidth - 2) {
                        ForEach(range, id: \.self) { tick in
                            let isMajor = tick % 5 == 0
                            let isSuperMajor = tick % 10 == 0

                            VStack(spacing: 3) {
                                Capsule()
                                    .fill(
                                        tick == value
                                            ? EditorialPalette.forest
                                            : (isSuperMajor ? Color.black.opacity(0.55) : (isMajor ? Color.black.opacity(0.32) : Color.black.opacity(0.15)))
                                    )
                                    .frame(width: tick == value ? 2.5 : (isMajor ? 1.6 : 1.1), height: isSuperMajor ? 15 : (isMajor ? 10 : 6))

                                if isSuperMajor {
                                    Text("\(tick)")
                                        .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                                        .foregroundStyle(EditorialPalette.inkSecondary.opacity(0.75))
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }
                            .frame(width: 2)
                        }
                    }
                    .offset(x: center - CGFloat(value - range.lowerBound) * stepWidth + dragOffset)
                }
                .frame(height: 50)
                .clipped()

                // Quiet center needle without neon glow
                VStack(spacing: 0) {
                    Capsule()
                        .fill(EditorialPalette.forest)
                        .frame(width: 2.5, height: 24)
                    Circle()
                        .fill(EditorialPalette.forest)
                        .frame(width: 5, height: 5)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if initialValueOnDrag == 0 {
                            initialValueOnDrag = value
                        }

                        let deltaSteps = Int(-gesture.translation.width / stepWidth)
                        let targetValue = max(range.lowerBound, min(range.upperBound, initialValueOnDrag + deltaSteps))

                        if targetValue != value {
                            value = targetValue
                            let generator = UISelectionFeedbackGenerator()
                            generator.prepare()
                            generator.selectionChanged()
                        }

                        let remainder = gesture.translation.width.truncatingRemainder(dividingBy: stepWidth)
                        dragOffset = remainder
                    }
                    .onEnded { _ in
                        initialValueOnDrag = 0
                        if reduceMotion {
                            dragOffset = 0
                        } else {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.72)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .padding(14)
        .background(EditorialPalette.surfaceLight)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
        )
    }
}
