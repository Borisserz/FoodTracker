import SwiftUI
import SwiftData

struct WeeklyPlanOverview: View {
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Query private var summaries: [DailySummary]
    
    let plan: WeeklyMealPlan
    let onDismiss: () -> Void
    
    @State private var selectedDayIndex = 0
    @State private var showSuccessToast = false
    @State private var selectedMealForDetails: MealPlanItem?
    
    @Namespace private var daySelectionAnimation
    
    var selectedDay: MealPlanDay? {
        (plan.days ?? []).first(where: { $0.dayIndex == selectedDayIndex })
    }
    
    let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                // Header & AI Summary
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(LocalizedStringKey("AI Weekly Protocol"))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    
                    // AI Summary Card
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey("Optimal Synergy Reached"))
                                .font(.caption.bold())
                                .foregroundColor(themeManager.current.primaryAccent)
                                .textCase(.uppercase)
                            
                            Text(LocalizedStringKey("A perfect 7-day alignment tailored to your metabolic goals."))
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(themeManager.current.primaryGradient)
                            .symbolEffect(.pulse)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
                
                // Days Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<7) { index in
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    selectedDayIndex = index
                                }
                            }) {
                                VStack(spacing: 6) {
                                    Text(LocalizedStringKey(dayNames[index]))
                                        .font(.caption)
                                        .fontWeight(.heavy)
                                        .foregroundColor(selectedDayIndex == index ? .white : .gray)
                                    
                                    Text(LocalizedStringKey("D\(index + 1)"))
                                        .font(.title3)
                                        .fontWeight(.black)
                                        .foregroundColor(selectedDayIndex == index ? .white : .primary)
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(
                                    ZStack {
                                        if selectedDayIndex == index {
                                            Capsule()
                                                .fill(themeManager.current.primaryGradient)
                                                .matchedGeometryEffect(id: "dayBackground", in: daySelectionAnimation)
                                                .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 10, y: 5)
                                        } else {
                                            Capsule()
                                                .fill(Color.white)
                                        }
                                    }
                                )
                                .scaleEffect(selectedDayIndex == index ? 1.05 : 1.0)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
                
                // Meals List
                if let day = selectedDay {
                        VStack(spacing: 24) {
                            // Day Summary (Macronutrients)
                            HStack {
                                macroGodView(title: String(localized: "Energy"), value: "\(day.totalCalories)", icon: "flame.fill", color: themeManager.current.primaryAccent)
                                Spacer()
                                macroGodView(title: String(localized: "Protein"), value: "\(day.totalProtein)g", icon: "bolt.fill", color: .red)
                                Spacer()
                                macroGodView(title: String(localized: "Carbs"), value: "\(day.totalCarbs)g", icon: "leaf.fill", color: .blue)
                                Spacer()
                                macroGodView(title: String(localized: "Fats"), value: "\(day.totalFat)g", icon: "drop.fill", color: .orange)
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .cornerRadius(32)
                            .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.white.opacity(0.5), lineWidth: 1))
                            .shadow(color: .black.opacity(0.04), radius: 10, y: 5)
                            
                            VStack(spacing: 20) {
                                ForEach((day.meals ?? []).sorted(by: { typePriority($0.type) < typePriority($1.type) })) { meal in
                                    Button(action: {
                                        HapticManager.shared.impact(style: .light)
                                        selectedMealForDetails = meal
                                    }) {
                                        GodTierMealCard(meal: meal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                                            removal: .opacity
                                        ))
                                }
                            }
                            
                            Spacer().frame(height: 140) // Space for bottom action bar
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            
            // Floating Action Dock
            VStack(spacing: 8) {
                if showSuccessToast {
                    Text("✅ Synced with Daily Log")
                        .font(.headline.bold())
                        .foregroundColor(.green)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .cornerRadius(30)
                        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.green.opacity(0.3), lineWidth: 1))
                        .shadow(radius: 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                    HStack(spacing: 16) {
                        Button(action: applyToToday) {
                            HStack {
                                Image(systemName: "tray.and.arrow.down.fill")
                                Text("Execute Today")
                            }
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(themeManager.current.primaryGradient)
                            .cornerRadius(20)
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 15, y: 8)
                        }
                        .disabled(showSuccessToast)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $selectedMealForDetails) { meal in
            MealPlanItemDetailView(meal: meal)
        }
    }
    private func macroGodView(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .textCase(.uppercase)
        }
    }
    
    private func typePriority(_ type: String) -> Int {
        switch type {
        case "Breakfast": return 0
        case "Lunch": return 1
        case "Dinner": return 2
        case "Snack": return 3
        default: return 4
        }
    }
    
    private func applyToToday() {
        HapticManager.shared.impact(style: .heavy)
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        var currentSummary: DailySummary
        
        if let existing = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            currentSummary = existing
        } else {
            currentSummary = DailySummary(date: startOfDay)
            context.insert(currentSummary)
        }
        
        if let day = selectedDay {
            for planMeal in (day.meals ?? []) {
                let foodItem = FoodItem(name: planMeal.title, weight: 100.0, calories: Int(planMeal.calories), protein: Double(planMeal.protein), fats: Double(planMeal.fat), carbs: Double(planMeal.carbs), omega3: planMeal.omega3, calcium: planMeal.calcium, potassium: planMeal.potassium, magnesium: planMeal.magnesium, iron: planMeal.iron, vitaminC: planMeal.vitaminC, vitaminD: planMeal.vitaminD)
                
                if let existingMeal = (currentSummary.meals ?? []).first(where: { $0.title == planMeal.type }) {
                    existingMeal.foodItems = (existingMeal.foodItems ?? []) + [foodItem]
                } else {
                    let newMeal = Meal(title: planMeal.type, date: Date(), foodItems: [foodItem])
                    currentSummary.meals = (currentSummary.meals ?? []) + [newMeal]
                }
            }
        }
        
        try? context.save()
        
        withAnimation(.spring()) {
            showSuccessToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            onDismiss()
        }
    }
}

