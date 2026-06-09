import SwiftUI

public struct UltraPremiumCardModifier: ViewModifier {
    public init() {}
    
    public func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.white)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 6)
    }
}

public extension View {
    func ultraPremiumCardStyle() -> some View {
        self.modifier(UltraPremiumCardModifier())
    }
}
