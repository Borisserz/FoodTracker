import SwiftUI
import SwiftData

// MARK: - CREATE RECIPE WIZARD
struct CreateRecipeView: View {
    // 1. ИСПРАВЛЕНИЕ: Переменная называется modelContext
    @Environment(\.modelContext) private var modelContext
    @Binding var path: NavigationPath
    
    // Управление шагами
    @State private var currentStep: Int = 0
    private let totalSteps = 4
    
    // Данные рецепта (Step 1)
    @State private var recipeName: String = ""
    @State private var category: String = "Breakfast"
    @State private var servings: Int = 1
    @State private var cookingTime: Int = 15
    let categories = ["Breakfast", "Lunch", "Dinner", "Snack", "Dessert"]
    
    // Ингредиенты (Step 2)
    @State private var ingredients: [FoodItem] = []
    @State private var showingAddIngredient = false
    
    // Шаги приготовления (Step 3)
    @State private var directions: [String] = [""]
    
    var isCurrentStepValid: Bool {
        switch currentStep {
        case 0: return recipeName.trimmingCharacters(in: .whitespaces).count >= 3
        case 1: return ingredients.count >= 2
        case 2: return !directions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.isEmpty
        default: return true
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // --- CUSTOM PROGRESS BAR ---
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
                
                // --- DYNAMIC CONTENT (TAB VIEW WIZARD) ---
                TabView(selection: $currentStep) {
                    Step1BasicsView(name: $recipeName, category: $category, servings: $servings, time: $cookingTime, categories: categories)
                        .tag(0)
                    
                    Step2IngredientsView(ingredients: $ingredients, showingAdd: $showingAddIngredient)
                        .tag(1)
                    
                    Step3DirectionsView(directions: $directions)
                        .tag(2)
                    
                    Step4VerificationView(name: recipeName, servings: servings, time: cookingTime, ingredients: ingredients, directions: directions)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                Spacer(minLength: 100) // Отступ под плавающую кнопку
            }
            
            // --- FLOATING BOTTOM BUTTON ---
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
        .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        .sheet(isPresented: $showingAddIngredient) {
            AddIngredientModalView { newIngredient in
                ingredients.append(newIngredient)
            }
            .presentationDragIndicator(.visible)
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
        
        // 2. ИСПРАВЛЕНИЕ: Используем modelContext
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

// MARK: - STEP 1: BASICS
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

// MARK: - STEP 2: INGREDIENTS
struct Step2IngredientsView: View {
    @Binding var ingredients: [FoodItem]
    @Binding var showingAdd: Bool
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                
                Text("Add ingredients that are contained in the recipe. Minimum amount is two ingredients.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)
                
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    showingAdd = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add ingredients")
                    }
                    .font(.headline)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(24)
                }
                .padding(.horizontal, 20)
                
                if !ingredients.isEmpty {
                    VStack(spacing: 0) {
                        // Безопасное удаление из массива для предотвращения крэшей
                        ForEach(0..<ingredients.count, id: \.self) { index in
                            if index < ingredients.count {
                                let item = ingredients[index]
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name).font(.headline)
                                        Text("\(item.calories) Cal — \(Int(item.weight))g").font(.caption).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button(action: {
                                        withAnimation {
                                            if index < ingredients.count { ingredients.remove(at: index) }
                                        }
                                    }) {
                                        Image(systemName: "trash.circle.fill").foregroundColor(.red.opacity(0.7)).font(.title2)
                                    }
                                }
                                .padding(.vertical, 16).padding(.horizontal, 20)
                                
                                if index < ingredients.count - 1 { Divider().padding(.leading, 20) }
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(24)
                    .padding(.horizontal, 20)
                    .shadow(color: Color.black.opacity(0.03), radius: 10, y: 4)
                }
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - STEP 3: DIRECTIONS (ИСПРАВЛЕНО ДЛЯ КОМПИЛЯТОРА)
struct Step3DirectionsView: View {
    @Binding var directions: [String]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                
                Text("If you wish, you can add step-by-step directions for the cooking process.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)
                
                VStack(spacing: 16) {
                    ForEach(0..<directions.count, id: \.self) { index in
                        // Выносим в отдельную структуру для безопасности компилятора
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
                        Text("Add direction")
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

// 3. ИСПРАВЛЕНИЕ: Изолированная строка для безопасного ввода текста
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
                .lineLimit(1...4)
                .padding(12)
                .background(Color.white)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
            
            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red.opacity(0.5))
                        .padding(.top, 6)
                }
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - STEP 4: VERIFICATION
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
                
                Text("The final step. Please check the previously entered data.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 24)
                
                // Hero Summary Card
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name.isEmpty ? "New Recipe" : name)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        HStack(spacing: 12) {
                            Label("\(totalCalories) Cal", systemImage: "flame.fill")
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
                
                // Servings Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Servings information").font(.title2).bold()
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Standard serving: 1 Portion").font(.caption).foregroundColor(.gray)
                            Text("\(Int(totalWeight / Double(max(servings, 1)))) g").font(.headline)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Total weight").font(.caption).foregroundColor(.gray)
                            Text("\(Int(totalWeight)) g").font(.headline)
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                // Ingredients List
                VStack(alignment: .leading, spacing: 16) {
                    Text("Ingredients").font(.title2).bold()
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(ingredients) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name).font(.headline)
                                Text("\(item.calories) Cal — \(Int(item.weight)) g")
                                    .font(.caption).foregroundColor(.gray)
                            }
                            if item.id != ingredients.last?.id { Divider() }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.top, 10)
        }
    }
}

// MARK: - Вспомогательное окно для добавления ингредиента
struct AddIngredientModalView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (FoodItem) -> Void
    
    @State private var name: String = ""
    @State private var weight: Double?
    @State private var calsPer100: Int?
    
    var isFormValid: Bool { !name.isEmpty && (weight ?? 0) > 0 && (calsPer100 != nil) }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Ingredient Details") {
                    TextField("Name (e.g. Chicken Breast)", text: $name)
                    TextField("Weight added to recipe (g)", value: $weight, format: .number).keyboardType(.decimalPad)
                    TextField("Calories per 100g", value: $calsPer100, format: .number).keyboardType(.numberPad)
                }
            }
            .navigationTitle("New Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let w = weight, let c100 = calsPer100 {
                            let actualCals = Int(Double(c100) * (w / 100.0))
                            onSave(FoodItem(name: name, weight: w, calories: actualCals, protein: 0, fats: 0, carbs: 0))
                            dismiss()
                        }
                    }.disabled(!isFormValid).foregroundColor(isFormValid ? .themePink : .gray)
                }
            }
        }
    }
}
// 🍩 КРУГОВАЯ ДИАГРАММА МАКРОСОВ
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
                    MacroStatColumn(percent: cPct, grams: carbs, title: "Carbs", color: .drinkWater)
                    MacroStatColumn(percent: fPct, grams: fat, title: "Fat", color: .themeYellow)
                    MacroStatColumn(percent: pPct, grams: protein, title: "Protein", color: .themePeach)
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

