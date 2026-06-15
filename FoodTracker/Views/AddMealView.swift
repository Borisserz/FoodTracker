import SwiftUI
import SwiftData

struct AddMealView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @Query private var summaries: [DailySummary]
    @Query private var users: [User]
    
    @State private var selectedMealType = "Breakfast"
    @State private var selectedFoods: [FoodItem] = []
    @State private var showingAddFood = false
    @State private var expandedFoodId: UUID? = nil
    
    let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]
    let selectedDate: Date
    
    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = #Predicate<DailySummary> { $0.date >= startOfDay && $0.date < endOfDay }
        self._summaries = Query(filter: predicate)
    }
    
    // User goal helpers
    private var calorieGoal: Int {
        users.first?.dailyCaloriesGoal ?? 2000
    }
    
    private var proteinGoal: Double {
        users.first?.targetProtein ?? 130
    }
    
    private var carbsGoal: Double {
        users.first?.targetCarbs ?? 250
    }
    
    private var fatsGoal: Double {
        users.first?.targetFats ?? 70
    }
    
    // Current meal nutrients
    private var totalMealCalories: Int {
        selectedFoods.reduce(0) { $0 + $1.calories }
    }
    
    private var totalMealProtein: Double {
        selectedFoods.reduce(0) { $0 + $1.protein }
    }
    
    private var totalMealCarbs: Double {
        selectedFoods.reduce(0) { $0 + $1.carbs }
    }
    
    private var totalMealFats: Double {
        selectedFoods.reduce(0) { $0 + $1.fats }
    }
    
    func localizedMealType(_ type: String) -> String {
        String(localized: String.LocalizationValue(type))
    }
    
    private func mealIcon(for type: String) -> String {
        switch type {
        case "Breakfast": return "🍳"
        case "Lunch": return "🥗"
        case "Dinner": return "🥩"
        case "Snack": return "🍎"
        default: return "🥘"
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color.themeBg.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 1. Dynamic Nutrition Summary Card
                        AddMealSummaryCard(
                            calories: totalMealCalories,
                            protein: totalMealProtein,
                            fats: totalMealFats,
                            carbs: totalMealCarbs,
                            calorieGoal: calorieGoal,
                            proteinGoal: proteinGoal,
                            fatsGoal: fatsGoal,
                            carbsGoal: carbsGoal
                        )
                        .padding(.top, 8)
                        
                        // 2. Meal Type Carousel Selector
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Meal Type")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                ForEach(mealTypes, id: \.self) { type in
                                    let isSelected = selectedMealType == type
                                    Button(action: {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            selectedMealType = type
                                        }
                                        HapticManager.shared.impact(style: .light)
                                    }) {
                                        VStack(spacing: 8) {
                                            Text(mealIcon(for: type))
                                                .font(.system(size: 26))
                                            Text(LocalizedStringKey(type))
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(isSelected ? ThemeManager.shared.current.primaryGradient : LinearGradient(colors: [Color.white], startPoint: .top, endPoint: .bottom))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .cornerRadius(18)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.12), lineWidth: 1)
                                        )
                                        .shadow(color: isSelected ? ThemeManager.shared.current.primaryAccent.opacity(0.25) : Color.black.opacity(0.02), radius: 6, y: 3)
                                    }
                                    .buttonStyle(BounceButtonStyle())
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 3. Logged Food Items Section
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Food Items")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Spacer()
                                if !selectedFoods.isEmpty {
                                    Text("\(selectedFoods.count) items")
                                        .font(.caption.bold())
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal)
                            
                            if selectedFoods.isEmpty {
                                // Empty State View
                                VStack(spacing: 16) {
                                    Image(systemName: "fork.knife")
                                        .font(.system(size: 44))
                                        .foregroundColor(.themeOrange.opacity(0.4))
                                        .padding(.top, 20)
                                    
                                    Text("No food items added yet.")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(.gray)
                                    
                                    Button(action: {
                                        HapticManager.shared.impact(style: .medium)
                                        showingAddFood = true
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add Food Item")
                                        }
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 12)
                                        .background(ThemeManager.shared.current.primaryGradient)
                                        .cornerRadius(20)
                                        .shadow(color: ThemeManager.shared.current.primaryAccent.opacity(0.3), radius: 8, y: 4)
                                    }
                                    .buttonStyle(BounceButtonStyle())
                                    .padding(.bottom, 20)
                                }
                                .frame(maxWidth: .infinity)
                                .ultraPremiumCardStyle()
                                .padding(.horizontal)
                            } else {
                                // Food List with inline expansion
                                LazyVStack(spacing: 12) {
                                    ForEach(selectedFoods, id: \.id) { food in
                                        FoodItemRowCard(
                                            food: food,
                                            isExpanded: expandedFoodId == food.id,
                                            onToggleExpand: {
                                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                    if expandedFoodId == food.id {
                                                        expandedFoodId = nil
                                                    } else {
                                                        expandedFoodId = food.id
                                                    }
                                                }
                                                HapticManager.shared.impact(style: .light)
                                            },
                                            onUpdateWeight: { newWeight in
                                                updateFoodItemWeight(food: food, newWeight: newWeight)
                                            },
                                            onDelete: {
                                                withAnimation(.spring()) {
                                                    if let idx = selectedFoods.firstIndex(where: { $0.id == food.id }) {
                                                        selectedFoods.remove(at: idx)
                                                    }
                                                }
                                            }
                                        )
                                    }
                                    
                                    // Add More Button
                                    Button(action: {
                                        HapticManager.shared.impact(style: .medium)
                                        showingAddFood = true
                                    }) {
                                        HStack {
                                            Image(systemName: "plus.circle.fill")
                                            Text("Add Another Food")
                                        }
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(.themePink)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Color.white)
                                        .cornerRadius(18)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(Color.themePink.opacity(0.2), lineWidth: 1.5)
                                        )
                                        .shadow(color: Color.black.opacity(0.01), radius: 5, y: 2)
                                    }
                                    .buttonStyle(BounceButtonStyle())
                                    .padding(.top, 4)
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer().frame(height: 120)
                    }
                }
                
                // 4. Sticky Bottom Action Overlay
                VStack {
                    Spacer()
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .frame(height: 110)
                            .mask(LinearGradient(colors: [.white, .white, .clear], startPoint: .bottom, endPoint: .top))
                        
                        HStack(spacing: 16) {
                            Button(action: { dismiss() }) {
                                Text("Cancel")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(BounceButtonStyle())
                            
                            Button(action: saveMealAndDismiss) {
                                Text("Save Meal")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background {
                                        if selectedFoods.isEmpty {
                                            Color.gray.opacity(0.3)
                                        } else {
                                            ThemeManager.shared.current.primaryGradient
                                        }
                                    }
                                    .cornerRadius(20)
                                    .shadow(color: selectedFoods.isEmpty ? Color.clear : ThemeManager.shared.current.primaryAccent.opacity(0.35), radius: 8, y: 4)
                            }
                            .disabled(selectedFoods.isEmpty)
                            .buttonStyle(BounceButtonStyle())
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                    }
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle("Log Meal")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.themePink)
            .sheet(isPresented: $showingAddFood) {
                SmartAddFoodView(mealTitle: localizedMealType(selectedMealType)) { newItems in
                    self.selectedFoods.append(contentsOf: newItems)
                }
                .presentationDetents([.fraction(0.85), .large])
                .presentationCornerRadius(32)
            }
        }
    }
    
    // Scaling helpers
    private func updateFoodItemWeight(food: FoodItem, newWeight: Double) {
        let oldWeight = food.weight > 0 ? food.weight : 100.0
        let multiplier = newWeight / oldWeight
        
        food.weight = newWeight
        food.calories = Int(Double(food.calories) * multiplier)
        food.protein = food.protein * multiplier
        food.fats = food.fats * multiplier
        food.carbs = food.carbs * multiplier
        
        food.omega3 *= multiplier
        food.calcium *= multiplier
        food.potassium *= multiplier
        food.magnesium *= multiplier
        food.iron *= multiplier
        food.vitaminC *= multiplier
        food.vitaminD *= multiplier
        
        // Force view refresh by updating the array reference
        if let index = selectedFoods.firstIndex(where: { $0.id == food.id }) {
            selectedFoods[index] = food
        }
    }
    
    private func saveMealAndDismiss() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        
        let summaryToUse: DailySummary
        if let existingSummary = summaries.first {
            summaryToUse = existingSummary
        } else {
            summaryToUse = DailySummary(date: startOfDay)
            modelContext.insert(summaryToUse)
        }
        
        if let existingMeal = summaryToUse.meals.first(where: { $0.title == selectedMealType }) {
            existingMeal.foodItems.append(contentsOf: selectedFoods)
        } else {
            let newMeal = Meal(title: selectedMealType, date: selectedDate, foodItems: selectedFoods)
            summaryToUse.meals.append(newMeal)
        }
        
        do {
            try modelContext.save()
            
            if let user = users.first, user.isHealthKitEnabled {
                let caloriesToSave = totalMealCalories
                let dateToSave = selectedDate
                Task {
                    await HealthKitManager.shared.saveDietaryEnergy(calories: caloriesToSave, date: dateToSave)
                }
            }
            
            dismiss()
        } catch {
            print("Failed to save meal: \(error.localizedDescription)")
        }
    }
}

