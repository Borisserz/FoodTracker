import SwiftUI
import SwiftData

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]
    
    @State private var showSettings = false
    
    // Стейты для Morphing Quick-Add
    @State private var showQuickAddSheet = false
    @State private var quickAddSelectedMeal = "Breakfast"
    
    private var currentUser: User? { users.first }
    
    private var todaySummary: DailySummary {
        let today = Calendar.current.startOfDay(for: Date.now)
        if let existing = summaries.first(where: { $0.date == today }) {
            return existing
        } else {
            let newSummary = DailySummary(date: today)
            context.insert(newSummary)
            return newSummary
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        CalendarCarouselView()
                        
                        // БЛОК КАЛОРИЙ
                        let baseGoal = currentUser?.dailyCaloriesGoal ?? 2400
                        let activeCals = todaySummary.activeCaloriesBurned
                        let targetCals = baseGoal + activeCals

                        VStack(spacing: 20) {
                            
                            // Внедрение нового дышащего дашборда
                            BreathingCaloriesDashboard(
                                consumed: todaySummary.totalCalories,
                                target: targetCals,
                                activeBurned: activeCals
                            )
                            
                            Divider()
                                .padding(.horizontal, 10)
                            
                            // Оставляем разделение Food/Drinks, аккуратно вписав их под кольцом
                            HStack {
                                Text("Food: **\(todaySummary.totalFoodCalories)** kcal")
                                Spacer()
                                Text("Drinks: **\(todaySummary.totalDrinkCalories)** kcal")
                            }
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .premiumCardStyle()
                        
              
                        MacroSummaryView(
                            protein: todaySummary.totalProtein,
                            fats: todaySummary.totalFats,
                            carbs: todaySummary.totalCarbs,
                            targetProtein: currentUser?.targetProtein ?? 150.0,
                            targetFats: currentUser?.targetFats ?? 70.0,
                            targetCarbs: currentUser?.targetCarbs ?? 250.0
                        )
                        
                        // БЛОК ПРИЕМОВ ПИЩИ
                        VStack(spacing: 16) {
                            ForEach(["Breakfast", "Lunch", "Snack", "Dinner"], id: \.self) { mealType in
                                let meal = todaySummary.meals.first(where: { $0.title == mealType })
                                MealCardView(
                                    title: mealType,
                                    calories: meal?.totalCalories,
                                    isBalanced: false,
                                    destination: MealDetailView(title: mealType, date: todaySummary.date)
                                )
                            }
                        }
                        
                        // БЛОК НАПИТКОВ
                        AdvancedBeverageTrackerView(summary: todaySummary)
                    }
                    .padding()
                    // Дополнительный отступ снизу, чтобы скролл не перекрывался кнопкой FAB
                    .padding(.bottom, 80)
                }
                
                // Внедрение Morphing Glass Quick-Add FAB
                MorphingQuickAddView { selectedMeal in
                    quickAddSelectedMeal = selectedMeal
                    showQuickAddSheet = true
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
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
                if let user = currentUser {
                    SettingsView(user: user)
                }
            }
            // Шторка для быстрого добавления приема пищи
            .sheet(isPresented: $showQuickAddSheet) {
                NavigationStack {
                    MealDetailView(title: quickAddSelectedMeal, date: todaySummary.date)
                }
            }
            .task(id: currentUser?.isHealthKitEnabled) {
                if currentUser?.isHealthKitEnabled == true {
                    HealthKitManager.shared.isAuthorized = true
                    do {
                        let burned = try await HealthKitManager.shared.fetchActiveEnergy(for: todaySummary.date)
                        if todaySummary.activeCaloriesBurned != burned {
                            todaySummary.activeCaloriesBurned = burned
                            try? context.save()
                        }
                    } catch {
                        print("Failed to fetch active energy: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - 2. SETTINGS
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var user: User
    
    @State private var soundEnabled = true
    @State private var notificationsEnabled = true
    @State private var waterReminderInterval = 60
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Apple Health") {
                    Toggle("Enable HealthKit", isOn: $user.isHealthKitEnabled)
                        .onChange(of: user.isHealthKitEnabled) { oldValue, newValue in
                            if newValue {
                                Task {
                                    do {
                                        try await HealthKitManager.shared.requestAuthorization()
                                        try? context.save()
                                    } catch {
                                        user.isHealthKitEnabled = false
                                        print("HealthKit Error: \(error.localizedDescription)")
                                    }
                                }
                            } else {
                                try? context.save()
                            }
                        }
                }
                
                Section("Notifications") {
                    Toggle("Sound", isOn: $soundEnabled)
                    Toggle("Notifications", isOn: $notificationsEnabled)
                    
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.themePink)
                }
            }
        }
    }
}

