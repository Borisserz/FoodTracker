import SwiftUI
import SwiftData

// MARK: - 1. HOME DASHBOARD (Refactored for SwiftData)
struct HomeDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]
    
    @State private var showSettings = false
    
    private var currentUser: User? { users.first }
    
    // Получение или создание сводки за сегодня
    private var todaySummary: DailySummary {
        let today = Calendar.current.startOfDay(for: Date.now)
        if let existing = summaries.first(where: { $0.date == today }) {
            return existing
        } else {
            // Если для сегодня нет сводки, создаем новую
            let newSummary = DailySummary(date: today)
            context.insert(newSummary)
            return newSummary
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    CalendarCarouselView()
                    
                    // БЛОК КАЛОРИЙ
                    VStack(spacing: 8) {
                        Text("\(todaySummary.totalCalories) / \(currentUser?.dailyCaloriesGoal ?? 2400) kcal")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .contentTransition(.numericText())
                        
                        Text("Food: \(todaySummary.totalFoodCalories) kcal | Drinks: \(todaySummary.totalDrinkCalories) kcal")
                            .font(.subheadline).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .premiumCardStyle()
                    
                    // БЛОК МАКРОНУТРИЕНТОВ
                    MacroSummaryView(
                        protein: todaySummary.totalProtein,
                        fats: todaySummary.totalFats,
                        carbs: todaySummary.totalCarbs
                    )
                    
                    // БЛОК ПРИЕМОВ ПИЩИ
                    VStack(spacing: 16) {
                        ForEach(["Breakfast", "Lunch", "Snack", "Dinner"], id: \.self) { mealType in
                            let meal = todaySummary.meals.first(where: { $0.title == mealType })
                            MealCardView(
                                title: mealType,
                                calories: meal?.totalCalories,
                                isBalanced: false, // This is a legacy property, defaults to false
                                destination: MealDetailView(title: mealType, date: todaySummary.date)
                            )
                        }
                    }
                    
                    // БЛОК НАПИТКОВ
                    AdvancedBeverageTrackerView(summary: todaySummary)
                }
                .padding()
            }
            .background(Color.themeBg)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill").foregroundColor(.themePink)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

// MARK: - 2. SETTINGS (With Stepper Fix)
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var soundEnabled = true
    @State private var notificationsEnabled = true
    @State private var waterReminderInterval = 60
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Notifications") {
                    Toggle("Sound", isOn: $soundEnabled)
                    Toggle("Notifications", isOn: $notificationsEnabled)
                    
                    // FIXED STEPPER: Using trailing closure for the label is more robust
                    Stepper(value: $waterReminderInterval, in: 30...240, step: 15) {
                        Text("Water Reminder Every \(waterReminderInterval)m")
                    }
                }
                Section("About") {
                    HStack { Text("Version"); Spacer(); Text("1.0.0").foregroundColor(.gray) }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() }.foregroundColor(.themePink) } }
        }
    }
}

// MARK: - 3. MEAL DETAILS (Refactored for SwiftData)
struct MealDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var summaries: [DailySummary]
    
    let title: String
    let date: Date
    
    @State private var showingAddFood = false
    
    private var meal: Meal? {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return summaries.first { $0.date == startOfDay }?
                        .meals.first { $0.title == title }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    if let meal = meal, !meal.foodItems.isEmpty {
                        VStack {
                            Text("\(meal.totalCalories) kcal").font(.system(size: 32, weight: .bold, design: .rounded))
                            HStack(spacing: 20) {
                                MiniProgressView(title: "P", progress: meal.totalProtein / 150.0, color: .themePeach)
                                MiniProgressView(title: "F", progress: meal.totalFats / 70.0, color: .themeYellow)
                                MiniProgressView(title: "C", progress: meal.totalCarbs / 250.0, color: .themeOrange)
                            }
                        }.premiumCardStyle()
                        
                        VStack(spacing: 0) {
                            ForEach(meal.foodItems) { food in
                                FoodItemRow(name: food.name, weight: "\(Int(food.weight))g", calories: food.calories)
                                Divider().padding(.leading)
                            }
                        }
                        .background(Color.white).cornerRadius(12)
                        
                    } else {
                        EmptyStateView(
                            imageName: "fork.knife.circle",
                            title: "No Food Logged",
                            description: "Tap 'Add Food' to log your \(title)."
                        ).frame(height: 300).premiumCardStyle()
                    }
                }
                .padding()
                .padding(.bottom, 80)
            }
            .background(Color.themeBg)
            
            Button(action: { showingAddFood.toggle() }) {
                HStack { Image(systemName: "plus"); Text("Add Food") }
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding().background(Color.themePink).cornerRadius(12).padding()
            }
        }
        .navigationTitle(title)
        .toolbar {
            if let meal = meal, !meal.foodItems.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: MicronutrientsView(meal: meal)) {
                        Image(systemName: "chart.pie.fill").foregroundColor(.themePink)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddFood) {
            // This view now takes a callback to return the selected food
            AddFoodSelectionView { selectedFoodItems in
                addFoodsToMeal(items: selectedFoodItems)
            }
        }
    }
    
    private func addFoodsToMeal(items: [FoodItem]) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let summary: DailySummary
        
        if let existingSummary = summaries.first(where: { $0.date == startOfDay }) {
            summary = existingSummary
        } else {
            summary = DailySummary(date: startOfDay)
            context.insert(summary)
        }
        
        if let existingMeal = summary.meals.first(where: { $0.title == title }) {
            existingMeal.foodItems.append(contentsOf: items)
        } else {
            let newMeal = Meal(title: title, date: date, foodItems: items)
            context.insert(newMeal)
            summary.meals.append(newMeal)
        }
        
        try? context.save()
    }
}

// MARK: - 4. ADD FOOD SELECTION (Refactored with Callback)
struct AddFoodSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: ([FoodItem]) -> Void
    
    @State private var temporarilySelectedFoods: [FoodItem] = []
    
    // Sample database, can be replaced with a @Query later
    let foodDatabase = [
        FoodItem(name: "Grilled Chicken", weight: 150, calories: 240, protein: 31, fats: 3.6, carbs: 0),
        FoodItem(name: "Avocado", weight: 100, calories: 160, protein: 2, fats: 15, carbs: 9),
        FoodItem(name: "Salmon", weight: 120, calories: 208, protein: 22, fats: 13, carbs: 0),
        FoodItem(name: "Eggs", weight: 50, calories: 78, protein: 6, fats: 5, carbs: 0.6),
        FoodItem(name: "Almonds", weight: 30, calories: 173, protein: 6, fats: 15, carbs: 6)
    ]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(foodDatabase) { food in
                    let isSelected = temporarilySelectedFoods.contains { $0.name == food.name }
                    HStack {
                        VStack(alignment: .leading) {
                            Text(food.name).font(.headline)
                            Text("\(food.calories) kcal / \(Int(food.weight))g").font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundColor(isSelected ? .themePink : .gray.opacity(0.5))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isSelected {
                            temporarilySelectedFoods.removeAll { $0.name == food.name }
                        } else {
                            temporarilySelectedFoods.append(food)
                        }
                    }
                }
            }
            .navigationTitle("Select Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(temporarilySelectedFoods)
                        dismiss()
                    }.disabled(temporarilySelectedFoods.isEmpty)
                }
            }
            .tint(.themePink)
        }
    }
}
