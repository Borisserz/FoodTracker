import SwiftUI

struct FoodDetailNutritionView: View {
    @Environment(\.dismiss) private var dismiss

    let food: FoodItem
    let mealTitle: String
    var onAdd: (FoodItem) -> Void

    @State private var weight: Double

    init(food: FoodItem, mealTitle: String, onAdd: @escaping (FoodItem) -> Void) {
        self.food = food
        self.mealTitle = mealTitle
        self.onAdd = onAdd
        self._weight = State(initialValue: food.weight > 0 ? food.weight : 100.0)
    }

    private var multiplier: Double { weight / max(food.weight, 1.0) }
    private var currentCals: Int { Int(Double(food.calories) * multiplier) }
    private var currentP: Double { food.protein * multiplier }
    private var currentF: Double { food.fats * multiplier }
    private var currentC: Double { food.carbs * multiplier }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    VStack(spacing: 0) {
                        FoodDetailHeader(name: food.name)

                        MacroDonutChartCard(
                            calories: currentCals,
                            p: currentP,
                            f: currentF,
                            c: currentC
                        )
                        .padding(.horizontal, 20)
                        .offset(y: -40)
                        .padding(.bottom, -40)
                    }

                    ServingSizeEditor(weight: $weight)
                        .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("Nutrition Facts")
                            .font(.title3.bold())
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                        VStack(spacing: 0) {
                            NutritionRow(title: "Proteins", value: currentP, unit: "g")
                            NutritionRow(title: "Total Fat", value: currentF, unit: "g")
                            NutritionRow(title: "Carbs", value: currentC, unit: "g")

                            NutritionSectionHeader(title: "Vitamins & Minerals")

                            NutritionRow(title: "Vitamin C", value: food.vitaminC * multiplier, unit: "mg", isPro: true)
                            NutritionRow(title: "Vitamin D", value: food.vitaminD * multiplier, unit: "mcg", isPro: true)
                            NutritionRow(title: "Calcium", value: food.calcium * multiplier, unit: "mg", isPro: true)
                            NutritionRow(title: "Iron", value: food.iron * multiplier, unit: "mg", isPro: true)
                            NutritionRow(title: "Magnesium", value: food.magnesium * multiplier, unit: "mg", isPro: true)
                            NutritionRow(title: "Potassium", value: food.potassium * multiplier, unit: "mg", isPro: true)
                            NutritionRow(title: "Omega-3", value: food.omega3 * multiplier, unit: "g", isPro: true)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(24)
                        .padding(.horizontal, 20)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                    }

                    Spacer().frame(height: 100)
                }
            }
            .ignoresSafeArea(edges: .top)

            VStack {
                Spacer()
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 110)
                        .mask(LinearGradient(colors: [.white, .white, .clear], startPoint: .bottom, endPoint: .top))

                    Button(action: {
                        HapticManager.shared.impact(style: .heavy)
                        let addedFood = FoodItem(
                            name: food.name,
                            weight: weight,
                            calories: currentCals,
                            protein: currentP,
                            fats: currentF,
                            carbs: currentC,
                            omega3: food.omega3 * multiplier,
                            calcium: food.calcium * multiplier,
                            potassium: food.potassium * multiplier,
                            magnesium: food.magnesium * multiplier,
                            iron: food.iron * multiplier,
                            vitaminC: food.vitaminC * multiplier,
                            vitaminD: food.vitaminD * multiplier
                        )
                        onAdd(addedFood)
                        dismiss()
                    }) {
                        HStack {
                            Text("Add to \(mealTitle)")
                                .font(.headline)
                            Spacer()
                            Text("\(currentCals) kcal")
                                .font(.headline.bold())
                                .contentTransition(.numericText())
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.themePink)
                        .cornerRadius(16)
                        .shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                    }
                    .buttonStyle(BounceButtonStyle())
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarHidden(true)
    }
}

