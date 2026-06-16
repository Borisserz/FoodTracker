import SwiftUI
import SwiftData

struct CreateRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var path: NavigationPath
    @State private var showingManualAdd = false

    @State private var currentStep: Int = 0
    private let totalSteps = 4

    @State private var recipeName: String = ""
    @State private var category: String = "Breakfast"
    @State private var servings: Int = 1
    @State private var cookingTime: Int = 15
    let categories = ["Breakfast", "Lunch", "Dinner", "Snack", "Dessert"]

    @State private var ingredients: [FoodItem] = []
    @State private var showingSmartAdd = false

    @State private var directions: [String] = [""]

    var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return recipeName.trimmingCharacters(in: .whitespaces).count >= 3
        case 1: return ingredients.count >= 1
        case 2: return !directions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.isEmpty
        default: return true
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 0) {

                HStack(spacing: 8) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color.themePink : Color.gray.opacity(0.2))
                            .frame(height: 4)
                            .animation(.spring(), value: currentStep)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

                TabView(selection: $currentStep) {
                    Step1BasicsView(name: $recipeName, category: $category, servings: $servings, time: $cookingTime, categories: categories)
                        .tag(0)

                    Step2IngredientsView(ingredients: $ingredients, showingAdd: $showingSmartAdd, showingManualAdd: $showingManualAdd)
                        .tag(1)

                    Step3DirectionsView(directions: $directions)
                        .tag(2)

                    Step4VerificationView(name: recipeName, servings: servings, time: cookingTime, ingredients: ingredients, directions: directions)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)

                Spacer(minLength: 100)
            }

            VStack {
                Spacer()
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 110)
                        .mask(LinearGradient(colors: [.white, .white, .clear], startPoint: .bottom, endPoint: .top))

                    Button(action: handleNextOrSave) {
                        Text(currentStep == 3 ? "Save Recipe" : "Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(isCurrentStepValid ? Color.themePink : Color.gray.opacity(0.5))
                            .cornerRadius(24)
                            .shadow(color: isCurrentStepValid ? Color.themePink.opacity(0.4) : .clear, radius: 8, y: 4)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 30)
                    }
                    .disabled(!isCurrentStepValid)
                    .buttonStyle(BounceButtonStyle())
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)

        .toolbar(.hidden, for: .tabBar)
        .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }

        .sheet(isPresented: $showingSmartAdd) {
            SmartAddFoodView(mealTitle: "Recipe Ingredient") { selectedItems in

                withAnimation(.spring()) {
                    ingredients.append(contentsOf: selectedItems)
                }
            }
            .presentationDetents([.fraction(0.85), .large])
            .presentationCornerRadius(32)
        }
        .sheet(isPresented: $showingManualAdd) {
            AddIngredientModalView { newCustomItem in
                withAnimation(.spring()) {
                    ingredients.append(newCustomItem)
                }
            }
            .presentationDetents([.fraction(0.85), .large])
            .presentationCornerRadius(32)
        }
    }

    private var navTitle: String {
        switch currentStep {
        case 0: return "Description"
        case 1: return "Ingredients"
        case 2: return "Directions"
        case 3: return "Verification"
        default: return "Create Recipe"
        }
    }

    private func handleNextOrSave() {
        HapticManager.shared.impact(style: .medium)

        if currentStep < 3 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentStep += 1
            }
        } else {
            saveAndNavigate()
        }
    }

    private func saveAndNavigate() {
        TrackingManager.shared.track(.customRecipeCreated(ingredientsCount: ingredients.count))

        let cleanDirections = directions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let newRecipe = CustomRecipe(
            name: recipeName,
            info: category,
            foodItems: ingredients,
            cookingTime: cookingTime,
            difficulty: "Medium",
            servings: servings,
            directions: cleanDirections
        )

        modelContext.insert(newRecipe)

        do {
            try modelContext.save()
            path.removeLast()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                path.append(FoodsRoute.recipeDetail(newRecipe))
            }
        } catch {
            print("Failed to save recipe: \(error.localizedDescription)")
        }
    }
}

