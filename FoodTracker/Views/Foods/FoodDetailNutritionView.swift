import SwiftUI

struct FoodDetailNutritionView: View {
    @Environment(\.dismiss) private var dismiss

    let food: FoodItem
    let mealTitle: String
    var isEditing: Bool = false
    var onAdd: (FoodItem) -> Void

    @State private var weight: Double

    init(food: FoodItem, mealTitle: String, isEditing: Bool = false, onAdd: @escaping (FoodItem) -> Void) {
        self.food = food
        self.mealTitle = mealTitle
        self.isEditing = isEditing
        self.onAdd = onAdd
        self._weight = State(initialValue: food.weight > 0 ? food.weight : 100.0)
    }

    private var scaled: ScaledNutritionValues {
        NutritionMath.scaledValues(
            baseWeight: food.weight,
            baseCalories: food.calories,
            baseProtein: food.protein,
            baseFats: food.fats,
            baseCarbs: food.carbs,
            fiber: food.fiber,
            sugar: food.sugar,
            omega3: food.omega3,
            calcium: food.calcium,
            potassium: food.potassium,
            magnesium: food.magnesium,
            iron: food.iron,
            vitaminC: food.vitaminC,
            vitaminD: food.vitaminD,
            targetWeight: weight
        )
    }

    private var currentCals: Int { scaled.calories }
    private var currentP: Double { scaled.protein }
    private var currentF: Double { scaled.fats }
    private var currentC: Double { scaled.carbs }

    var body: some View {
        ZStack {
            DynamicAuroraBackgroundView(pinnedPaletteIndex: EditorialMealTheme.paletteIndex(for: mealTitle))
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(spacing: 0) {
                        FoodDetailHeader(name: food.name, mealTitle: mealTitle)

                        MacroDonutChartCard(
                            calories: currentCals,
                            p: currentP,
                            f: currentF,
                            c: currentC
                        )
                        .padding(.horizontal, 20)
                        .offset(y: -34)
                        .padding(.bottom, -34)
                    }

                    if food.weight > 0 {
                        ServingSizeEditor(weight: $weight)
                            .padding(.horizontal, 20)
                    } else {
                        EditorialLightCard(cornerRadius: 20, padding: 18) {
                            HStack {
                                Text("Serving Size")
                                    .font(.system(size: 15.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(EditorialPalette.inkSecondary)
                                Spacer()
                                Text("1 serving")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(EditorialPalette.inkPrimary)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Nutrition Facts")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkPrimary)
                            .padding(.horizontal, 4)

                        VStack(spacing: 0) {
                            NutritionRow(title: "Proteins", value: currentP, unit: "g")
                            NutritionRow(title: "Total Fat", value: currentF, unit: "g")
                            NutritionRow(title: "Carbs", value: currentC, unit: "g")
                            NutritionRow(title: "Dietary Fiber", value: scaled.fiber, unit: "g")
                            NutritionRow(title: "Total Sugars", value: scaled.sugar, unit: "g")
                            NutritionRow(title: "Net Carbs", value: scaled.netCarbs, unit: "g")

                            NutritionSectionHeader(title: "Vitamins & Minerals")

                            NutritionRow(title: "Vitamin C", value: scaled.vitaminC, unit: "mg", isPro: true)
                            NutritionRow(title: "Vitamin D", value: scaled.vitaminD, unit: "mcg", isPro: true)
                            NutritionRow(title: "Calcium", value: scaled.calcium, unit: "mg", isPro: true)
                            NutritionRow(title: "Iron", value: scaled.iron, unit: "mg", isPro: true)
                            NutritionRow(title: "Magnesium", value: scaled.magnesium, unit: "mg", isPro: true)
                            NutritionRow(title: "Potassium", value: scaled.potassium, unit: "mg", isPro: true)
                            NutritionRow(title: "Omega-3", value: scaled.omega3, unit: "g", isPro: true)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.82))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                        )
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 24)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button(action: {
                HapticManager.shared.impact(style: .heavy)
                let addedFood = FoodItem(
                    name: food.name,
                    weight: scaled.weight,
                    calories: currentCals,
                    protein: currentP,
                    fats: currentF,
                    carbs: currentC,
                    fiber: scaled.fiber,
                    sugar: scaled.sugar,
                    omega3: scaled.omega3,
                    calcium: scaled.calcium,
                    potassium: scaled.potassium,
                    magnesium: scaled.magnesium,
                    iron: scaled.iron,
                    vitaminC: scaled.vitaminC,
                    vitaminD: scaled.vitaminD
                )
                onAdd(addedFood)
                dismiss()
            }) {
                HStack {
                    let localizedTitle = String(localized: String.LocalizationValue(mealTitle))
                    Text(isEditing ? String(localized: "Save Changes") : String(format: String(localized: "Add to %@"), localizedTitle))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Text("\(currentCals) kcal")
                        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(EditorialPalette.oat)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 18)
            }
            .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite, height: 54))
            .accessibilityIdentifier("food_detail_confirm_button")
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial)
        }
        .keyboardDoneToolbar()
        .navigationBarHidden(true)
    }
}