struct GodTierMealCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let meal: MealPlanItem
    
    var gradientForMeal: LinearGradient {
        let t = meal.type.lowercased()
        if t.contains("breakfast") { return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing) }
        if t.contains("lunch") { return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing) }
        if t.contains("dinner") { return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) }
        return LinearGradient(colors: [.gray, .gray.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    var iconForMeal: String {
        let t = meal.type.lowercased()
        if t.contains("breakfast") { return "sun.max.fill" }
        if t.contains("lunch") { return "sun.haze.fill" }
        if t.contains("dinner") { return "moon.stars.fill" }
        return "fork.knife"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            QueuedAsyncImageView(
                searchQuery: meal.imageQuery.isEmpty ? meal.title : meal.imageQuery,
                fallbackImageName: AINutritionService.shared.fallbackLocalImage(for: meal.title),
                gradientForMeal: gradientForMeal
            )
            .frame(height: 140)
            .clipped()
            .frame(height: 140)
            .overlay(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: iconForMeal)
                        Text(meal.type)
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.gray.opacity(0.1), lineWidth: 1))
                    .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(themeManager.current.primaryAccent)
                        Text("\(meal.calories)")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(themeManager.current.primaryAccent)
                    }
                }
                
                Text(meal.title)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(meal.ingredients)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                
                Divider()
                
                HStack {
                    Label("\(meal.prepTimeMinutes) min", systemImage: "clock.fill")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                    Spacer()
                    HStack(spacing: 12) {
                        Text("P: \(meal.protein)g")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                        Text("C: \(meal.carbs)g")
                            .font(.caption.bold())
                            .foregroundColor(.blue)
                        Text("F: \(meal.fat)g")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.5))
                    .clipShape(Capsule())
                }
            }
            .padding(24)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.white.opacity(0.5), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 15, y: 10)
    }
}