struct Step1BasicsView: View {
    @Binding var name: String
    @Binding var category: String
    @Binding var servings: Int
    @Binding var time: Int
    let categories: [String]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Add basic information about the recipe.")
                        .font(.body)
                        .foregroundColor(.gray)
                    Text("Note: The recipe name must be at least 3 characters long.")
                        .font(.caption)
                        .foregroundColor(.themeOrange)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 0) {
                    HStack {
                        TextField("Recipe name", text: $name)
                            .font(.headline)
                        if name.isEmpty { Text("required").font(.subheadline).foregroundColor(.themePink.opacity(0.6)) }
                    }
                    .padding(.vertical, 16).padding(.horizontal, 20)
                    Divider().padding(.leading, 20)

                    HStack {
                        Text("Category").foregroundColor(category.isEmpty ? .gray : .primary)
                        Spacer()
                        Picker("Category", selection: $category) {
                            ForEach(categories, id: \.self) { Text($0).tag($0) }
                        }
                        .tint(.themePink)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 20)
                    Divider().padding(.leading, 20)

                    HStack {
                        Text("Number of servings")
                        Spacer()
                        Stepper("\(servings)", value: $servings, in: 1...20)
                            .frame(width: 120)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 20)
                    Divider().padding(.leading, 20)

                    HStack {
                        Text("Cooking time")
                        Spacer()
                        Stepper("\(time) min", value: $time, in: 5...240, step: 5)
                            .frame(width: 130)
                    }
                    .padding(.vertical, 10).padding(.horizontal, 20)
                }
                .background(Color.white)
                .cornerRadius(24)
                .padding(.horizontal, 20)
                .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
            }
            .padding(.top, 10)
        }
    }
}

struct Step2IngredientsView: View {
    @Binding var ingredients: [FoodItem]
    @Binding var showingAdd: Bool
    @Binding var showingManualAdd: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                Text("Search our global database or create your own custom ingredients.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)

                HStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        showingAdd = true
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.themePink)
                        .cornerRadius(20)
                        .shadow(color: Color.themePink.opacity(0.3), radius: 8, y: 4)
                    }

                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        showingManualAdd = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Custom")
                        }
                        .font(.headline)
                        .foregroundColor(.themePink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.themePink.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.horizontal, 20)

                if !ingredients.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(0..<ingredients.count, id: \.self) { index in
                            if index < ingredients.count {
                                let item = ingredients[index]
                                HStack {
                                    ZStack {
                                        Circle().fill(Color.gray.opacity(0.05)).frame(width: 44, height: 44)
                                        Text(String(item.name.first ?? "🥗")).font(.headline)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.system(size: 16, weight: .bold, design: .rounded))

                                        HStack {
                                            Text("\(item.calories) kcal — \(Int(item.weight))g")
                                                .foregroundColor(.gray)
                                            if item.protein > 0 || item.fats > 0 || item.carbs > 0 {
                                                Text("• P:\(Int(item.protein)) F:\(Int(item.fats)) C:\(Int(item.carbs))")
                                                    .foregroundColor(.themePink.opacity(0.8))
                                            }
                                        }
                                        .font(.caption)
                                    }
                                    Spacer()

                                    Button(action: {
                                        HapticManager.shared.impact(style: .light)
                                        withAnimation {
                                            if index < ingredients.count { ingredients.remove(at: index) }
                                        }
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red.opacity(0.7))
                                            .font(.title2)
                                    }
                                }
                                .padding(.vertical, 12).padding(.horizontal, 20)

                                if index < ingredients.count - 1 { Divider().padding(.leading, 70) }
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(24)
                    .padding(.horizontal, 20)
                    .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
                } else {
                    EmptyStateView(imageName: "cart.badge.plus", title: String(localized: "No ingredients"), description: String(localized: "Tap the buttons above to add food."))
                        .frame(height: 200)
                }
            }
            .padding(.top, 10)
        }
    }
}

struct Step3DirectionsView: View {
    @Binding var directions: [String]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {

                Text("Add step-by-step directions for the cooking process.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)

                VStack(spacing: 16) {
                    ForEach(0..<directions.count, id: \.self) { index in
                        DirectionRowView(
                            index: index,
                            text: Binding(
                                get: { index < directions.count ? directions[index] : "" },
                                set: { if index < directions.count { directions[index] = $0 } }
                            ),
                            canDelete: directions.count > 1,
                            onDelete: {
                                withAnimation {
                                    if index < directions.count {
                                        directions.remove(at: index)
                                    }
                                }
                            }
                        )
                    }
                }

                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    withAnimation { directions.append("") }
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add step")
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(24)
                }
                .padding(.horizontal, 20)
            }
            .padding(.top, 10)
        }
    }
}

