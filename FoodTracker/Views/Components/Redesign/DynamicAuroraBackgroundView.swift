import SwiftUI

// MARK: - Spotify-Style Vertical Tonal Wash Background (Calm Top-to-Bottom Saturation Falloff)
struct DynamicAuroraBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var paletteIndex: Int
    private let paletteTrigger: Int
    private let tabTag: Int?

    private struct TonalPalette {
        let primary: Color
        let secondary: Color
    }

    // Calm, curated editorial palettes (zero neon slop, Spotify vertical fade cadence)
    private static let palettes: [TonalPalette] = [
        // 0: Forest Sage
        TonalPalette(primary: Color(hex: 0x1D6A4E), secondary: Color(hex: 0x2E8062)),
        // 1: Deep Ocean Teal
        TonalPalette(primary: Color(hex: 0x1B596E), secondary: Color(hex: 0x2D748C)),
        // 2: Roasted Espresso Amber
        TonalPalette(primary: Color(hex: 0x8A4E1F), secondary: Color(hex: 0xAD6B32)),
        // 3: Midnight Cobalt
        TonalPalette(primary: Color(hex: 0x27407A), secondary: Color(hex: 0x3A5A9E)),
        // 4: Muted Plum
        TonalPalette(primary: Color(hex: 0x5C2F66), secondary: Color(hex: 0x7B4687)),
        // 5: Deep Rosewood
        TonalPalette(primary: Color(hex: 0x7A2E3B), secondary: Color(hex: 0x994352))
    ]

    init(seed: Int? = nil, paletteTrigger: Int = 0, tabTag: Int? = nil) {
        if let s = seed {
            self._paletteIndex = State(initialValue: abs(s) % Self.palettes.count)
        } else if let tag = tabTag {
            self._paletteIndex = State(initialValue: abs(tag) % Self.palettes.count)
        } else {
            self._paletteIndex = State(initialValue: Int.random(in: 0..<Self.palettes.count))
        }
        self.paletteTrigger = paletteTrigger
        self.tabTag = tabTag
    }

    var body: some View {
        let palette = Self.palettes[paletteIndex]
        let topStrength: Double = colorScheme == .dark ? 0.56 : 0.34
        let upperMidStrength: Double = colorScheme == .dark ? 0.32 : 0.19
        let lowerMidStrength: Double = colorScheme == .dark ? 0.12 : 0.06

        ZStack {
            // Base canvas color
            Color.themeBg
                .ignoresSafeArea()

            // Spotify-style calm top-down saturation falloff
            LinearGradient(
                stops: [
                    .init(color: palette.primary.opacity(topStrength), location: 0.00),
                    .init(color: palette.secondary.opacity(upperMidStrength), location: 0.22),
                    .init(color: palette.secondary.opacity(lowerMidStrength), location: 0.44),
                    .init(color: palette.primary.opacity(0.0), location: 0.68),
                    .init(color: Color.clear, location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Subtle zenith sheen to softly anchor the navigation area
            RadialGradient(
                colors: [
                    palette.primary.opacity(colorScheme == .dark ? 0.20 : 0.12),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 20,
                endRadius: 340
            )
            .ignoresSafeArea()
        }
        .onAppear {
            if tabTag == nil {
                paletteIndex = (paletteIndex + 1) % Self.palettes.count
            }
        }
        .onChange(of: paletteTrigger) { _, newValue in
            guard tabTag == nil || newValue == tabTag else { return }
            let nextIndex = (paletteIndex + 1) % Self.palettes.count
            if reduceMotion {
                paletteIndex = nextIndex
            } else {
                withAnimation(.easeInOut(duration: 0.9)) {
                    paletteIndex = nextIndex
                }
            }
        }
    }
}
