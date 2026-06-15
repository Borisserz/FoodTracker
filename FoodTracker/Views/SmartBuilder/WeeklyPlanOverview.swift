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
        plan.days.first(where: { $0.dayIndex == selectedDayIndex })
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
                        Text("AI Weekly Protocol")
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
                            Text("Optimal Synergy Reached")
                                .font(.caption.bold())
                                .foregroundColor(themeManager.current.primaryAccent)
                                .textCase(.uppercase)
                            
                            Text("A perfect 7-day alignment tailored to your metabolic goals.")
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
                                    Text(dayNames[index])
                                        .font(.caption)
                                        .fontWeight(.heavy)
                                        .foregroundColor(selectedDayIndex == index ? .white : .gray)
                                    
                                    Text("D\(index + 1)")
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
                                macroGodView(title: "Energy", value: "\(day.totalCalories)", icon: "flame.fill", color: themeManager.current.primaryAccent)
                                Spacer()
                                macroGodView(title: "Protein", value: "\(day.totalProtein)g", icon: "bolt.fill", color: .red)
                                Spacer()
                                macroGodView(title: "Carbs", value: "\(day.totalCarbs)g", icon: "leaf.fill", color: .blue)
                                Spacer()
                                macroGodView(title: "Fats", value: "\(day.totalFat)g", icon: "drop.fill", color: .orange)
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .cornerRadius(32)
                            .overlay(RoundedRectangle(cornerRadius: 32).stroke(Color.white.opacity(0.5), lineWidth: 1))
                            .shadow(color: .black.opacity(0.04), radius: 10, y: 5)
                            
                            VStack(spacing: 20) {
                                ForEach(day.meals.sorted(by: { typePriority($0.type) < typePriority($1.type) })) { meal in
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
            for planMeal in day.meals {
                let foodItem = FoodItem(name: planMeal.title, weight: 100.0, calories: Int(planMeal.calories), protein: Double(planMeal.protein), fats: Double(planMeal.fat), carbs: Double(planMeal.carbs), omega3: planMeal.omega3, calcium: planMeal.calcium, potassium: planMeal.potassium, magnesium: planMeal.magnesium, iron: planMeal.iron, vitaminC: planMeal.vitaminC, vitaminD: planMeal.vitaminD)
                
                if let existingMeal = currentSummary.meals.first(where: { $0.title == planMeal.type }) {
                    existingMeal.foodItems.append(foodItem)
                } else {
                    let newMeal = Meal(title: planMeal.type, date: Date(), foodItems: [foodItem])
                    currentSummary.meals.append(newMeal)
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
        switch meal.type {
        case "Breakfast": return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Lunch": return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Dinner": return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        default: return LinearGradient(colors: [.gray, .gray.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    var iconForMeal: String {
        switch meal.type {
        case "Breakfast": return "sun.max.fill"
        case "Lunch": return "sun.haze.fill"
        case "Dinner": return "moon.stars.fill"
        default: return "fork.knife"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !meal.imageUrl.isEmpty {
                AsyncImage(url: URL(string: meal.imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipped()
                    case .failure(_), .empty:
                        ZStack {
                            Rectangle()
                                .fill(gradientForMeal.opacity(0.3))
                                .frame(height: 140)
                            Image(systemName: "fork.knife")
                                .font(.title)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 140)
                .overlay(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
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
                        if !meal.imageUrl.isEmpty {
                            AsyncImage(url: URL(string: meal.imageUrl)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 220)
                                        .clipped()
                                case .failure(_), .empty:
                                    ZStack {
                                        Rectangle()
                                            .fill(LinearGradient(colors: [themeManager.current.primaryAccent.opacity(0.6), Color.themePink.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(height: 220)
                                        Image(systemName: "fork.knife")
                                            .font(.system(size: 48))
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(height: 220)
                            .cornerRadius(24)
                            .padding(.horizontal)
                            .padding(.top, 16)
                            .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                        }
                        
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
                            macroGodView(title: "Energy", value: "\(meal.calories)", icon: "flame.fill", color: themeManager.current.primaryAccent)
                            Spacer()
                            macroGodView(title: "Protein", value: "\(meal.protein)g", icon: "bolt.fill", color: .red)
                            Spacer()
                            macroGodView(title: "Carbs", value: "\(meal.carbs)g", icon: "leaf.fill", color: .blue)
                            Spacer()
                            macroGodView(title: "Fats", value: "\(meal.fat)g", icon: "drop.fill", color: .orange)
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
                                MealPlanNutritionRow(title: "Proteins", value: Double(meal.protein), unit: "g")
                                MealPlanNutritionRow(title: "Total Fat", value: Double(meal.fat), unit: "g")
                                MealPlanNutritionRow(title: "Carbs", value: Double(meal.carbs), unit: "g")

                                Text("Vitamins & Minerals")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding(.top, 24)
                                    .padding(.bottom, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                MealPlanNutritionRow(title: "Vitamin C", value: meal.vitaminC, unit: "mg")
                                MealPlanNutritionRow(title: "Vitamin D", value: meal.vitaminD, unit: "mcg")
                                MealPlanNutritionRow(title: "Calcium", value: meal.calcium, unit: "mg")
                                MealPlanNutritionRow(title: "Iron", value: meal.iron, unit: "mg")
                                MealPlanNutritionRow(title: "Magnesium", value: meal.magnesium, unit: "mg")
                                MealPlanNutritionRow(title: "Potassium", value: meal.potassium, unit: "mg")
                                MealPlanNutritionRow(title: "Omega-3", value: meal.omega3, unit: "g")
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
                        Text("✅ Added to \(meal.type)")
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
                                Text("Add to \(meal.type)")
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
        
        if let existingMeal = currentSummary.meals.first(where: { $0.title == meal.type }) {
            existingMeal.foodItems.append(foodItem)
        } else {
            let newMeal = Meal(title: meal.type, date: Date(), foodItems: [foodItem])
            currentSummary.meals.append(newMeal)
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