struct DirectionRowView: View {
    let index: Int
    @Binding var text: String
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.themePink)
                .clipShape(Circle())

            TextField("Describe step \(index + 1)...", text: $text, axis: .vertical)
                .lineLimit(2...5)
                .padding(16)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.02), radius: 5, y: 2)

            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red.opacity(0.5))
                        .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

struct Step4VerificationView: View {
    let name: String
    let servings: Int
    let time: Int
    let ingredients: [FoodItem]
    let directions: [String]

    var totalCalories: Int { ingredients.reduce(0) { $0 + $1.calories } }
    var totalWeight: Double { ingredients.reduce(0) { $0 + $1.weight } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 32) {

                Text("Final review. Check your recipe details before saving.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)

                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name.isEmpty ? "New Recipe" : name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        HStack(spacing: 12) {
                            Label("\(totalCalories) kcal", systemImage: "flame.fill")
                            Label("\(time) min", systemImage: "clock.fill")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(24)
                .background(
                    LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(24)
                .shadow(color: Color.green.opacity(0.3), radius: 10, y: 5)
                .padding(.horizontal, 20)

                HStack {
                    VStack(alignment: .leading) {
                        Text("Standard Serving").font(.caption).foregroundColor(.gray)
                        Text("\(Int(totalWeight / Double(max(servings, 1)))) g").font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Total Weight").font(.caption).foregroundColor(.gray)
                        Text("\(Int(totalWeight)) g").font(.system(size: 20, weight: .bold, design: .rounded))
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color.black.opacity(0.02), radius: 5, y: 2)
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 16) {
                    Text("Ingredients").font(.title2).bold().padding(.horizontal, 20)
                    VStack(spacing: 0) {
                        ForEach(ingredients) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name).font(.system(size: 16, weight: .semibold, design: .rounded))
                                    Text("\(item.calories) kcal — \(Int(item.weight))g")
                                        .font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 12).padding(.horizontal, 20)
                            if item.id != ingredients.last?.id { Divider().padding(.leading, 20) }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.02), radius: 5, y: 2)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 10)
        }
    }
}

struct AddIngredientModalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var onSave: (FoodItem) -> Void

    @State private var name: String = ""
    @State private var weight: String = "100"

    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var fats: String = ""
    @State private var carbs: String = ""

    var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (Double(weight) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.themeBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Basic Info").font(.headline).foregroundColor(.gray)

                            VStack(spacing: 0) {
                                CustomTextFieldRow(title: String(localized: "Name"), placeholder: "e.g. Oat Milk", text: $name, isNumber: false)
                                Divider().padding(.leading, 20)
                                CustomTextFieldRow(title: String(localized: "Weight (g)"), placeholder: "100", text: $weight, isNumber: true)
                            }
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
                        }

                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Nutrition Facts").font(.headline).foregroundColor(.gray)
                                Spacer()
                                Text("Optional").font(.caption).foregroundColor(.gray.opacity(0.6))
                            }

                            VStack(spacing: 0) {
                                CustomTextFieldRow(title: String(localized: "Calories (kcal)"), placeholder: "0", text: $calories, isNumber: true)
                                Divider().padding(.leading, 20)
                                CustomTextFieldRow(title: String(localized: "Protein (g)"), placeholder: "0", text: $protein, isNumber: true)
                                Divider().padding(.leading, 20)
                                CustomTextFieldRow(title: String(localized: "Fats (g)"), placeholder: "0", text: $fats, isNumber: true)
                                Divider().padding(.leading, 20)
                                CustomTextFieldRow(title: String(localized: "Carbs (g)"), placeholder: "0", text: $carbs, isNumber: true)
                            }
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
                        }

                        Text("Items created here are permanently saved to your database and can be used in your daily logs.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        Spacer().frame(height: 100)
                    }
                    .padding(20)
                }

                VStack {
                    Spacer()
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .frame(height: 100)
                            .mask(LinearGradient(colors: [.white, .white, .clear], startPoint: .bottom, endPoint: .top))

                        Button(action: saveIngredient) {
                            Text("Save & Add")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isFormValid ? Color.themePink : Color.gray.opacity(0.5))
                                .cornerRadius(20)
                                .shadow(color: isFormValid ? Color.themePink.opacity(0.4) : .clear, radius: 8, y: 4)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                        }
                        .disabled(!isFormValid)
                        .buttonStyle(BounceButtonStyle())
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Custom Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.gray)
                }
            }
        }
    }

    private func saveIngredient() {
        HapticManager.shared.impact(style: .heavy)

        let w = Double(weight) ?? 100.0
        let cals = Int(calories) ?? 0
        let p = Double(protein) ?? 0.0
        let f = Double(fats) ?? 0.0
        let c = Double(carbs) ?? 0.0

        let newFood = FoodItem(name: name, weight: w, calories: cals, protein: p, fats: f, carbs: c)

        context.insert(newFood)
        try? context.save()

        onSave(newFood)
        dismiss()
    }
}

