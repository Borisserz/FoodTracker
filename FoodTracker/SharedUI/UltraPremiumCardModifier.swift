import SwiftUI

public struct UltraPremiumCardModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.regularMaterial)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.15 : 0.6),
                                Color.white.opacity(colorScheme == .dark ? 0.02 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 20, x: 0, y: 10)
    }
}

public extension View {
    func ultraPremiumCardStyle() -> some View {
        self.modifier(UltraPremiumCardModifier())
    }
}