private struct FoodDetailHeader: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage(FavoriteFoodStore.storageKey) private var favoriteFoodNamesRaw: String = ""

    let name: String
    var mealTitle: String = "Breakfast"

    private var isFavorite: Bool {
        FavoriteFoodStore.namesSet(from: favoriteFoodNamesRaw).contains(
            name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
    }

    private func toggleFavorite() {
        favoriteFoodNamesRaw = FavoriteFoodStore.toggledRaw(favoriteFoodNamesRaw, foodName: name)
    }

    private var topSafeInset: CGFloat {
        let inset = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 44
        return max(inset, 20) + 8
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            DynamicAuroraBackgroundView(
                pinnedPaletteIndex: EditorialMealTheme.paletteIndex(for: mealTitle),
                darkCanvas: true
            )

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(EditorialPalette.chipDark.opacity(0.84))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
                    }
                    Spacer()
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring()) { toggleFavorite() }
                    }) {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isFavorite ? EditorialPalette.warmAmber : .white)
                            .frame(width: 40, height: 40)
                            .background(EditorialPalette.chipDark.opacity(0.84))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75))
                    }
                }
                .padding(.top, topSafeInset)

                Text(name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 20)
        }
        .clipShape(RoundedCorner(radius: 28, corners: [.bottomLeft, .bottomRight]))
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
        EditorialDarkCard(cornerRadius: 22, padding: 18) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: showAnimation ? cPercent : 0)
                        .stroke(EditorialPalette.oceanSlate, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .trim(from: showAnimation ? cPercent : 0, to: showAnimation ? (cPercent + fPercent) : 0)
                        .stroke(EditorialPalette.warmAmber, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    if pPercent > 0 {
                        Circle()
                            .trim(from: showAnimation ? (cPercent + fPercent) : 0, to: showAnimation ? min(cPercent + fPercent + pPercent, 1.0) : 0)
                            .stroke(EditorialPalette.emerald, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }

                    VStack(spacing: 0) {
                        Text("\(calories)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded).monospacedDigit())
                            .foregroundStyle(EditorialPalette.oat)
                            .contentTransition(.numericText())
                        Text("cal")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                }
                .frame(width: 80, height: 80)

                Spacer()

                HStack(spacing: 14) {
                    MacroColumnInfo(percent: cPercent, grams: c, title: "Carbs", color: EditorialPalette.oceanSlate)
                    MacroColumnInfo(percent: fPercent, grams: f, title: "Fat", color: EditorialPalette.warmAmber)
                    MacroColumnInfo(percent: pPercent, grams: p, title: "Protein", color: EditorialPalette.emerald)
                }
            }
        }
        .shadow(color: Color.black.opacity(0.18), radius: 14, y: 6)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                    showAnimation = true
                }
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
        VStack(alignment: .center, spacing: 3) {
            Text("\(Int(percent * 100))%")
                .font(.system(size: 11.5, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color)

            Text("\(grams, specifier: "%.1f") g")
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText())

            Text(LocalizedStringKey(title))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.66))
        }
        .frame(minWidth: 48)
    }
}

private struct ServingSizeEditor: View {
    @Binding var weight: Double
    @AppStorage("useMetricSystem") private var useMetricSystem = true
    @State private var textInput: String = ""
    @FocusState private var isWeightFocused: Bool

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { min(max(weight, 5), 1000) },
            set: { weight = $0 }
        )
    }

    private func formattedInput(for grams: Double) -> String {
        let display = NutritionMath.displayFoodWeight(grams, useMetric: useMetricSystem)
        return useMetricSystem ? String(format: "%.0f", display) : String(format: "%.1f", display)
    }

    var body: some View {
        EditorialLightCard(cornerRadius: 20, padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Serving Size")
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkSecondary)
                        if !useMetricSystem {
                            Text(NutritionMath.formattedFoodWeight(weight, useMetric: false))
                                .font(.caption.bold())
                                .foregroundStyle(EditorialPalette.forest)
                        }
                    }
                    Spacer()

                    HStack(spacing: 4) {
                        TextField(useMetricSystem ? "100" : "3.5", text: $textInput)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 19, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(EditorialPalette.inkPrimary)
                            .focused($isWeightFocused)
                            .frame(width: 78)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background(Color.black.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onChange(of: textInput) { _, newValue in
                                guard isWeightFocused, newValue != formattedInput(for: weight) else { return }
                                if let val = NutritionMath.parsePositiveDecimal(newValue) {
                                    let grams = NutritionMath.gramsFromDisplayFoodWeight(val, useMetric: useMetricSystem)
                                    weight = min(grams, 50_000)
                                }
                            }

                        Text(NutritionMath.foodWeightUnit(useMetric: useMetricSystem))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkSecondary)
                    }
                }

                Slider(value: sliderBinding, in: 5...1000, step: 5)
                    .tint(EditorialPalette.inkPrimary)
                    .onChange(of: weight) { _, newValue in
                        guard !isWeightFocused else { return }
                        let newText = formattedInput(for: newValue)
                        if textInput != newText {
                            textInput = newText
                        }
                    }

                HStack(spacing: 8) {
                    ForEach([50, 100, 150, 200, 300], id: \.self) { amount in
                        let isSelected = weight == Double(amount)
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            isWeightFocused = false
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                let grams = Double(amount)
                                weight = grams
                                textInput = formattedInput(for: grams)
                            }
                        }) {
                            Text(useMetricSystem ? "\(amount)g" : NutritionMath.formattedFoodWeight(Double(amount), useMetric: false))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(isSelected ? EditorialPalette.inkPrimary : Color.black.opacity(0.05))
                                .foregroundStyle(isSelected ? Color.themeBg : EditorialPalette.inkPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        }
                    }
                }
            }
        }
        .onAppear {
            textInput = formattedInput(for: weight)
        }
        .onChange(of: useMetricSystem) { _, _ in
            guard !isWeightFocused else { return }
            let newText = formattedInput(for: weight)
            if textInput != newText {
                textInput = newText
            }
        }
        .onChange(of: isWeightFocused) { _, focused in
            if !focused {
                let formatted = formattedInput(for: weight)
                if textInput != formatted {
                    textInput = formatted
                }
            }
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
            Text(LocalizedStringKey(title))
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
        Text(LocalizedStringKey(title))
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