// MARK: - 6. CUSTOM RECIPE DETAIL VIEW (Исправляет ошибку компиляции)
struct RecipeDetailView: View {
    let recipe: CustomRecipe
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss
    
    @State private var showMealSheet = false
    
    var totalProtein: Double { recipe.foodItems.reduce(0) { $0 + $1.protein } }
    var totalFat: Double { recipe.foodItems.reduce(0) { $0 + $1.fats } }
    var totalCarbs: Double { recipe.foodItems.reduce(0) { $0 + $1.carbs } }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Заголовок
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recipe.name)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .padding(.top, 20)
                        
                        HStack(spacing: 16) {
                            Label("\(recipe.cookingTime) min", systemImage: "clock.fill")
                            Label(recipe.difficulty, systemImage: "flame.fill")
                            Label("\(recipe.servings) servings", systemImage: "person.2.fill")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.themeOrange)
                    }
                    .padding(.horizontal, 20)
                    
                    // КРУТАЯ ДИАГРАММА МАКРОСОВ
                    RecipeMacroDonutView(
                        calories: recipe.totalCalories,
                        protein: totalProtein,
                        fat: totalFat,
                        carbs: totalCarbs
                    )
                    .padding(.horizontal, 20)
                    
                    // Ингредиенты
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
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Шаги
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
            
            // ПЛАВАЮЩАЯ КНОПКА
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
        .navigationTitle("Custom Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMealSheet) {
            CustomChooseMealSheet(recipe: recipe)
                .presentationDetents([.fraction(0.4)])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
                .toolbar(.hidden, for: .tabBar) // Скрывает нижний TabBar при переходе сюда
                .sheet(isPresented: $showMealSheet) {
                    CustomChooseMealSheet(recipe: recipe)
                        .presentationDetents([.fraction(0.4)])
                        .presentationCornerRadius(32)
                        .presentationDragIndicator(.visible)
                }
        }
    }
    // Шторка добавления личного рецепта в дневник
    struct CustomChooseMealSheet: View {
        @Environment(\.dismiss) var dismiss
        @Environment(\.modelContext) private var context
        @Query private var summaries: [DailySummary]
        
        let recipe: CustomRecipe
        @State private var selectedMeal = "Breakfast"
        let meals = ["Breakfast", "Lunch", "Dinner", "Snack"]
        
        var body: some View {
            VStack(spacing: 24) {
                Text("Choose a meal").font(.title2.bold()).padding(.top, 24)
                Picker("Meal", selection: $selectedMeal) {
                    ForEach(meals, id: \.self) { meal in Text(meal).tag(meal) }
                }
                .pickerStyle(.wheel).frame(height: 120)
                
                Button(action: {
                    HapticManager.shared.impact(style: .heavy)
                    saveToDiary()
                    dismiss()
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
        
        private func saveToDiary() {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            let summary: DailySummary
            if let existing = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) { summary = existing } else {
                summary = DailySummary(date: today); context.insert(summary)
            }
            let newFood = recipe.toFoodItem()
            if let meal = summary.meals.first(where: { $0.title == selectedMeal }) { meal.foodItems.append(newFood) } else {
                let newMeal = Meal(title: selectedMeal, date: .now, foodItems: [newFood])
                context.insert(newMeal); summary.meals.append(newMeal)
            }
            try? context.save()
        }
    }
}
