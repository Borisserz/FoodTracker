import SwiftUI

public struct GlassEffectModifier: ViewModifier {
    var material: Material
    var cornerRadius: CGFloat
    
    public init(material: Material = .ultraThinMaterial, cornerRadius: CGFloat = 16) {
        self.material = material
        self.cornerRadius = cornerRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

public extension View {
    func glassEffect(material: Material = .ultraThinMaterial, cornerRadius: CGFloat = 16) -> some View {
        self.modifier(GlassEffectModifier(material: material, cornerRadius: cornerRadius))
    }
}
