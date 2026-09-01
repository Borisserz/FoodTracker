import SwiftUI

struct MicronutrientsView: View {
    let meal: Meal

    private let targetOmega3: Double = 1.6
    private let targetPotassium: Double = 3500
    private let targetMagnesium: Double = 400

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {

                ZStack {
                    ActivityRing(progress: meal.totalOmega3 / targetOmega3, color: .themePink, radius: 100, thickness: 16)
                    ActivityRing(progress: meal.totalPotassium / targetPotassium, color: .themeYellow, radius: 76, thickness: 16)
                    ActivityRing(progress: meal.totalMagnesium / targetMagnesium, color: .themeOrange, radius: 52, thickness: 16)

                    VStack {
                        Image(systemName: "sparkles")
                            .font(.largeTitle)
                            .foregroundStyle(.linearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom))
                        Text("Vitamins").font(.caption).foregroundColor(.gray)
                    }
                }
                .padding(.top, 20)

                HStack(spacing: 20) {
                    RingLegend(color: .themePink, title: "Omega-3", value: meal.totalOmega3, unit: "g")
                    RingLegend(color: .themeYellow, title: "Potassium", value: meal.totalPotassium, unit: "mg")
                    RingLegend(color: .themeOrange, title: "Magnesium", value: meal.totalMagnesium, unit: "mg")
                }

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Text("Minerals & Vitamins").font(.title3).bold()

                    NutrientRow(icon: "bone.fill", title: "Calcium", value: meal.totalCalcium, unit: "mg", color: .drinkWater)
                    NutrientRow(icon: "drop.degreesign.fill", title: "Iron", value: meal.totalIron, unit: "mg", color: .red.opacity(0.7))
                    NutrientRow(icon: "sun.max.fill", title: "Vitamin C", value: meal.totalVitaminC, unit: "mg", color: .themeOrange)
                    NutrientRow(icon: "sun.haze.fill", title: "Vitamin D", value: meal.totalVitaminD, unit: "mcg", color: .themeYellow)
                }
                .premiumCardStyle()

            }
            .padding()
        }
        .background(Color.themeBg)
        .navigationTitle("Micronutrients")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct NutrientRow: View {
    let icon: String; let title: String; let value: Double; let unit: String; let color: Color
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).font(.headline).frame(width: 30)
            Text(title).font(.subheadline)
            Spacer()
            Text("\(value, specifier: "%.1f") \(unit)").font(.subheadline.bold()).foregroundColor(.primary.opacity(0.8))
        }
    }
}

private struct ActivityRing: View {
    let progress: Double; let color: Color; let radius: CGFloat; let thickness: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: thickness)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: radius * 2, height: radius * 2)
        .animation(.spring(response: 0.8), value: progress)
    }
}

private struct RingLegend: View {
    let color: Color; let title: String; let value: Double; let unit: String
    var body: some View {
        VStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.caption).foregroundColor(.gray)
            Text("\(value, specifier: "%.1f")\(unit)").font(.subheadline).bold()
        }
    }
}

