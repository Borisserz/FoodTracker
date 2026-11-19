import SwiftUI
import SwiftData

struct WeeklyPlanOverview: View {
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Query private var users: [User]
    
    let plan: WeeklyMealPlan
    let onDismiss: () -> Void
    
    @State private var selectedDayIndex = 0
    @State private var showSuccessToast = false
    @State private var showGrocerySuccess = false
    
    var selectedDay: MealPlanDay? {
        (plan.days ?? []).first(where: { $0.dayIndex == selectedDayIndex })
    }
    
    let dayNames = [
        String(localized: "Mon"),
        String(localized: "Tue"),
        String(localized: "Wed"),
        String(localized: "Thu"),
        String(localized: "Fri"),
        String(localized: "Sat"),
        String(localized: "Sun")
    ]
    
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
                if let day = selectedDay, !(day.meals ?? []).isEmpty {
                    VStack(spacing: 16) {
                        // Day Summary
                        HStack(spacing: 20) {
                            macroView(title: "Cals", value: "\(day.totalCalories)", color: themeManager.current.primaryAccent)
                            macroView(title: "Protein", value: "\(day.totalProtein)g", color: .red)
                            macroView(title: "Carbs", value: "\(day.totalCarbs)g", color: .blue)
                            macroView(title: "Fat", value: "\(day.totalFat)g", color: .orange)
                        }
                        .padding(.bottom, 8)
                        
                        ForEach((day.meals ?? []).sorted(by: { typePriority($0.type) < typePriority($1.type) })) { meal in
                            MealPlanItemCard(meal: meal)
                        }
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No meals generated for this day.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
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
                        .background((selectedDay?.meals ?? []).isEmpty ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(themeManager.current.primaryGradient))
                        .cornerRadius(16)
                        .shadow(color: (selectedDay?.meals ?? []).isEmpty ? .clear : themeManager.current.primaryAccent.opacity(0.3), radius: 10, y: 5)
                    }
                    .disabled(showSuccessToast || (selectedDay?.meals ?? []).isEmpty)
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
            Text(LocalizedStringKey(title))
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
    
    private func typePriority(_ type: String) -> Int {
        switch NutritionMath.canonicalMealType(type) {
        case "Breakfast": return 0
        case "Lunch": return 1
        case "Dinner": return 2
        case "Snack": return 3
        default: return 4
        }
    }
    
    private func applyToToday() {
        guard let day = selectedDay, let dayMeals = day.meals, !dayMeals.isEmpty else { return }
        HapticManager.shared.impact(style: .medium)
        
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let currentSummary = DailySummary.fetchOrCreate(for: startOfDay, in: context)
        
        var addedItems: [FoodItem] = []
        for planMeal in dayMeals {
            let canonicalType = NutritionMath.canonicalMealType(planMeal.type)
            let cals = Int(planMeal.calories)
            let micros = MicronutrientEstimator.estimate(
                name: planMeal.title,
                calories: cals,
                protein: Double(planMeal.protein),
                fat: Double(planMeal.fat),
                carbs: Double(planMeal.carbs),
                weight: 100.0
            )
            let foodItem = FoodItem(
                name: planMeal.title,
                weight: 100.0,
                calories: cals,
                protein: Double(planMeal.protein),
                fats: Double(planMeal.fat),
                carbs: Double(planMeal.carbs),
                omega3: micros.omega3,
                calcium: micros.calcium,
                potassium: micros.potassium,
                magnesium: micros.magnesium,
                iron: micros.iron,
                vitaminC: micros.vitaminC,
                vitaminD: micros.vitaminD
            )
            context.insert(foodItem)
            if cals > 0 {
                addedItems.append(foodItem)
            }

            if let existingMeal = (currentSummary.meals ?? []).first(where: { DailySummary.canonicalMealSlot($0.title) == canonicalType }) {
                existingMeal.addFoodItem(foodItem)
                existingMeal.date = Date.now
            } else {
                let meal = Meal(title: canonicalType, date: Date.now, foodItems: [foodItem])
                context.insert(meal)
                currentSummary.addMeal(meal)
            }
        }
        
        try? context.save()
        WidgetReloader.reloadAll()
        AppReviewManager.shared.userDidLogMeal()
        if users.first?.isHealthKitEnabled == true && !addedItems.isEmpty {
            let now = Date.now
            let container = context.container
            Task { @MainActor in
                for item in addedItems {
                    if let uuid = await HealthKitManager.shared.saveDietaryEnergy(calories: item.calories, date: now) {
                        item.healthKitSampleID = uuid.uuidString
                    }
                }
                try? container.mainContext.save()
            }
        }
        
        withAnimation {
            showSuccessToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            onDismiss()
        }
    }
    
    private func generateGroceryList() {
        HapticManager.shared.impact(style: .medium)
        
        var allIngredients: [String] = []
        for day in (plan.days ?? []) {
            for meal in (day.meals ?? []) {
                allIngredients.append(contentsOf: SmartPlanIngredientParser.split(meal.ingredients))
            }
        }
        
        ShoppingItem.insertDeduplicated(
            items: allIngredients.map { (name: $0, amount: "") },
            recipeTitle: "AI Weekly Plan",
            in: context
        )
        
        try? context.save()
        WidgetReloader.reloadAll()
        
        withAnimation {
            showGrocerySuccess = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showGrocerySuccess = false }
        }
    }
}

enum SmartPlanIngredientParser {
    static func split(_ raw: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",;\n•")
        let bulletTrim = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "-*•"))
        return raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: bulletTrim) }
            .filter { !$0.isEmpty }
    }
}

struct MealPlanItemCard: View {
    @Environment(ThemeManager.self) private var themeManager
    let meal: MealPlanItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(LocalizedStringKey(meal.type))
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
                .lineLimit(3)

            if !meal.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(meal.instructions)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            HStack(spacing: 10) {
                Label("\(meal.prepTimeMinutes) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
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
            .padding(.top, 4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
    }
}
