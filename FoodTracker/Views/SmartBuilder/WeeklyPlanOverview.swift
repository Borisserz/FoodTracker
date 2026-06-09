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
    @State private var showGrocerySuccess = false
    
    var selectedDay: MealPlanDay? {
        plan.days.first(where: { $0.dayIndex == selectedDayIndex })
    }
    
    let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Your AI Plan")
                    .font(.title2.bold())
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            
            // Days Carousel
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<7) { index in
                        Button(action: {
                            withAnimation { selectedDayIndex = index }
                            HapticManager.shared.impact(style: .light)
                        }) {
                            VStack(spacing: 8) {
                                Text(dayNames[index])
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(selectedDayIndex == index ? .white : .gray)
                                
                                Text("Day \(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.black)
                                    .foregroundColor(selectedDayIndex == index ? .white : .primary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(selectedDayIndex == index ? themeManager.current.primaryAccent : Color.white)
                            .cornerRadius(16)
                            .shadow(color: selectedDayIndex == index ? themeManager.current.primaryAccent.opacity(0.3) : .black.opacity(0.05), radius: 5, y: 2)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            
            // Meals List
            ScrollView(showsIndicators: false) {
                if let day = selectedDay {
                    VStack(spacing: 16) {
                        // Day Summary
                        HStack(spacing: 20) {
                            macroView(title: "Cals", value: "\(day.totalCalories)", color: themeManager.current.primaryAccent)
                            macroView(title: "Protein", value: "\(day.totalProtein)g", color: .red)
                            macroView(title: "Carbs", value: "\(day.totalCarbs)g", color: .blue)
                            macroView(title: "Fat", value: "\(day.totalFat)g", color: .orange)
                        }
                        .padding(.bottom, 8)
                        
                        ForEach(day.meals.sorted(by: { typePriority($0.type) < typePriority($1.type) })) { meal in
                            MealPlanItemCard(meal: meal)
                        }
                    }
                    .padding()
                }
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                if showSuccessToast {
                    Text("✅ Applied to Today's Log!")
                        .font(.subheadline.bold())
                        .foregroundColor(.green)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if showGrocerySuccess {
                    Text("🛒 Ingredients added to Grocery List!")
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                HStack(spacing: 16) {
                    Button(action: generateGroceryList) {
                        HStack {
                            Image(systemName: "cart.fill.badge.plus")
                            Text("Groceries")
                        }
                        .font(.headline)
                        .foregroundColor(themeManager.current.primaryAccent)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.current.primaryAccent.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .disabled(showGrocerySuccess)
                    
                    Button(action: applyToToday) {
                        HStack {
                            Image(systemName: "tray.and.arrow.down.fill")
                            Text("Apply to Today")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.current.primaryGradient)
                        .cornerRadius(16)
                        .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 10, y: 5)
                    }
                    .disabled(showSuccessToast)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
        }
        .background(Color.themeBg)
    }
    
    private func macroView(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.bold())
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
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
        HapticManager.shared.impact(style: .medium)
        
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
                let meal = Meal(title: planMeal.type, date: startOfDay, foodItems: [])
                
                let foodItem = FoodItem(name: planMeal.title, weight: 100.0, calories: Int(planMeal.calories), protein: Double(planMeal.protein), fats: Double(planMeal.fat), carbs: Double(planMeal.carbs))
                
                meal.foodItems.append(foodItem)
                currentSummary.meals.append(meal)
            }
        }
        
        try? context.save()
        
        withAnimation {
            showSuccessToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            onDismiss()
        }
    }
    
    private func generateGroceryList() {
        HapticManager.shared.impact(style: .medium)
        
        var allIngredients: Set<String> = []
        for day in plan.days {
            for meal in day.meals {
                let parts = meal.ingredients.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                for part in parts where !part.isEmpty {
                    allIngredients.insert(part)
                }
            }
        }
        
        for ingredient in allIngredients {
            let item = ShoppingItem(name: ingredient, amount: "", isChecked: false, addedFromRecipe: "AI Weekly Plan")
            context.insert(item)
        }
        
        try? context.save()
        
        withAnimation {
            showGrocerySuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showGrocerySuccess = false }
        }
    }
}

struct MealPlanItemCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let meal: MealPlanItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(meal.type)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(themeManager.current.primaryAccent.opacity(0.1))
                    .foregroundColor(themeManager.current.primaryAccent)
                    .cornerRadius(8)
                
                Spacer()
                
                Text("\(meal.calories) kcal")
                    .font(.headline)
                    .foregroundColor(themeManager.current.primaryAccent)
            }
            
            Text(meal.title)
                .font(.title3.bold())
            
            Text(meal.ingredients)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack {
                Label("\(meal.prepTimeMinutes) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text("P: \(meal.protein)g")
                    .font(.caption.bold())
                    .foregroundColor(.red)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
    }
}