// MARK: - 3. MEAL DETAILS
struct MealDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var summaries: [DailySummary]
    @Query private var users: [User]
    
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
                                let user = users.first
                                let targetP = user?.targetProtein ?? 150.0
                                let targetF = user?.targetFats ?? 70.0
                                let targetC = user?.targetCarbs ?? 250.0
                                
                                MiniProgressView(title: "P", progress: meal.totalProtein / max(targetP, 1), color: .themePeach)
                                MiniProgressView(title: "F", progress: meal.totalFats / max(targetF, 1), color: .themeYellow)
                                MiniProgressView(title: "C", progress: meal.totalCarbs / max(targetC, 1), color: .themeOrange)
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
            AddFoodSelectionView { selectedFoodItems in
                addFoodsToMeal(items: selectedFoodItems)
            }
            .presentationDetents([.fraction(0.65), .large])
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(32)
            .presentationDragIndicator(.visible)
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

// MARK: - 4. ADD FOOD SELECTION
struct AddFoodSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query private var customRecipes: [CustomRecipe]
    @Query(sort: \Meal.date, order: .reverse) private var pastMeals: [Meal]
    
    var onSave: ([FoodItem]) -> Void
    
    @State private var temporarilySelectedFoods: [FoodItem] = []
    @State private var selectedTab = "Recents"
    @State private var searchText = ""
    
    var recentFoods: [FoodItem] {
        var uniqueItems: [String: FoodItem] = [:]
        
        for meal in pastMeals.prefix(20) {
            for item in meal.foodItems {
                if uniqueItems[item.name] == nil {
                    uniqueItems[item.name] = item
                }
            }
        }
        
        var results = Array(uniqueItems.values)
        
        if results.isEmpty {
            results = [
                FoodItem(name: "Grilled Chicken", weight: 150, calories: 240, protein: 31, fats: 3.6, carbs: 0),
                FoodItem(name: "Avocado", weight: 100, calories: 160, protein: 2, fats: 15, carbs: 9),
                FoodItem(name: "Salmon", weight: 120, calories: 208, protein: 22, fats: 13, carbs: 0),
                FoodItem(name: "Eggs", weight: 50, calories: 78, protein: 6, fats: 5, carbs: 0.6),
                FoodItem(name: "Almonds", weight: 30, calories: 173, protein: 6, fats: 15, carbs: 6)
            ]
        }
        
        if !searchText.isEmpty {
            results = results.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return results.sorted { $0.name < $1.name }
    }
    
    var filteredRecipes: [CustomRecipe] {
        if searchText.isEmpty {
            return customRecipes
        } else {
            return customRecipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack {
                        Text("Add Food")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search foods...", text: $searchText)
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)
                    
                    Picker("Source", selection: $selectedTab) {
                        Text("Recents").tag("Recents")
                        Text("My Recipes").tag("My Recipes")
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        if selectedTab == "Recents" {
                            ForEach(recentFoods, id: \.name) { food in
                                foodRowView(for: food, isRecipe: false)
                            }
                        } else {
                            if filteredRecipes.isEmpty && searchText.isEmpty {
                                Text("No custom recipes yet.\nGo to 'Chefs' tab to create one!")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 40)
                            } else {
                                ForEach(filteredRecipes, id: \.name) { recipe in
                                    foodRowView(for: recipe.toFoodItem(), isRecipe: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, temporarilySelectedFoods.isEmpty ? 20 : 100)
                }
            }
            
            if !temporarilySelectedFoods.isEmpty {
                Button(action: {
                    HapticManager.shared.impact(style: .heavy)
                    onSave(temporarilySelectedFoods)
                    dismiss()
                }) {
                    HStack {
                        Text("Add \(temporarilySelectedFoods.count) Items")
                            .font(.headline)
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
                    .shadow(color: .themePink.opacity(0.4), radius: 10, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: temporarilySelectedFoods.isEmpty)
    }
    
    @ViewBuilder
    private func foodRowView(for food: FoodItem, isRecipe: Bool) -> some View {
        let isSelected = temporarilySelectedFoods.contains { $0.name == food.name }
        
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isRecipe ? Color.themeYellow.opacity(0.15) : Color.green.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: isRecipe ? "star.fill" : "leaf.fill")
                    .foregroundColor(isRecipe ? .themeYellow : .green)
                    .font(.system(size: 18))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                
                HStack(spacing: 6) {
                    Text("\(food.calories) kcal")
                        .font(.caption).bold()
                        .foregroundColor(.themePink)
                    Text("•")
                        .foregroundColor(.gray.opacity(0.5))
                    Text("\(Int(food.weight))g")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(isSelected ? .themePink : .gray.opacity(0.2))
                .symbolEffect(.bounce, value: isSelected)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.themePink : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .medium)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                if isSelected {
                    temporarilySelectedFoods.removeAll { $0.name == food.name }
                } else {
                    temporarilySelectedFoods.append(food)
                }
            }
        }
    }
}