struct CustomTextFieldRow: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let isNumber: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
            TextField(placeholder, text: $text)
                .multilineTextAlignment(.trailing)
                .keyboardType(isNumber ? .decimalPad : .default)
                .foregroundColor(.themePink)
                .font(.headline)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct RecipeMacroDonutView: View {
    let calories: Int; let protein: Double; let fat: Double; let carbs: Double
    @State private var anim = false
    var totalCalsFromMacros: Double { max((protein * 4) + (fat * 9) + (carbs * 4), 1.0) }
    var cPct: Double { (carbs * 4) / totalCalsFromMacros }
    var fPct: Double { (fat * 9) / totalCalsFromMacros }
    var pPct: Double { (protein * 4) / totalCalsFromMacros }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Nutrition Per Serving").font(.title3.bold())
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.15), lineWidth: 10)
                    Circle().trim(from: 0, to: anim ? cPct : 0).stroke(Color.drinkWater, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                    Circle().trim(from: anim ? cPct : 0, to: anim ? (cPct + fPct) : 0).stroke(Color.themeYellow, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                    Circle().trim(from: anim ? (cPct + fPct) : 0, to: anim ? 1.0 : 0).stroke(Color.themePeach, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack(spacing: 0) { Text("\(calories)").font(.system(size: 22, weight: .heavy, design: .rounded)); Text("cal").font(.caption).foregroundColor(.gray) }
                }.frame(width: 90, height: 90)
                Spacer()
                HStack(spacing: 16) {
                    MacroStatColumn(percent: cPct, grams: carbs, title: String(localized: "Carbs"), color: .drinkWater)
                    MacroStatColumn(percent: fPct, grams: fat, title: String(localized: "Fat"), color: .themeYellow)
                    MacroStatColumn(percent: pPct, grams: protein, title: String(localized: "Protein"), color: .themePeach)
                }
            }
        }.padding(20).background(Color.white).cornerRadius(24).shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { anim = true } } }
        .onChange(of: calories) { _, _ in anim = false; withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { anim = true } }
    }
}
struct MacroStatColumn: View {
    let percent: Double; let grams: Double; let title: String; let color: Color
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("\(Int(percent * 100))%").font(.system(size: 14, weight: .bold)).foregroundColor(color)
            Text("\(grams, specifier: "%.1f") g").font(.system(size: 16, weight: .bold, design: .rounded)).contentTransition(.numericText())
            Text(title).font(.caption).foregroundColor(.gray)
        }.frame(minWidth: 50)
    }
}

struct CustomRecipeHeroHeader: View {
    let name: String
    
    var gradientColors: [Color] {
        let hash = name.hashValue
        let colors: [[Color]] = [
            [.themePink, .themeOrange],
            [.purple, .blue],
            [.green, .mint],
            [.themeOrange, .red],
            [.themePeach, .themeYellow],
            [.teal, .indigo]
        ]
        return colors[abs(hash) % colors.count]
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            
            GeometryReader { proxy in
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: proxy.size.width * 0.8)
                    .offset(x: -proxy.size.width * 0.2, y: -proxy.size.height * 0.2)
                    .blur(radius: 30)
                
                Circle()
                    .fill(.black.opacity(0.1))
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: proxy.size.width * 0.5, y: proxy.size.height * 0.4)
                    .blur(radius: 30)
            }
        }
    }
}

