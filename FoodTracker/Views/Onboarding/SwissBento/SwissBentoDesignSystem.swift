import SwiftUI
import UIKit

// MARK: - Editorial Culinary Design Tokens
enum EditorialPalette {
    static let canvasDark = Color(hex: 0x111315)
    static let cardDark = Color(hex: 0x17181D)
    static let cardElevatedDark = Color(hex: 0x1E2027)
    static let chipDark = Color(hex: 0x121317)

    static let oat = Color(hex: 0xEFE3D3)
    static let textOnOat = Color(hex: 0x0E0F12)

    static let forest = Color(hex: 0x1D6A4E)
    static let emerald = Color(hex: 0x10B981)
    static let oceanSlate = Color(hex: 0x60A5FA)
    static let warmAmber = Color(hex: 0xFBBF24)
    static let softPeach = Color(hex: 0xE06C53)

    static let inkPrimary = Color(hex: 0x111315)
    static let inkSecondary = Color(hex: 0x5A5E66)
    static let hairlineLight = Color.black.opacity(0.08)
    static let surfaceLight = Color.white.opacity(0.76)

    static let cardBorderDark = oat.opacity(0.18)
    static let cardBorderDarkFocused = oat.opacity(0.45)
}

enum EditorialCTATone {
    case graphite
    case oat
    case forest

    var enabledBackground: Color {
        switch self {
        case .graphite: return EditorialPalette.inkPrimary
        case .oat: return EditorialPalette.oat
        case .forest: return EditorialPalette.forest
        }
    }

    var enabledForeground: Color {
        switch self {
        case .graphite, .forest: return Color.themeBg
        case .oat: return EditorialPalette.textOnOat
        }
    }
}

// MARK: - Editorial CTA & Surface Button Styles
struct EditorialPrimaryCTAButtonStyle: ButtonStyle {
    var tone: EditorialCTATone = .graphite
    var isEnabled: Bool = true
    var height: CGFloat = 54
    var cornerRadius: CGFloat = 16
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(
                isEnabled
                    ? tone.enabledForeground
                    : Color.primary.opacity(0.35)
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                isEnabled
                    ? tone.enabledBackground
                    : Color.primary.opacity(0.10)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(!reduceMotion && configuration.isPressed && isEnabled ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && isEnabled {
                    HapticManager.shared.impact(style: .medium)
                }
            }
    }
}

struct EditorialSecondaryDarkButtonStyle: ButtonStyle {
    var height: CGFloat = 52
    var cornerRadius: CGFloat = 16
    var fillColor: Color = Color(hex: 0x1C1E24)
    var borderColor: Color = Color.white.opacity(0.16)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(fillColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.impact(style: .light)
                }
            }
    }
}

// MARK: - Editorial Dark Card & Photo Backdrop
struct EditorialDarkCard<Content: View>: View {
    var cornerRadius: CGFloat = 22
    var borderColor: Color = EditorialPalette.cardBorderDark
    var padding: CGFloat = 18
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(EditorialPalette.cardDark)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            )
    }
}

/// Shared studio food photography container with crisp directional scrim and hairline frame.
struct EditorialPhotoBackdropCard<Content: View>: View {
    let imageName: String
    var minHeight: CGFloat = 180
    var cornerRadius: CGFloat = 22
    var scrimBottomOpacity: Double = 0.88
    var alignment: Alignment = .bottomLeading
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: alignment) {
            GeometryReader { geo in
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.14), location: 0.0),
                    .init(color: Color.black.opacity(0.42), location: 0.45),
                    .init(color: Color.black.opacity(scrimBottomOpacity), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.54), location: 0.0),
                    .init(color: Color.black.opacity(0.24), location: 0.56),
                    .init(color: Color.clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            content()
                .padding(18)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
        .background(EditorialPalette.cardDark)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(EditorialPalette.cardBorderDark, lineWidth: 1)
        )
    }
}

// MARK: - Clean Inset Macro Chip
struct EditorialMetricChip: View {
    let label: LocalizedStringKey
    let value: String
    var accent: Color = EditorialPalette.oat

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(accent)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(EditorialPalette.chipDark)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
        )
    }
}

// MARK: - Crisp Multi-Color Vector Google "G" Mark
struct GoogleLogoMark: View {
    var size: CGFloat = 18

    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let circleRect = CGRect(
                x: (canvasSize.width - s) / 2,
                y: (canvasSize.height - s) / 2,
                width: s,
                height: s
            )
            context.clip(to: Path(ellipseIn: circleRect))

            let center = CGPoint(x: circleRect.midX, y: circleRect.midY)
            let strokeWidth = s * 0.21
            let radius = (s - strokeWidth) / 2

            func arc(startDeg: Double, endDeg: Double, color: Color) {
                var p = Path()
                p.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(startDeg),
                    endAngle: .degrees(endDeg),
                    clockwise: false
                )
                context.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .butt))
            }

            // Blue (right bottom quadrant to center bar)
            arc(startDeg: -5, endDeg: 52, color: Color(hex: 0x4285F4))
            // Green (bottom)
            arc(startDeg: 48, endDeg: 148, color: Color(hex: 0x34A853))
            // Yellow (left)
            arc(startDeg: 144, endDeg: 218, color: Color(hex: 0xFBBC05))
            // Red (top)
            arc(startDeg: 214, endDeg: 318, color: Color(hex: 0xEA4335))

            // Horizontal bar of "G" cleanly bounded within the outer circle
            let barHeight = strokeWidth
            let barRect = CGRect(
                x: center.x - barHeight * 0.12,
                y: center.y - barHeight / 2,
                width: s / 2 + barHeight * 0.12,
                height: barHeight
            )
            context.fill(Path(barRect), with: .color(Color(hex: 0x4285F4)))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
