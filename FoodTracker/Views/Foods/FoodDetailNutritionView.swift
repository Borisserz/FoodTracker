import SwiftUI

struct FoodDetailNutritionView: View {
    @Environment(\.dismiss) private var dismiss

    let food: FoodItem
    let mealTitle: String
    var onAdd: (FoodItem) -> Void

    @State private var weight: Double
    
    // Editable base properties
    @State private var editedName: String
    @State private var baseCalories: Int
    @State private var baseProtein: Double
    @State private var baseFats: Double
    @State private var baseCarbs: Double
    
    @State private var showAdjustSheet = false

    init(food: FoodItem, mealTitle: String, onAdd: @escaping (FoodItem) -> Void) {
        self.food = food
        self.mealTitle = mealTitle
        self.onAdd = onAdd
        self._weight = State(initialValue: food.weight > 0 ? food.weight : 100.0)
        
        self._editedName = State(initialValue: food.name)
        self._baseCalories = State(initialValue: food.calories)
        self._baseProtein = State(initialValue: food.protein)
        self._baseFats = State(initialValue: food.fats)
        self._baseCarbs = State(initialValue: food.carbs)
    }

    private var multiplier: Double { weight / max(food.weight, 1.0) }
    private var currentCals: Int { Int(Double(baseCalories) * multiplier) }
    private var currentP: Double { baseProtein * multiplier }
    private var currentF: Double { baseFats * multiplier }
    private var currentC: Double { baseCarbs * multiplier }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    VStack(spacing: 0) {
                        FoodDetailHeader(name: editedName) {
                            HapticManager.shared.impact(style: .medium)
                            showAdjustSheet = true
                        }

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
                            NutritionRow(title: String(localized: "Proteins"), value: currentP, unit: "g")
                            NutritionRow(title: String(localized: "Total Fat"), value: currentF, unit: "g")
                            NutritionRow(title: String(localized: "Carbs"), value: currentC, unit: "g")

                            NutritionSectionHeader(title: String(localized: "Vitamins & Minerals"))

                            NutritionRow(title: String(localized: "Vitamin C"), value: food.vitaminC * multiplier, unit: "mg", isPro: true)
                            NutritionRow(title: String(localized: "Vitamin D"), value: food.vitaminD * multiplier, unit: "mcg", isPro: true)
                            NutritionRow(title: String(localized: "Calcium"), value: food.calcium * multiplier, unit: "mg", isPro: true)
                            NutritionRow(title: String(localized: "Iron"), value: food.iron * multiplier, unit: "mg", isPro: true)
                            NutritionRow(title: String(localized: "Magnesium"), value: food.magnesium * multiplier, unit: "mg", isPro: true)
                            NutritionRow(title: String(localized: "Potassium"), value: food.potassium * multiplier, unit: "mg", isPro: true)
                            NutritionRow(title: String(localized: "Omega-3"), value: food.omega3 * multiplier, unit: "g", isPro: true)
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
                            name: editedName,
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
        .sheet(isPresented: $showAdjustSheet) {
            AdjustMacrosSheet(
                name: $editedName,
                calories: $baseCalories,
                protein: $baseProtein,
                fats: $baseFats,
                carbs: $baseCarbs
            )
            .presentationDetents([.fraction(0.7), .large])
            .presentationCornerRadius(32)
            .presentationDragIndicator(.visible)
        }
    }
}

private struct FoodDetailHeader: View {
    @Environment(\.dismiss) var dismiss
    @State private var isFavorite = false

    let name: String
    var onAdjust: () -> Void

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
                Button(action: onAdjust) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundColor(.white)
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
                MacroColumnInfo(percent: cPercent, grams: c, title: String(localized: "Carbs"), color: .drinkWater)
                MacroColumnInfo(percent: fPercent, grams: f, title: String(localized: "Fats"), color: .themeYellow)
                MacroColumnInfo(percent: pPercent, grams: p, title: String(localized: "Protein"), color: .themePeach)
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
    
    private var weightTextBinding: Binding<String> {
        Binding(
            get: {
                if weight == 0 {
                    return ""
                }
                return String(format: "%.0f", weight)
            },
            set: { newValue in
                let filtered = newValue.filter { "0123456789".contains($0) }
                if let val = Double(filtered) {
                    weight = val
                } else if filtered.isEmpty {
                    weight = 0
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Serving Size")
                .font(.headline)

            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Spacer()
                    TextField("100", text: weightTextBinding)
                        .keyboardType(.numberPad)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 140)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )

                    Text("g")
                        .font(.title2.bold())
                        .foregroundColor(.gray)
                    Spacer()
                }

                Slider(value: $weight, in: 1...500, step: 1)
                    .tint(.themePink)
                    .padding(.horizontal, 10)
            }

            HStack(spacing: 12) {
                ForEach([50, 100, 150, 200], id: \.self) { amount in
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            weight = Double(amount)
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
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
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

// MARK: - AdjustMacrosSheet
struct AdjustMacrosSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var name: String
    @Binding var calories: Int
    @Binding var protein: Double
    @Binding var fats: Double
    @Binding var carbs: Double

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
                .onTapGesture { hideKeyboard() }
                
            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                HStack {
                    Text(String(localized: "Adjust Results"))
                        .font(.title2.bold())
                    Spacer()
                    Button(String(localized: "Done")) {
                        hideKeyboard()
                        HapticManager.shared.impact(style: .medium)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.themePink)
                }
                .padding(.horizontal, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        AdjustInputField(title: String(localized: "Food Name"), icon: "pencil", text: $name)
                        
                        HStack(spacing: 16) {
                            AdjustNumberField(title: String(localized: "Calories"), icon: "flame.fill", color: .themeOrange, value: Binding(get: { Double(calories) }, set: { calories = Int($0) }))
                            AdjustNumberField(title: String(localized: "Protein"), icon: "bolt.fill", color: .themePeach, value: $protein)
                        }
                        
                        HStack(spacing: 16) {
                            AdjustNumberField(title: String(localized: "Fats"), icon: "drop.fill", color: .themeYellow, value: $fats)
                            AdjustNumberField(title: String(localized: "Carbs"), icon: "leaf.fill", color: .drinkWater, value: $carbs)
                        }
                        
                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct AdjustInputField: View {
    let title: String
    let icon: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold()).foregroundColor(.gray)
            HStack {
                Image(systemName: icon).foregroundColor(.themePink)
                TextField(title, text: $text)
                    .font(.headline)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
        }
    }
}

struct AdjustNumberField: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var value: Double
    
    private var textBinding: Binding<String> {
        Binding(
            get: { value == 0 ? "" : (value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.1f", value)) },
            set: {
                let filtered = $0.filter { "0123456789.".contains($0) }
                if let val = Double(filtered) { value = val }
                else if filtered.isEmpty { value = 0 }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold()).foregroundColor(.gray)
            HStack {
                Image(systemName: icon).foregroundColor(color)
                TextField("0", text: textBinding)
                    .keyboardType(.decimalPad)
                    .font(.headline.bold())
                    .multilineTextAlignment(.trailing)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
        }
    }
}