// MARK: - Meal Detail View
struct MealPlanItemDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Query private var summaries: [DailySummary]
    
    let meal: MealPlanItem
    
    @State private var isGeneratingRecipe = false
    @State private var generatedRecipe: AIChefRecipe?
    @State private var showSuccessToast = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.themeBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        QueuedAsyncImageView(
                            searchQuery: meal.imageQuery.isEmpty ? meal.title : meal.imageQuery,
                            fallbackImageName: AINutritionService.shared.fallbackLocalImage(for: meal.title),
                            gradientForMeal: LinearGradient(colors: [themeManager.current.primaryAccent.opacity(0.6), Color.themePink.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(height: 220)
                        .clipped()
                        .cornerRadius(24)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                        
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(meal.type.uppercased())
                                .font(.caption.bold())
                                .foregroundColor(themeManager.current.primaryAccent)
                            
                            Text(meal.title)
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal)
                        
                        // Macros
                        HStack {
                            macroGodView(title: String(localized: "Energy"), value: "\(meal.calories)", icon: "flame.fill", color: themeManager.current.primaryAccent)
                            Spacer()
                            macroGodView(title: String(localized: "Protein"), value: "\(meal.protein)g", icon: "bolt.fill", color: .red)
                            Spacer()
                            macroGodView(title: String(localized: "Carbs"), value: "\(meal.carbs)g", icon: "leaf.fill", color: .blue)
                            Spacer()
                            macroGodView(title: String(localized: "Fats"), value: "\(meal.fat)g", icon: "drop.fill", color: .orange)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .padding(.horizontal)
                        
                        // Ingredients
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Ingredients")
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                            
                            let ingredientsList = meal.ingredients.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(ingredientsList, id: \.self) { ingredient in
                                    HStack(spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text(ingredient)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: .black.opacity(0.02), radius: 5, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Instructions
                        if !meal.instructions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Cooking Instructions")
                                    .font(.title2.bold())
                                    .foregroundColor(.primary)
                                
                                Text(meal.instructions)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineSpacing(6)
                                    .padding()
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(16)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Nutrition Facts
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Nutrition Facts")
                                .font(.title3.bold())
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)

                            VStack(spacing: 0) {
                                MealPlanNutritionRow(title: String(localized: "Proteins"), value: Double(meal.protein), unit: "g")
                                MealPlanNutritionRow(title: String(localized: "Total Fat"), value: Double(meal.fat), unit: "g")
                                MealPlanNutritionRow(title: String(localized: "Carbs"), value: Double(meal.carbs), unit: "g")

                                Text("Vitamins & Minerals")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding(.top, 24)
                                    .padding(.bottom, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                MealPlanNutritionRow(title: String(localized: "Vitamin C"), value: meal.vitaminC, unit: "mg")
                                MealPlanNutritionRow(title: String(localized: "Vitamin D"), value: meal.vitaminD, unit: "mcg")
                                MealPlanNutritionRow(title: String(localized: "Calcium"), value: meal.calcium, unit: "mg")
                                MealPlanNutritionRow(title: String(localized: "Iron"), value: meal.iron, unit: "mg")
                                MealPlanNutritionRow(title: String(localized: "Magnesium"), value: meal.magnesium, unit: "mg")
                                MealPlanNutritionRow(title: String(localized: "Potassium"), value: meal.potassium, unit: "mg")
                                MealPlanNutritionRow(title: String(localized: "Omega-3"), value: meal.omega3, unit: "g")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .cornerRadius(24)
                            .padding(.horizontal, 20)
                            .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                        }

                        Spacer().frame(height: 140)
                    }
                }
                
                // Bottom Action Buttons
                VStack(spacing: 12) {
                    if showSuccessToast {
                        Text("✅ \(String(localized: "Added to")) \(String(localized: String.LocalizationValue(meal.type)))")
                            .font(.headline.bold())
                            .foregroundColor(.green)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .cornerRadius(30)
                            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.green.opacity(0.3), lineWidth: 1))
                            .shadow(radius: 10)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    HStack(spacing: 16) {
                        Button(action: logToMeal) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("\(String(localized: "Add to")) \(String(localized: String.LocalizationValue(meal.type)))")
                            }
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.green)
                            .cornerRadius(16)
                            .shadow(color: .green.opacity(0.3), radius: 10, y: 5)
                        }
                        
                        Button(action: generateRecipe) {
                            HStack {
                                if isGeneratingRecipe {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text("Cook with Chef")
                            }
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(themeManager.current.primaryGradient)
                            .cornerRadius(16)
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 10, y: 5)
                        }
                        .disabled(isGeneratingRecipe)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .ignoresSafeArea(edges: .bottom)
                .fullScreenCover(item: $generatedRecipe) { recipe in
                    NavigationStack {
                        PrepChecklistView(
                            recipe: recipe,
                            isFlowPresented: Binding(
                                get: { generatedRecipe != nil },
                                set: { if !$0 { generatedRecipe = nil } }
                            )
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
            }
        }
    }
    
    private func logToMeal() {
        HapticManager.shared.impact(style: .medium)
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        var currentSummary: DailySummary
        
        if let existing = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            currentSummary = existing
        } else {
            currentSummary = DailySummary(date: startOfDay)
            context.insert(currentSummary)
        }
        
        let foodItem = FoodItem(name: meal.title, weight: 100.0, calories: Int(meal.calories), protein: Double(meal.protein), fats: Double(meal.fat), carbs: Double(meal.carbs), omega3: meal.omega3, calcium: meal.calcium, potassium: meal.potassium, magnesium: meal.magnesium, iron: meal.iron, vitaminC: meal.vitaminC, vitaminD: meal.vitaminD)
        
        if let existingMeal = (currentSummary.meals ?? []).first(where: { $0.title == meal.type }) {
            existingMeal.foodItems = (existingMeal.foodItems ?? []) + [foodItem]
        } else {
            let newMeal = Meal(title: meal.type, date: Date(), foodItems: [foodItem])
            currentSummary.meals = (currentSummary.meals ?? []) + [newMeal]
        }
        
        try? context.save()
        
        withAnimation(.spring()) {
            showSuccessToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring()) {
                showSuccessToast = false
            }
        }
    }
    
    private func generateRecipe() {
        let mealName = meal.title
        let ingredientsList = meal.ingredients.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        
        isGeneratingRecipe = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            let dto = await AINutritionService.shared.generateCookingSteps(for: mealName, ingredients: ingredientsList)
            DispatchQueue.main.async {
                isGeneratingRecipe = false
                if let dto = dto {
                    HapticManager.shared.notification(type: .success)
                    self.generatedRecipe = AIChefRecipe(
                        title: dto.title,
                        calories: dto.calories,
                        protein: dto.protein,
                        heroImage: "agent_chef",
                        cookTime: dto.cookTime,
                        difficulty: dto.difficulty,
                        history: dto.history,
                        ingredients: dto.ingredients,
                        steps: dto.steps.map { RecipeStep(instruction: $0.instruction, imageName: "", aiTip: $0.aiTip) },
                        platingTip: dto.platingTip
                    )
                } else {
                    HapticManager.shared.notification(type: .error)
                }
            }
        }
    }
    
    private func macroGodView(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.gray)
                .textCase(.uppercase)
        }
    }
}