struct AIChefPremiumBanner: View {
    let isGenerating: Bool
    let action: () -> Void
    
    @State private var shimmerOffset: CGFloat = -200
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isGenerating ? 360 : 0))
                        .animation(isGenerating ? .linear(duration: 2).repeatForever(autoreverses: false) : .default, value: isGenerating)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isGenerating ? "Chef is thinking..." : "Cook with AI Chef")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Interactive, smart cooking guide")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(16)
            .background(
                ZStack {
                    LinearGradient(colors: isGenerating ? [.gray, .gray.opacity(0.8)] : [.themeOrange, .themePink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    
                    if !isGenerating {
                        GeometryReader { proxy in
                            LinearGradient(colors: [.clear, .white.opacity(0.4), .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: 100)
                                .offset(x: shimmerOffset)
                        }
                    }
                }
            )
            .cornerRadius(24)
            .shadow(color: isGenerating ? .clear : Color.themeOrange.opacity(0.3), radius: 15, y: 8)
            .clipped()
        }
        .buttonStyle(BounceButtonStyle())
        .disabled(isGenerating)
        .onAppear {
            if !isGenerating {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    shimmerOffset = 400
                }
            }
        }
    }
}

struct RecipeDetailView: View {
    let recipe: CustomRecipe
    @Binding var path: NavigationPath
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showMealSheet = false
    @State private var isGeneratingRecipe = false
    @State private var generatedRecipe: AIChefRecipe? = nil
    @State private var showAIFlow = false

    private func deleteRecipe() {
        context.delete(recipe)
        try? context.save()
        dismiss()
    }
    var totalProtein: Double { recipe.foodItems.reduce(0) { $0 + $1.protein } }
    var totalFat: Double { recipe.foodItems.reduce(0) { $0 + $1.fats } }
    var totalCarbs: Double { recipe.foodItems.reduce(0) { $0 + $1.carbs } }

