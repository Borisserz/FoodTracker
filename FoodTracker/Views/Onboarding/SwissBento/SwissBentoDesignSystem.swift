import SwiftUI
import UIKit

// MARK: - Swiss Bento Color Tokens
extension Color {
    static let swissGraphite = Color(red: 0.067, green: 0.075, blue: 0.082) // #111315
    static let swissCardSurface = Color(red: 0.102, green: 0.114, blue: 0.125) // #1A1D20
    static let swissCardElevated = Color(red: 0.137, green: 0.153, blue: 0.169) // #23272B
    static let swissBorder = Color(red: 0.165, green: 0.180, blue: 0.200) // #2A2E33
    static let swissChartreuse = Color(red: 0.839, green: 1.000, blue: 0.000) // #D6FF00 (Electric Lime)
    static let swissChartreuseGlow = Color(red: 0.839, green: 1.000, blue: 0.000).opacity(0.35)
    static let swissCyan = Color(red: 0.000, green: 0.902, blue: 0.941) // #00E6F0
    static let swissCoral = Color(red: 1.000, green: 0.369, blue: 0.227) // #FF5E3A
}

// MARK: - Swiss Bento Button Styles
struct SwissPillCTAButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .black, design: .monospaced))
            .textCase(.uppercase)
            .foregroundStyle(isEnabled ? Color.black : Color.white.opacity(0.3))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                isEnabled
                    ? Color.swissChartreuse
                    : Color.white.opacity(0.1)
            )
            .clipShape(Capsule())
            .shadow(
                color: isEnabled && !configuration.isPressed ? Color.swissChartreuse.opacity(0.45) : .clear,
                radius: configuration.isPressed ? 6 : 16,
                y: configuration.isPressed ? 2 : 6
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    let generator = UIImpactFeedbackGenerator(style: .rigid)
                    generator.prepare()
                    generator.impactOccurred()
                }
            }
    }
}

struct SwissGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(configuration.isPressed ? 0.15 : 0.06))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Swiss Bento Tile Container
struct SwissBentoTile<Content: View>: View {
    var strokeColor: Color = .swissBorder
    var cornerRadius: CGFloat = 24
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        content()
            .padding(18)
            .background(Color.swissCardSurface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
    }
}

// MARK: - Monospaced Tag Badge
struct SwissTagBadge: View {
    let text: String
    var color: Color = .swissChartreuse
    
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(color.opacity(0.25), lineWidth: 0.75)
            )
    }
}
