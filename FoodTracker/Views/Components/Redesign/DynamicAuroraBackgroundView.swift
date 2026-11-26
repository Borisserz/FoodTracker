import SwiftUI

// MARK: - Dynamic Aurora Background (Apple HIG Atmospheric Mood System)
struct DynamicAuroraBackgroundView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0.0
    @State private var paletteIndex: Int
    private let paletteTrigger: Int
    private let tabTag: Int?
    
    // Curated Luxury Fitness & Wellness Palettes (Apple HIG / OLED Optimized)
    private static let palettes: [[Color]] = [
        // 0: Emerald Vitality (Health & Freshness)
        [Color(red: 0.08, green: 0.65, blue: 0.45), Color(red: 0.15, green: 0.85, blue: 0.60)],
        // 1: Twilight Lavender & Slate (Proactive Intelligence)
        [Color(red: 0.35, green: 0.55, blue: 0.95), Color(red: 0.65, green: 0.45, blue: 0.92)],
        // 2: Warm Golden Amber (Sunrise & Energy)
        [Color(red: 0.98, green: 0.65, blue: 0.15), Color(red: 0.95, green: 0.40, blue: 0.20)],
        // 3: Nordic Indigo & Arctic Cyan (Calm Recovery & Focus)
        [Color(red: 0.38, green: 0.35, blue: 0.92), Color(red: 0.18, green: 0.72, blue: 0.95)],
        // 4: Warm Cashmere Terracotta (Natural Satiety & Earth)
        [Color(red: 0.90, green: 0.50, blue: 0.35), Color(red: 0.85, green: 0.35, blue: 0.45)]
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
        let colors = Self.palettes[paletteIndex]
        
        ZStack {
            // OLED Canvas Background
            Color.themeBg
                .ignoresSafeArea()
            
            // Floating Ambient Light Orbs
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                
                ZStack {
                    // Top-Left Primary Orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [colors[0].opacity(0.14), colors[0].opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            )
                        )
                        .frame(width: w * 0.95, height: w * 0.95)
                        .blur(radius: 75)
                        .offset(
                            x: -w * 0.25 + (phase == 0 ? -20 : 30),
                            y: -h * 0.18 + (phase == 0 ? -30 : 25)
                        )
                    
                    // Bottom-Right Complementary Orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [colors[1].opacity(0.12), colors[1].opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 190
                            )
                        )
                        .frame(width: w * 0.90, height: w * 0.90)
                        .blur(radius: 80)
                        .offset(
                            x: w * 0.30 + (phase == 0 ? 25 : -25),
                            y: h * 0.20 + (phase == 0 ? 30 : -30)
                        )
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            if tabTag == nil {
                paletteIndex = (paletteIndex + 1) % Self.palettes.count
            }
            
            guard !reduceMotion, phase == 0.0 else { return }
            withAnimation(.easeInOut(duration: 7.5).repeatForever(autoreverses: true)) {
                phase = 1.0
            }
        }
        .onChange(of: paletteTrigger) { _, newValue in
            guard tabTag == nil || newValue == tabTag else { return }
            let nextIndex = (paletteIndex + 1) % Self.palettes.count
            if reduceMotion {
                paletteIndex = nextIndex
            } else {
                withAnimation(.easeInOut(duration: 0.85)) {
                    paletteIndex = nextIndex
                }
            }
        }
    }
}