// MARK: - Subviews

private struct AddMealSummaryCard: View {
    let calories: Int
    let protein: Double
    let fats: Double
    let carbs: Double
    
    let calorieGoal: Int
    let proteinGoal: Double
    let fatsGoal: Double
    let carbsGoal: Double
    
    private var progress: Double {
        calorieGoal > 0 ? Double(calories) / Double(calorieGoal) : 0.0
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 24) {
                // Calorie Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.1), lineWidth: 10)
                    
                    Circle()
                        .trim(from: 0.0, to: min(progress, 1.0))
                        .stroke(
                            ThemeManager.shared.current.primaryGradient,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text("\(calories)")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        Text("kcal")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 88, height: 88)
                
                // Text info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(calories)")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                        Text("/ \(calorieGoal) kcal")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    let remaining = calorieGoal - calories
                    if remaining >= 0 {
                        Text("Calories Left: **\(remaining)**")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.themeOrange)
                    } else {
                        Text("Over Goal: **\(abs(remaining))**")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.red)
                    }
                }
                Spacer()
            }
            
            Divider()
            
            // Macro Grid/Pills
            HStack(spacing: 12) {
                MacroSummaryMiniProgress(title: "Proteins", current: protein, goal: proteinGoal, color: .themePink)
                MacroSummaryMiniProgress(title: "Carbs", current: carbs, goal: carbsGoal, color: .blue)
                MacroSummaryMiniProgress(title: "Fats", current: fats, goal: fatsGoal, color: .orange)
            }
        }
        .padding(20)
        .glassEffect()
        .padding(.horizontal)
    }
}

