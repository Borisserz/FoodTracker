import SwiftUI

// MARK: - Premium Background
struct AuroraBackground: View {
    @State private var animate = false

    private struct Orb: Identifiable {
        let id = UUID()
        let color: Color
        let size: CGFloat
        let from: CGSize
        let to: CGSize
    }

    private let orbs: [Orb] = [
        .init(color: .themePink, size: 320, from: .init(width: -120, height: -260), to: .init(width: -60,  height: -200)),
        .init(color: .themeOrange, size: 300, from: .init(width:  140, height: -110), to: .init(width:  90,  height:  -50)),
        .init(color: .themePeach, size: 280, from: .init(width:  -80, height:  260), to: .init(width: -140, height:  200))
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.11, blue: 0.20),
                         Color(red: 0.20, green: 0.16, blue: 0.34)],
                startPoint: .top, endPoint: .bottom
            )
            ForEach(orbs) { orb in
                Circle()
                    .fill(orb.color.opacity(0.35))
                    .frame(width: orb.size, height: orb.size)
                    .blur(radius: 90)
                    .offset(animate ? orb.to : orb.from)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { animate = true }
        }
    }
}

// MARK: - Buttons
struct OnboardingButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .medium)
            action()
        }) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(isDisabled ? Color.white.opacity(0.3) : .black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isDisabled 
                        ? AnyShapeStyle(Color.white.opacity(0.1)) 
                        : AnyShapeStyle(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .top, endPoint: .bottom))
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: isDisabled ? .clear : .white.opacity(0.3), radius: 10, y: 5)
        }
        .disabled(isDisabled)
        .buttonStyle(BouncyButtonStyle())
    }
}

struct GhostAuthButtonStyle: ButtonStyle {
    var width: CGFloat
    var height: CGFloat
    var corner: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: width)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Wheel Picker
struct OnboardingWheelColumn: View {
    let title: String
    let range: ClosedRange<Int>
    let suffix: String
    @Binding var selection: Int

    var body: some View {
        VStack(spacing: -10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 10)
            
            Picker(title, selection: $selection) {
                ForEach(range, id: \.self) { value in
                    Text("\(value) \(suffix)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .tag(value)
                }
            }
            .pickerStyle(.wheel)
        }
        .frame(maxWidth: .infinity)
    }
}