private struct FoodDetailHeader: View {
    @Environment(\.dismiss) var dismiss
    @State private var isFavorite = false

    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.2))
                        .clipShape(Circle())
                }
                Spacer()
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.spring()) { isFavorite.toggle() }
                }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundColor(isFavorite ? .themeYellow : .white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.top, 50)

            Text(name)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.bottom, 50)
        }
        .padding(.horizontal, 20)
        .background(
            LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
        )

        .clipShape(RoundedCorner(radius: 32, corners: [.bottomLeft, .bottomRight]))
        .shadow(color: Color.themePink.opacity(0.3), radius: 15, y: 10)
    }
}

private struct MacroDonutChartCard: View {
    let calories: Int
    let p: Double
    let f: Double
    let c: Double

    @State private var showAnimation = false

    private var totalMacroCals: Double {
        max((p * 4) + (f * 9) + (c * 4), 1.0)
    }

    private var cPercent: Double { (c * 4) / totalMacroCals }
    private var fPercent: Double { (f * 9) / totalMacroCals }
    private var pPercent: Double { (p * 4) / totalMacroCals }

    var body: some View {
        HStack(spacing: 16) {

            ZStack {

                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: showAnimation ? cPercent : 0)
                    .stroke(Color.drinkWater, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: showAnimation ? cPercent : 0, to: showAnimation ? (cPercent + fPercent) : 0)
                    .stroke(Color.themeYellow, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Circle()
                    .trim(from: showAnimation ? (cPercent + fPercent) : 0, to: showAnimation ? 1.0 : 0)
                    .stroke(Color.themePeach, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(calories)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    Text("cal")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 80, height: 80)

            Spacer()

            HStack(spacing: 16) {
                MacroColumnInfo(percent: cPercent, grams: c, title: "Carbs", color: .drinkWater)
                MacroColumnInfo(percent: fPercent, grams: f, title: "Fat", color: .themeYellow)
                MacroColumnInfo(percent: pPercent, grams: p, title: "Protein", color: .themePeach)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.06), radius: 15, y: 8)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    showAnimation = true
                }
            }
        }

        .onChange(of: calories) { _, _ in
            showAnimation = false
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                showAnimation = true
            }
        }
    }
}

private struct MacroColumnInfo: View {
    let percent: Double
    let grams: Double
    let title: String
    let color: Color

    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("\(Int(percent * 100))%")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)

            Text("\(grams, specifier: "%.1f") g")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .contentTransition(.numericText())

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(minWidth: 50)
    }
}

private struct ServingSizeEditor: View {
    @Binding var weight: Double
    @State private var textInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Serving Size")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                Spacer()
                
                HStack(spacing: 4) {
                    TextField("100", text: $textInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.themePink)
                        .frame(width: 80)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color.themeBg.opacity(0.5))
                        .cornerRadius(10)
                        .onChange(of: textInput) { _, newValue in
                            if let val = Double(newValue), val > 0 {
                                weight = val
                            }
                        }
                    
                    Text("g")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }

            Slider(value: $weight, in: 5...1000, step: 5)
                .tint(.themePink)
                .onChange(of: weight) { _, newValue in
                    let newText = String(format: "%.0f", newValue)
                    if textInput != newText {
                        textInput = newText
                    }
                }
            
            HStack(spacing: 12) {
                ForEach([50, 100, 150, 200, 300], id: \.self) { amount in
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            weight = Double(amount)
                            textInput = "\(amount)"
                        }
                    }) {
                        Text("\(amount)g")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(weight == Double(amount) ? Color.themePink : Color.gray.opacity(0.05))
                            .foregroundColor(weight == Double(amount) ? .white : .primary)
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
        .onAppear {
            textInput = String(format: "%.0f", weight)
        }
    }
}

private struct NutritionRow: View {
    let title: String
    let value: Double
    let unit: String
    var isPro: Bool = false

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Text("\(value, specifier: "%.1f") \(unit)")
                .font(.subheadline.bold())
                .foregroundColor(.gray)
                .contentTransition(.numericText())
        }
        .padding(.vertical, 18)
        .overlay(
            Divider(), alignment: .bottom
        )
    }
}

private struct NutritionSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.gray)
            .padding(.top, 24)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