private struct MealPlanNutritionRow: View {
    let title: String
    let value: Double
    let unit: String

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

struct QueuedAsyncImageView: View {
    let searchQuery: String          // теперь принимаем название блюда или англ. запрос
    let fallbackImageName: String
    let gradientForMeal: LinearGradient

    enum LoadState { case empty, success(Image), failure }
    @State private var state: LoadState = .empty

    var body: some View {
        Group {
            switch state {
            case .empty:
                ZStack {
                    Rectangle()
                        .fill(gradientForMeal.opacity(0.3))
                    ProgressView()
                        .tint(.white)
                }
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .failure:
                Image(fallbackImageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .task(id: searchQuery) {
            await load()
        }
    }

    private func load() async {
        // 1) Pexels — точное совпадение по блюду
        if let url = await AINutritionService.shared.resolveImageURL(forMealTitle: searchQuery),
           let img = try? await PollinationsImageLoader.shared.fetchImage(url: url) {
            if !Task.isCancelled {
                await MainActor.run { state = .success(Image(uiImage: img)) }
            }
            return
        }
        // 2) Fallback — стоковое фото по ключевым словам
        if let url = URL(string: AINutritionService.shared.imageUrl(forMealTitle: searchQuery)),
           let img = try? await PollinationsImageLoader.shared.fetchImage(url: url) {
            if !Task.isCancelled {
                await MainActor.run { state = .success(Image(uiImage: img)) }
            }
            return
        }
        // 3) Финальный fallback — локальная картинка из ассетов
        if !Task.isCancelled {
            await MainActor.run { state = .failure }
        }
    }
}
