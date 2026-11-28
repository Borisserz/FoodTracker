import SwiftUI
import SwiftData

struct WeeklyPlanOverview: View {
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Query private var users: [User]
    
    let plan: WeeklyMealPlan
    let onDismiss: () -> Void
    
    @State private var selectedDayIndex = 0
    @State private var appliedDayIndices: Set<Int> = []
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
        ZStack {
            DynamicAuroraBackgroundView(paletteTrigger: selectedDayIndex, tabTag: 1)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your AI Plan")
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                        Text(LocalizedStringKey(plan.dietType))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 14)
                
                // Days Carousel
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<7, id: \.self) { index in
                            let isSelected = selectedDayIndex == index
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedDayIndex = index }
                                HapticManager.shared.impact(style: .light)
                            }) {
                                VStack(spacing: 5) {
                                    Text(dayNames[index])
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                                    
                                    Text("Day \(index + 1)")
                                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                                        .foregroundColor(isSelected ? .white : .primary)
                                }
                                .padding(.vertical, 11)
                                .padding(.horizontal, 15)
                                .background(
                                    isSelected
                                        ? AnyShapeStyle(themeManager.current.primaryGradient)
                                        : AnyShapeStyle(Color(UIColor.secondarySystemGroupedBackground))
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(isSelected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 14)
                }
                
                // Meals List
                ScrollView(showsIndicators: false) {
                    if let day = selectedDay, !(day.meals ?? []).isEmpty {
                        VStack(spacing: 14) {
                            // Day Summary Strip
                            HStack(spacing: 8) {
                                macroPillView(title: "Cals", value: "\(day.totalCalories)", color: themeManager.current.primaryAccent)
                                macroPillView(title: "Protein", value: "\(day.totalProtein)g", color: Color(red: 0.16, green: 0.72, blue: 0.50))
                                macroPillView(title: "Carbs", value: "\(day.totalCarbs)g", color: .blue)
                                macroPillView(title: "Fat", value: "\(day.totalFat)g", color: .themeOrange)
                            }
                            .padding(.bottom, 4)
                            
                            ForEach((day.meals ?? []).sorted(by: { typePriority($0.type) < typePriority($1.type) })) { meal in
                                MealPlanItemCard(meal: meal)
                            }

                            NutritionMethodologyDisclaimerView(
                                citations: [.dietaryGuidelines],
                                compact: true
                            )
                            HStack {
                                Spacer()
                                ReportAIContentButton(surface: "weekly_plan")
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
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
                VStack(spacing: 10) {
                    if showSuccessToast {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Applied to Today's Log")
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if showGrocerySuccess {
                        HStack(spacing: 6) {
                            Image(systemName: "cart.fill")
                            Text("Added to Grocery List")
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.themeOrange)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    HStack(spacing: 12) {
                        Button(action: generateGroceryList) {
                            HStack(spacing: 6) {
                                Image(systemName: "cart.fill.badge.plus")
                                Text("Groceries")
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .disabled(showGrocerySuccess)
                        
                        let isDayApplied = appliedDayIndices.contains(selectedDayIndex)
                        Button(action: applyToToday) {
                            HStack(spacing: 6) {
                                Image(systemName: isDayApplied ? "checkmark.circle.fill" : "tray.and.arrow.down.fill")
                                Text(isDayApplied ? "Applied to Today" : "Apply to Today")
                            }
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(((selectedDay?.meals ?? []).isEmpty || isDayApplied) ? AnyShapeStyle(Color.gray.opacity(0.4)) : AnyShapeStyle(themeManager.current.primaryGradient))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: ((selectedDay?.meals ?? []).isEmpty || isDayApplied) ? .clear : themeManager.current.primaryAccent.opacity(0.25), radius: 8, y: 4)
                        }
                        .disabled(isDayApplied || (selectedDay?.meals ?? []).isEmpty)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .padding(.top, 8)
            }
        }
    }

    private func macroPillView(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundColor(color)
            Text(LocalizedStringKey(title))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
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
        guard !appliedDayIndices.contains(selectedDayIndex),
              let day = selectedDay,
              let dayMeals = day.meals,
              !dayMeals.isEmpty else { return }
        appliedDayIndices.insert(selectedDayIndex)
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { showSuccessToast = false }
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
    @State private var isExpanded = false
    
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
                .lineLimit(isExpanded ? nil : 3)

            if !meal.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(meal.instructions)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(isExpanded ? nil : 3)
            }

            HStack {
                Spacer()
                Text(isExpanded ? "Show Less" : "Read More")
                    .font(.caption2.bold())
                    .foregroundColor(themeManager.current.primaryAccent)
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
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25)) {
                isExpanded.toggle()
            }
        }
    }
}
