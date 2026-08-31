import SwiftUI
import UIKit

struct SwissTapeRuler: View {
    let title: String
    let unit: String
    let range: ClosedRange<Int>
    @Binding var value: Int
    
    @State private var dragOffset: CGFloat = 0.0
    @State private var initialValueOnDrag: Int = 0
    
    private let stepWidth: CGFloat = 16.0
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with Value Display
            HStack(alignment: .firstTextBaseline) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("\(value)")
                        .font(.system(size: 32, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.swissChartreuse)
                        .contentTransition(.numericText())
                    
                    Text(unit)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 4)
            
            // Tape Ruler Viewport
            ZStack(alignment: .center) {
                // Background groove
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.swissCardElevated)
                    .frame(height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.swissBorder, lineWidth: 1)
                    )
                
                // Tick Marks Canvas
                GeometryReader { geo in
                    let center = geo.size.width / 2
                    
                    HStack(spacing: stepWidth - 2) {
                        ForEach(range, id: \.self) { tick in
                            let isMajor = tick % 5 == 0
                            let isSuperMajor = tick % 10 == 0
                            
                            VStack(spacing: 4) {
                                Rectangle()
                                    .fill(
                                        tick == value
                                            ? Color.swissChartreuse
                                            : (isSuperMajor ? Color.white.opacity(0.8) : (isMajor ? Color.white.opacity(0.4) : Color.white.opacity(0.2)))
                                    )
                                    .frame(width: tick == value ? 3 : (isMajor ? 2 : 1), height: isSuperMajor ? 26 : (isMajor ? 18 : 12))
                                    .cornerRadius(1)
                                
                                if isSuperMajor {
                                    Text("\(tick)")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                            .frame(width: 2)
                        }
                    }
                    .offset(x: center - CGFloat(value - range.lowerBound) * stepWidth + dragOffset)
                }
                .frame(height: 70)
                .clipped()
                
                // Central Chartreuse Pointer Needle & Lens
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.swissChartreuse)
                        .frame(width: 3, height: 40)
                        .shadow(color: Color.swissChartreuseGlow, radius: 8, y: 0)
                    
                    Circle()
                        .fill(Color.swissChartreuse)
                        .frame(width: 6, height: 6)
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if initialValueOnDrag == 0 {
                            initialValueOnDrag = value
                        }
                        
                        let deltaSteps = Int(-gesture.translation.width / stepWidth)
                        let targetValue = max(range.lowerBound, min(range.upperBound, initialValueOnDrag + deltaSteps))
                        
                        if targetValue != value {
                            value = targetValue
                            let generator = UISelectionFeedbackGenerator()
                            generator.prepare()
                            generator.selectionChanged()
                        }
                        
                        let remainder = gesture.translation.width.truncatingRemainder(dividingBy: stepWidth)
                        dragOffset = remainder
                    }
                    .onEnded { _ in
                        initialValueOnDrag = 0
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
            )
        }
        .padding(16)
        .background(Color.swissCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.swissBorder, lineWidth: 1)
        )
    }
}
