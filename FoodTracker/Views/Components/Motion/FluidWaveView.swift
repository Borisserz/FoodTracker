import SwiftUI

// MARK: - Fluid Harmonic Wave View
public struct FluidWaveView: View {
    public var progress: Double // 0.0 to 1.0
    public var waveColor: Color
    public var secondaryWaveColor: Color
    public var isInteractive: Bool
    
    @State private var phase: Double = 0
    @State private var bubbleOffsets: [BubbleState] = (0..<8).map { _ in
        BubbleState(
            xProgress: Double.random(in: 0.1...0.9),
            yProgress: Double.random(in: 0.2...0.9),
            size: CGFloat.random(in: 4...9),
            speed: Double.random(in: 1.5...3.5)
        )
    }
    
    public init(
        progress: Double,
        waveColor: Color = Color(red: 0.0, green: 0.72, blue: 0.96),
        secondaryWaveColor: Color = Color(red: 0.0, green: 0.50, blue: 0.85).opacity(0.45),
        isInteractive: Bool = true
    ) {
        self.progress = max(0.02, min(1.0, progress))
        self.waveColor = waveColor
        self.secondaryWaveColor = secondaryWaveColor
        self.isInteractive = isInteractive
    }
    
    public var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let fillHeight = height * CGFloat(progress)
                let baseWaterLevel = height - fillHeight
                
                ZStack {
                    // Back Wave
                    HarmonicWaveShape(
                        phase: time * 1.6,
                        amplitude: 6.0,
                        wavelength: width * 0.85,
                        waterLevel: baseWaterLevel + 3
                    )
                    .fill(secondaryWaveColor)
                    
                    // Front Wave
                    HarmonicWaveShape(
                        phase: time * 2.2,
                        amplitude: 8.0,
                        wavelength: width * 0.7,
                        waterLevel: baseWaterLevel
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                waveColor.opacity(0.85),
                                waveColor.opacity(0.95),
                                waveColor.opacity(0.65)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Ascending Bubbles
                    ForEach(bubbleOffsets.indices, id: \.self) { idx in
                        let b = bubbleOffsets[idx]
                        let bubbleY = (baseWaterLevel + (fillHeight * CGFloat(b.yProgress)) - CGFloat(time * 20 * b.speed).truncatingRemainder(dividingBy: fillHeight))
                        
                        Circle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: b.size, height: b.size)
                            .position(x: width * CGFloat(b.xProgress) + sin(time * 3 + Double(idx)) * 6, y: max(baseWaterLevel + 4, bubbleY))
                    }
                }
            }
        }
        .clipped()
    }
}

// MARK: - Bubble State
private struct BubbleState {
    var xProgress: Double
    var yProgress: Double
    var size: CGFloat
    var speed: Double
}

// MARK: - Procedural Harmonic Wave Shape
private struct HarmonicWaveShape: Shape {
    var phase: Double
    var amplitude: CGFloat
    var wavelength: CGFloat
    var waterLevel: CGFloat
    
    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: waterLevel))
        
        for x in stride(from: 0, through: width + 5, by: 4) {
            let relativeX = x / wavelength
            let sine = sin(relativeX * 2 * .pi + phase)
            let y = waterLevel + amplitude * CGFloat(sine)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}