private struct MacroSummaryMiniProgress: View {
    let title: String
    let current: Double
    let goal: Double
    let color: Color
    
    private var progress: Double {
        goal > 0 ? current / goal : 0.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.1f g", current))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * min(progress, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FoodItemRowCard: View {
    let food: FoodItem
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onUpdateWeight: (Double) -> Void
    let onDelete: () -> Void
    
    private func emojiForFood(_ name: String) -> String {
        let nameLower = name.lowercased()
        if nameLower.contains("yogurt") || nameLower.contains("йогурт") { return "🥛" }
        if nameLower.contains("granola") || nameLower.contains("гранола") || nameLower.contains("овсян") || nameLower.contains("oat") { return "🥣" }
        if nameLower.contains("coffee") || nameLower.contains("кофе") { return "☕️" }
        if nameLower.contains("apple") || nameLower.contains("яблоко") { return "🍎" }
        if nameLower.contains("chicken") || nameLower.contains("куриц") { return "🍗" }
        if nameLower.contains("avocado") || nameLower.contains("авокадо") { return "🥑" }
        if nameLower.contains("egg") || nameLower.contains("яйцо") || nameLower.contains("яиц") { return "🍳" }
        if nameLower.contains("salad") || nameLower.contains("салат") { return "🥗" }
        if nameLower.contains("meat") || nameLower.contains("мясо") || nameLower.contains("steak") || nameLower.contains("стейк") { return "🥩" }
        if nameLower.contains("banana") || nameLower.contains("банан") { return "🍌" }
        if nameLower.contains("fish") || nameLower.contains("рыба") || nameLower.contains("salmon") || nameLower.contains("лосось") { return "🐟" }
        if nameLower.contains("water") || nameLower.contains("вода") { return "💧" }
        return "🥘"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggleExpand) {
                HStack(spacing: 16) {
                    Text(emojiForFood(food.name))
                        .font(.system(size: 26))
                        .frame(width: 46, height: 46)
                        .background(Color.themeBg.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        
                        Text(String(format: "%dg • P: %.1f g • F: %.1f g • C: %.1f g", Int(food.weight), food.protein, food.fats, food.carbs))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("\(food.calories) kcal")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.themePink)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.gray)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)
                
                VStack(spacing: 16) {
                    HStack {
                        Text("Portion Weight")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.gray)
                        Spacer()
                        
                        HStack(spacing: 14) {
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                onUpdateWeight(max(10, food.weight - 10))
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                            
                            Text("\(Int(food.weight)) g")
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .frame(width: 60)
                            
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                onUpdateWeight(food.weight + 10)
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        ForEach([50, 100, 150, 200], id: \.self) { amount in
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                onUpdateWeight(Double(amount))
                            }) {
                                Text("\(amount)g")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(food.weight == Double(amount) ? Color.themePink.opacity(0.15) : Color.gray.opacity(0.06))
                                    .foregroundColor(food.weight == Double(amount) ? .themePink : .primary)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            onDelete()
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red.opacity(0.8))
                                .padding(8)
                                .background(Color.red.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(16)
                .background(Color.gray.opacity(0.01))
            }
        }
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isExpanded ? Color.themePink.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
    }
}
