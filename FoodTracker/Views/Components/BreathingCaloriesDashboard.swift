import SwiftUI
struct EatenCaloriesRing: View {
    let consumed: Int
    let target: Int
    let protein: Double
    let fats: Double
    let carbs: Double

    @State private var animC: Double = 0
    @State private var animF: Double = 0
    @State private var animP: Double = 0

    private var eatenFrac: Double {
        min(Double(consumed) / Double(max(target, 1)), 1.0)
    }

    private var macroCals: Double {
        max(protein * 4.0 + fats * 9.0 + carbs * 4.0, 1.0)
    }

    // Portions of the *eaten* calories coming from each macro (so the three colors always sum exactly to eatenFrac)
    private var cPortion: Double { (carbs * 4.0) / macroCals }
    private var fPortion: Double { (fats * 9.0) / macroCals }
    private var pPortion: Double { (protein * 4.0) / macroCals }

    // Cumulative positions on the ring (0...eatenFrac)
    private var cEnd: Double { eatenFrac * cPortion }
    private var fEnd: Double { eatenFrac * (cPortion + fPortion) }
    private var pEnd: Double { eatenFrac } // full eaten progress

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15).shadow(.inner(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)), lineWidth: 24)

                // Only the three macro colors — no ugly gray "other" segment
                Circle()
                    .trim(from: 0, to: min(animC, 1.0))
                    .stroke(Color.drinkWater, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.drinkWater.opacity(0.4), radius: 8)

                Circle()
                    .trim(from: min(animC, 1.0), to: min(animF, 1.0))
                    .stroke(Color.themeYellow, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.themeYellow.opacity(0.4), radius: 8)

                Circle()
                    .trim(from: min(animF, 1.0), to: min(animP, 1.0))
                    .stroke(Color.themePeach, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.themePeach.opacity(0.4), radius: 8)

                VStack(spacing: 6) {
                    Text("\(consumed)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundColor(consumed > target ? .red : .primary)
                        .contentTransition(.numericText())

                    Text("kcal eaten")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.textGray)

                    Text("Goal: \(target)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.textGray)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(consumed) calories eaten out of \(target) goal")
                .accessibilityValue("Progress ring showing macro breakdown")
            }
            .frame(width: 240, height: 240)
            .padding(.top, 10)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) {
                    animC = cEnd
                    animF = fEnd
                    animP = pEnd
                }
            }
        }
    }
}
struct BurnedCaloriesRing: View {
    let burned: Int

    let targetBurn: Int

    @State private var animProgress: Double = 0

    var body: some View {
        let progress = Double(burned) / Double(max(targetBurn, 1))

        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15).shadow(.inner(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)), lineWidth: 24)

            Circle()
                .trim(from: 0, to: min(animProgress, 1.0))
                .stroke(LinearGradient(colors: [.themeOrange, .red], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.themeOrange.opacity(0.5), radius: 10)

            VStack(spacing: 6) {
                Text("\(burned)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundColor(.themeOrange)
                    .contentTransition(.numericText())

                Text("kcal burned")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.textGray)

                Text("Goal: \(targetBurn)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.textGray)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(burned) calories burned, goal \(targetBurn)")
        }
        .frame(width: 240, height: 240)
        .padding(.top, 10)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animProgress = progress
            }
        }
    }
}

struct NetCaloriesRing: View {
    let net: Int
    let target: Int

    @State private var animProgress: Double = 0

    var body: some View {
        let isOver = net > target
        let progress = Double(net) / Double(max(target, 1))
        let ringColor = isOver ? Color.red : Color.green

        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15).shadow(.inner(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)), lineWidth: 24)

            Circle()
                .trim(from: 0, to: min(animProgress, 1.0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.5), radius: 10)

            VStack(spacing: 6) {
                Text("\(net)")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundColor(ringColor)
                    .contentTransition(.numericText())

                Text("net kcal")
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.textGray)

                let remaining = target - net
                Text(remaining >= 0 ? "\(remaining) left" : "\(abs(remaining)) over")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(ringColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(ringColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Net \(net) calories, \(remaining >= 0 ? "\(remaining) left" : "\(abs(remaining)) over goal")")
        }
        .frame(width: 240, height: 240)
        .padding(.top, 10)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animProgress = abs(progress)
            }
        }
    }
}

// Example preview (per system-rules + swiftui-pro: previews should be present; for complex views we inject mock DI + ModelContainer)
#Preview {
    VStack(spacing: 40) {
        EatenCaloriesRing(
            consumed: 1650,
            target: 2200,
            protein: 130,
            fats: 55,
            carbs: 165
        )

        BurnedCaloriesRing(
            burned: 480,
            targetBurn: 600
        )

        NetCaloriesRing(
            net: 1170,
            target: 1600
        )
    }
    .padding()
    .background(Color(white: 0.97))
    .preferredColorScheme(.light)
}
