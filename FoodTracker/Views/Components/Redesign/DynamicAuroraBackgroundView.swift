import SwiftUI

// MARK: - Spotify-Style Vertical Tonal Wash Background (Calm Top-to-Bottom Saturation Falloff)
struct DynamicAuroraBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var paletteIndex: Int
    private let paletteTrigger: Int
    private let tabTag: Int?
    private let pinnedPaletteIndex: Int?
    private let forceDarkCanvas: Bool

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

    init(
        seed: Int? = nil,
        paletteTrigger: Int = 0,
        tabTag: Int? = nil,
        pinnedPaletteIndex: Int? = nil,
        darkCanvas: Bool = false
    ) {
        if let pinned = pinnedPaletteIndex {
            self._paletteIndex = State(initialValue: abs(pinned) % Self.palettes.count)
        } else if let s = seed {
            self._paletteIndex = State(initialValue: abs(s) % Self.palettes.count)
        } else if let tag = tabTag {
            self._paletteIndex = State(initialValue: abs(tag) % Self.palettes.count)
        } else {
            self._paletteIndex = State(initialValue: Int.random(in: 0..<Self.palettes.count))
        }
        self.paletteTrigger = paletteTrigger
        self.tabTag = tabTag
        self.pinnedPaletteIndex = pinnedPaletteIndex
        self.forceDarkCanvas = darkCanvas
    }

    var body: some View {
        let resolvedIndex = pinnedPaletteIndex.map { abs($0) % Self.palettes.count } ?? paletteIndex
        let palette = Self.palettes[resolvedIndex]
        let isDarkSurface = forceDarkCanvas || colorScheme == .dark
        let topStrength: Double = isDarkSurface ? 0.50 : 0.34
        let upperMidStrength: Double = isDarkSurface ? 0.28 : 0.19
        let lowerMidStrength: Double = isDarkSurface ? 0.10 : 0.06
        let canvasColor: Color = forceDarkCanvas ? Color(hex: 0x111315) : Color.themeBg

        ZStack {
            // Base canvas color
            canvasColor
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
                    palette.primary.opacity(isDarkSurface ? 0.18 : 0.12),
                    Color.clear
                ],
                center: UnitPoint(x: 0.5, y: -0.05),
                startRadius: 20,
                endRadius: 340
            )
            .ignoresSafeArea()
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.65), value: resolvedIndex)
        .onAppear {
            if pinnedPaletteIndex == nil && tabTag == nil {
                paletteIndex = (paletteIndex + 1) % Self.palettes.count
            }
        }
        .onChange(of: paletteTrigger) { _, newValue in
            guard pinnedPaletteIndex == nil else { return }
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