    private func generateAI() {
        guard !isGeneratingRecipe else { return }
        isGeneratingRecipe = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            let ingredientsList = recipe.foodItems.map { "\($0.name) (\(Int($0.weight))g)" }
            if let dto = await AINutritionService.shared.generateCookingSteps(for: recipe.name, ingredients: ingredientsList) {
                let ai = AIChefRecipe(
                    title: dto.title,
                    calories: dto.calories,
                    protein: dto.protein,
                    heroImage: "sparkles",
                    cookTime: dto.cookTime,
                    difficulty: dto.difficulty,
                    history: dto.history,
                    ingredients: dto.ingredients,
                    steps: dto.steps.map { RecipeStep(instruction: $0.instruction, imageName: "sparkles", aiTip: $0.aiTip) },
                    platingTip: dto.platingTip
                )
                await MainActor.run {
                    self.generatedRecipe = ai
                    self.isGeneratingRecipe = false
                    self.showAIFlow = true
                }
            } else {
                await MainActor.run { self.isGeneratingRecipe = false }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    ZStack(alignment: .bottomLeading) {
                        CustomRecipeHeroHeader(name: recipe.name)
                            .frame(maxWidth: .infinity)
                            .frame(height: 320)
                            .clipped()

                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(recipe.name)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(3)

                            HStack(spacing: 16) {
                                Label("\(recipe.cookingTime) min", systemImage: "clock.fill")
                                Label(recipe.difficulty, systemImage: "flame.fill")
                                Label("\(recipe.servings) servings", systemImage: "person.2.fill")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(20)
                    }
                    .cornerRadius(32, corners: [.bottomLeft, .bottomRight])
                    .ignoresSafeArea(edges: .top)

                    VStack(alignment: .leading, spacing: 32) {
                        
                        if !recipe.directions.isEmpty {
                            AIChefPremiumBanner(isGenerating: isGeneratingRecipe) {
                                generateAI()
                            }
                            .padding(.horizontal, 20)
                        }

                        RecipeMacroDonutView(
                            calories: recipe.totalCalories,
                            protein: totalProtein,
                            fat: totalFat,
                            carbs: totalCarbs
                        )
                        .padding(.horizontal, 20)

                        if !recipe.foodItems.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Ingredients").font(.title2).bold()
                                VStack(spacing: 16) {
                                    ForEach(recipe.foodItems) { item in
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(item.name).font(.headline)
                                                Text("\(item.calories) Cal — \(Int(item.weight)) g")
                                                    .font(.caption).foregroundColor(.gray)
                                            }
                                            Spacer()
                                        }
                                        if item.id != recipe.foodItems.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                                .padding(20)
                                .background(Color.white)
                                .cornerRadius(24)
                                .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
                            }
                            .padding(.horizontal, 20)
                        }

                        if !recipe.directions.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Directions").font(.title2).bold()
                                VStack(alignment: .leading, spacing: 24) {
                                    ForEach(Array(recipe.directions.enumerated()), id: \.offset) { index, step in
                                        HStack(alignment: .top, spacing: 16) {
                                            Text("\(index + 1)")
                                                .font(.headline)
                                                .foregroundColor(.themePink)
                                                .frame(width: 32, height: 32)
                                                .background(Color.white)
                                                .overlay(Circle().stroke(Color.themePink, lineWidth: 2))
                                                .clipShape(Circle())
                                            Text(step)
                                                .font(.body)
                                                .foregroundColor(.primary.opacity(0.9))
                                                .lineSpacing(4)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer().frame(height: 120)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)

            VStack {
                HStack {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
                    }
                    Spacer()

                    Button(action: {
                        HapticManager.shared.impact(style: .heavy)
                        deleteRecipe()
                    }) {
                        Image(systemName: "trash")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Circle())
                            .shadow(color: .red.opacity(0.3), radius: 5, y: 2)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 50)

                Spacer()
            }

            VStack {
                Spacer()
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 110)
                        .mask(LinearGradient(colors: [.white, .white, .clear], startPoint: .bottom, endPoint: .top))

                    Button(action: {
                        HapticManager.shared.impact(style: .heavy)
                        showMealSheet = true
                    }) {
                        Text("Add to meal")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.themePink)
                            .cornerRadius(24)
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
        .fullScreenCover(isPresented: $showAIFlow) {
            if let ai = generatedRecipe {
                NavigationStack {
                    PrepChecklistView(recipe: ai, isFlowPresented: $showAIFlow)
                }
            }
        }
        .sheet(isPresented: $showMealSheet) {
            CustomChooseMealSheet(recipe: recipe)
                .presentationDetents([.fraction(0.4)])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
        }
    }
}

struct CustomChooseMealSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Environment(DIContainer.self) private var di
    @Query private var summaries: [DailySummary]

        let recipe: CustomRecipe
        @State private var selectedMeal = "Breakfast"
        let meals = ["Breakfast", "Lunch", "Dinner", "Snack"]

        init(recipe: CustomRecipe) {
            self.recipe = recipe
            let today = Calendar.current.startOfDay(for: .now)
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            let predicate = #Predicate<DailySummary> { $0.date >= today && $0.date < tomorrow }
            self._summaries = Query(filter: predicate)
        }

        var body: some View {
            VStack(spacing: 24) {
                Text("Choose a meal").font(.title2.bold()).padding(.top, 24)
                Picker("Meal", selection: $selectedMeal) {
                    ForEach(meals, id: \.self) { meal in Text(meal).tag(meal) }
                }
                .pickerStyle(.wheel).frame(height: 120)

                Button(action: {
                    HapticManager.shared.impact(style: .heavy)
                    Task {
                        await saveToDiary()
                        await MainActor.run { dismiss() }
                    }
                }) {
                    Text("Select")
                        .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                        .padding(.vertical, 18).background(Color.themePink)
                        .cornerRadius(24).shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4)
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.horizontal, 24).padding(.bottom, 20)
            }
            .background(Color.themeBg.ignoresSafeArea())
        }

        private func saveToDiary() async {
            // Use @ModelActor repo to ensure the day's summary (removes detached creation)
            _ = try? await di.summaryRepository.ensureSummary(for: Date.now)

            guard let summary = summaries.first else { return }

            let newFood = recipe.toFoodItem()
            if let meal = summary.meals.first(where: { $0.title == selectedMeal }) {
                meal.foodItems.append(newFood)
            } else {
                let newMeal = Meal(title: selectedMeal, date: .now, foodItems: [newFood])
                context.insert(newMeal)
                summary.meals.append(newMeal)
            }
            try? context.save()
        }
    }

