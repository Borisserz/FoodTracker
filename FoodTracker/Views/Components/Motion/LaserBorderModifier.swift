import SwiftUI

// MARK: - Apple Intelligence Style Laser Border Modifier
public struct LaserBorderModifier: ViewModifier {
    let lineWidth: CGFloat
    let cornerRadius: CGFloat
    let colors: [Color]
    let speed: Double
    let isGlowing: Bool
    
    @State private var rotationAngle: Double = 0
    
    public init(
        lineWidth: CGFloat = 2.5,
        cornerRadius: CGFloat = 16,
        colors: [Color] = [
            Color(red: 0.18, green: 0.86, blue: 0.38),
            Color(red: 0.10, green: 0.90, blue: 0.80),
            Color(red: 0.20, green: 0.60, blue: 1.00),
            Color(red: 0.18, green: 0.86, blue: 0.38).opacity(0.1),
            Color(red: 0.18, green: 0.86, blue: 0.38)
        ],
        speed: Double = 3.0,
        isGlowing: Bool = true
    ) {
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
        self.colors = colors
        self.speed = speed
        self.isGlowing = isGlowing
    }
    
    public func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: colors),
                            center: .center,
                            startAngle: .degrees(rotationAngle),
                            endAngle: .degrees(rotationAngle + 360)
                        ),
                        lineWidth: lineWidth
                    )
                    .shadow(
                        color: isGlowing ? (colors.first ?? Color.green).opacity(0.6) : .clear,
                        radius: isGlowing ? 8 : 0
                    )
            )
            .onAppear {
                withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                    rotationAngle = 360
                }
            }
    }
}

// MARK: - View Extension
public extension View {
    func laserBorder(
        lineWidth: CGFloat = 2.5,
        cornerRadius: CGFloat = 16,
        colors: [Color] = [
            Color(red: 0.18, green: 0.86, blue: 0.38),
            Color(red: 0.10, green: 0.90, blue: 0.80),
            Color(red: 0.20, green: 0.60, blue: 1.00),
            Color(red: 0.18, green: 0.86, blue: 0.38).opacity(0.1),
            Color(red: 0.18, green: 0.86, blue: 0.38)
        ],
        speed: Double = 3.0,
        isGlowing: Bool = true
    ) -> some View {
        self.modifier(
            LaserBorderModifier(
                lineWidth: lineWidth,
                cornerRadius: cornerRadius,
                colors: colors,
                speed: speed,
                isGlowing: isGlowing
            )
        )
    }
}
