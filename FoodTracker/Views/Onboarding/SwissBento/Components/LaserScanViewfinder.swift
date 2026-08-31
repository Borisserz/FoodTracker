import SwiftUI

struct LaserScanViewfinder: View {
    @State private var laserProgress: CGFloat = 0.0
    @State private var isPulsing: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                // Viewfinder Dark Frame
                ZStack {
                    Color(red: 0.04, green: 0.05, blue: 0.05)
                    
                    // Stylized Food Illustration / Visual
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.04))
                            .frame(width: 170, height: 170)
                        
                        // Food Icons Arrangement
                        HStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundStyle(Color.swissChartreuse)
                                Text("Salmon")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            
                            VStack(spacing: 8) {
                                Image(systemName: "leaf.circle.fill")
                                    .font(.system(size: 38))
                                    .foregroundStyle(Color.swissCyan)
                                Text("Avocado")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            
                            VStack(spacing: 8) {
                                Image(systemName: "chart.pie.fill")
                                    .font(.system(size: 38))
                                    .foregroundStyle(Color.swissCoral)
                                Text("Quinoa")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    
                    // High-Tech Horizontal Grid Scan Lines
                    GeometryReader { geo in
                        VStack(spacing: 4) {
                            ForEach(0..<Int(geo.size.height / 6), id: \.self) { _ in
                                Rectangle()
                                    .fill(Color.swissChartreuse.opacity(0.05))
                                    .frame(height: 1)
                            }
                        }
                        
                        // Moving Neon Laser Bar
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, Color.swissChartreuse.opacity(0.9), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 3)
                            .shadow(color: Color.swissChartreuse, radius: 8, y: 0)
                            .offset(y: laserProgress * geo.size.height)
                    }
                    
                    // Reticle Corner Brackets
                    GeometryReader { geo in
                        let s: CGFloat = 16
                        // Top Left
                        Path { path in
                            path.move(to: CGPoint(x: 12, y: 12 + s))
                            path.addLine(to: CGPoint(x: 12, y: 12))
                            path.addLine(to: CGPoint(x: 12 + s, y: 12))
                        }.stroke(Color.swissChartreuse, lineWidth: 2)
                        
                        // Top Right
                        Path { path in
                            path.move(to: CGPoint(x: geo.size.width - 12 - s, y: 12))
                            path.addLine(to: CGPoint(x: geo.size.width - 12, y: 12))
                            path.addLine(to: CGPoint(x: geo.size.width - 12, y: 12 + s))
                        }.stroke(Color.swissChartreuse, lineWidth: 2)
                        
                        // Bottom Left
                        Path { path in
                            path.move(to: CGPoint(x: 12, y: geo.size.height - 12 - s))
                            path.addLine(to: CGPoint(x: 12, y: geo.size.height - 12))
                            path.addLine(to: CGPoint(x: 12 + s, y: geo.size.height - 12))
                        }.stroke(Color.swissChartreuse, lineWidth: 2)
                        
                        // Bottom Right
                        Path { path in
                            path.move(to: CGPoint(x: geo.size.width - 12 - s, y: geo.size.height - 12))
                            path.addLine(to: CGPoint(x: geo.size.width - 12, y: geo.size.height - 12))
                            path.addLine(to: CGPoint(x: geo.size.width - 12, y: geo.size.height - 12 - s))
                        }.stroke(Color.swissChartreuse, lineWidth: 2)
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                
                // Bottom Gradient Scrim with OCR Recognized Data
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.swissChartreuse)
                            .frame(width: 6, height: 6)
                            .scaleEffect(isPulsing ? 1.4 : 1.0)
                        Text("AI NEURAL SCAN • 99.4%")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.swissChartreuse)
                    }
                    
                    Text("Salmon Avocado Bowl")
                        .font(.system(size: 17, weight: .black, design: .default))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        SwissTagBadge(text: "580 KCAL", color: .swissChartreuse)
                        SwissTagBadge(text: "38G PRO", color: .swissCyan)
                        SwissTagBadge(text: "22G FAT", color: .swissCoral)
                    }
                }
                .padding(14)
            }
        }
        .background(Color.swissCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.swissBorder, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                laserProgress = 1.0
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
