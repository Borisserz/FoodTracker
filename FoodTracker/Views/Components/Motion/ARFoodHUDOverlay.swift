import SwiftUI

// MARK: - AR HUD Food Vision Scanner Overlay
public struct ARFoodHUDOverlay: View {
    @State private var scanLineOffset: CGFloat = -140
    @State private var reticleRotation: Double = 0
    @State private var calloutsAppeared = false
    
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.40)
            let boxSize: CGFloat = min(geo.size.width * 0.78, 290)
            
            ZStack {
                // Dim camera edges vignette
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.45)],
                    center: .center,
                    startRadius: boxSize * 0.4,
                    endRadius: geo.size.width * 0.8
                )
                .ignoresSafeArea()
                
                // MARK: 1. Four Corner Viewfinder Brackets
                ViewfinderBracketsShape(boxSize: boxSize)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan, Color(red: 0.18, green: 0.86, blue: 0.38)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3.0
                    )
                    .frame(width: boxSize, height: boxSize)
                    .position(center)
                    .shadow(color: Color.cyan.opacity(0.6), radius: 8)
                
                // MARK: 2. Rotating Radar Reticle in Center
                ZStack {
                    Circle()
                        .strokeBorder(Color.cyan.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
                        .frame(width: boxSize * 0.65, height: boxSize * 0.65)
                        .rotationEffect(.degrees(reticleRotation))
                    
                    Circle()
                        .strokeBorder(Color.green.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [8, 12]))
                        .frame(width: boxSize * 0.45, height: boxSize * 0.45)
                        .rotationEffect(.degrees(-reticleRotation * 1.5))
                    
                    // Crosshair tick marks
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .light))
                        .foregroundStyle(Color.cyan.opacity(0.7))
                }
                .position(center)
                
                // MARK: 3. Sweeping Laser Scan Line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.cyan.opacity(0.85),
                                Color(red: 0.18, green: 0.86, blue: 0.38),
                                Color.cyan.opacity(0.85),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: boxSize - 16, height: 2.5)
                    .shadow(color: Color.cyan, radius: 6)
                    .position(x: center.x, y: center.y + scanLineOffset)
                
                // MARK: 4. Floating AR Nutrient Callout Badges
                if calloutsAppeared {
                    // Top-Left: Protein Badge
                    ARNutrientBadge(
                        title: "БЕЛКИ",
                        value: "+32г",
                        color: Color.cyan,
                        icon: "figure.strengthtraining.traditional"
                    )
                    .position(x: center.x - boxSize * 0.42, y: center.y - boxSize * 0.52)
                    .transition(.scale.combined(with: .opacity))
                    
                    // Top-Right: Healthy Fats Badge
                    ARNutrientBadge(
                        title: "ПОЛЕЗНЫЕ ЖИРЫ",
                        value: "+18г",
                        color: Color.green,
                        icon: "leaf.fill"
                    )
                    .position(x: center.x + boxSize * 0.42, y: center.y - boxSize * 0.52)
                    .transition(.scale.combined(with: .opacity))
                    
                    // Bottom-Right: Complex Carbs Badge
                    ARNutrientBadge(
                        title: "УГЛЕВОДЫ",
                        value: "+24г",
                        color: Color.orange,
                        icon: "bolt.fill"
                    )
                    .position(x: center.x + boxSize * 0.42, y: center.y + boxSize * 0.48)
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Top Telemetry Header
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text("AI VISION: LIVE ANALYSIS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        
                        Spacer()
                        
                        Text("99.4% CONFIDENCE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 24)
                .position(x: geo.size.width / 2, y: geo.size.height * 0.12)
            }
        }
        .onAppear {
            // Sweep laser scan line up and down
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                scanLineOffset = 140
            }
            // Rotate radar reticle
            withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
                reticleRotation = 360
            }
            // Pop in badges with slight delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    calloutsAppeared = true
                }
            }
        }
    }
}

// MARK: - AR Callout Badge
private struct ARNutrientBadge: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.8))
                
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(color.opacity(0.6), lineWidth: 1.2)
        )
        .shadow(color: color.opacity(0.3), radius: 6, y: 2)
    }
}

// MARK: - Corner Viewfinder Brackets Shape
private struct ViewfinderBracketsShape: Shape {
    let boxSize: CGFloat
    let cornerLength: CGFloat = 26
    
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let minX = rect.minX
        let maxX = rect.maxX
        let minY = rect.minY
        let maxY = rect.maxY
        
        // Top-Left
        p.move(to: CGPoint(x: minX, y: minY + cornerLength))
        p.addLine(to: CGPoint(x: minX, y: minY))
        p.addLine(to: CGPoint(x: minX + cornerLength, y: minY))
        
        // Top-Right
        p.move(to: CGPoint(x: maxX - cornerLength, y: minY))
        p.addLine(to: CGPoint(x: maxX, y: minY))
        p.addLine(to: CGPoint(x: maxX, y: minY + cornerLength))
        
        // Bottom-Left
        p.move(to: CGPoint(x: minX, y: maxY - cornerLength))
        p.addLine(to: CGPoint(x: minX, y: maxY))
        p.addLine(to: CGPoint(x: minX + cornerLength, y: maxY))
        
        // Bottom-Right
        p.move(to: CGPoint(x: maxX - cornerLength, y: maxY))
        p.addLine(to: CGPoint(x: maxX, y: maxY))
        p.addLine(to: CGPoint(x: maxX, y: maxY - cornerLength))
        
        return p
    }
}
