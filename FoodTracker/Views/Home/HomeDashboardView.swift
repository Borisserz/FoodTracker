//============================================================
// FILE: FoodTracker/Views/Home/HomeDashboardView.swift
//============================================================

import SwiftUI
import SwiftData

// MARK: - 🎨 Глобальные стили и UX-модификаторы
// (Помещены здесь для самодостаточности файла, но лучше вынести в отдельный файл)

struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct UltraPremiumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.white)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func ultraPremiumCardStyle() -> some View {
        self.modifier(UltraPremiumCardModifier())
    }
}

// MARK: - 🏠 Главный Экран (HomeDashboardView)
struct HomeDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]
    
    @State private var selectedDate: Date = .now
    
    private var currentUser: User? { users.first }
    
    private var currentSummary: DailySummary {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        if let existing = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            return existing
        } else {
            let newSummary = DailySummary(date: startOfDay)
            context.insert(newSummary)
            return newSummary
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        HeaderView(selectedDate: selectedDate)
                        
                        CalendarCarouselView(selectedDate: $selectedDate)
                        
                        InsightsWidget(summary: currentSummary, user: currentUser)
                        
                        UnifiedProgressCard(summary: currentSummary, user: currentUser)
                        
                        // Список приемов пищи
                        VStack(spacing: 16) {
                            let baseGoal = currentUser?.dailyCaloriesGoal ?? 2400
                            ForEach(["Breakfast", "Lunch", "Snack", "Dinner"], id: \.self) { mealType in
                                let meal = currentSummary.meals.first(where: { $0.title == mealType })
                                let ingredientsStr = meal?.foodItems.prefix(3).map { $0.name }.joined(separator: ", ")
                                
                                let recRatio: Double = {
                                    switch mealType {
                                    case "Breakfast": return 0.25
                                    case "Lunch": return 0.35
                                    case "Dinner": return 0.30
                                    case "Snack": return 0.10
                                    default: return 0.0
                                    }
                                }()
                                let recommended = Int(Double(baseGoal) * recRatio)
                                
                                MealCardView(
                                    title: mealType,
                                    calories: meal?.totalCalories,
                                    recommendedCalories: recommended,
                                    ingredients: ingredientsStr,
                                    destination: MealDetailView(title: mealType, date: currentSummary.date)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        AdvancedBeverageTrackerView(summary: currentSummary)
                            .padding(.horizontal)
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationBarHidden(true)
            .task(id: selectedDate) {
                 await fetchHealthData(for: currentSummary)
            }
        }
    }

    private func fetchHealthData(for summary: DailySummary) async {
        guard currentUser?.isHealthKitEnabled == true else { return }
        HealthKitManager.shared.isAuthorized = true
        do {
            let burned = try await HealthKitManager.shared.fetchActiveEnergy(for: summary.date)
            if summary.activeCaloriesBurned != burned {
                summary.activeCaloriesBurned = burned
                try? context.save()
            }
        } catch {
            print("Failed to fetch health data: \(error.localizedDescription)")
        }
    }
}

// MARK: - Вложенные Подкомпоненты
// Это решает все проблемы с "not found in scope" и "Type '()' cannot conform to View"

struct HeaderView: View {
    let selectedDate: Date
    
    // ИСПРАВЛЕНО: Используем DateFormatter для надежности
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var relativeDateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) { return "Today" }
        if calendar.isDateInYesterday(selectedDate) { return "Yesterday" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: selectedDate)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(monthYearString).font(.title2.bold())
                Text(relativeDateString).foregroundColor(.textGray)
            }
            Spacer()
            NavigationLink(destination: ProfileWrapperView()) {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 32)).foregroundColor(.themePink)
            }
        }
        .padding(.horizontal).padding(.top, 10)
    }
}

struct UnifiedProgressCard: View {
    let summary: DailySummary
    let user: User?
    
    var body: some View {
        let target = (user?.dailyCaloriesGoal ?? 2400) + summary.activeCaloriesBurned
        
        VStack(spacing: 24) {
            BreathingCaloriesDashboard(
                consumed: summary.totalCalories,
                target: target,
                activeBurned: summary.activeCaloriesBurned,
                protein: summary.totalProtein,
                fats: summary.totalFats,
                carbs: summary.totalCarbs
            )
            
            MacroSummaryView(
                protein: summary.totalProtein,
                fats: summary.totalFats,
                carbs: summary.totalCarbs,
                targetProtein: user?.targetProtein ?? 150,
                targetFats: user?.targetFats ?? 70,
                targetCarbs: user?.targetCarbs ?? 250
            )
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal)
    }
}

struct InsightsWidget: View {
    let summary: DailySummary
    let user: User?
    
    // ИСПРАВЛЕНО: Логика вынесена из ViewBuilder в вычислимое свойство.
    private var insightData: (message: String, icon: String, color: Color) {
        let baseGoal = user?.dailyCaloriesGoal ?? 2400
        let remaining = (baseGoal + summary.activeCaloriesBurned) - summary.totalCalories
        
        if summary.totalCalories == 0 {
            return ("Good morning! Ready to crush your goals?", "sun.max.fill", .themeDarkYellow)
        } else if remaining < 0 {
            return ("Slightly over limit, but tomorrow is a new day!", "exclamationmark.circle.fill", .red)
        } else if summary.totalProtein < (user?.targetProtein ?? 150) * 0.3 && summary.totalCalories > 600 {
            return ("Great start! Try adding more protein to your next meal.", "bolt.fill", .themePeach)
        } else if summary.totalHydrationLiters < 1.0 && summary.totalCalories > 1000 {
            return ("Don't forget to drink water to stay hydrated!", "drop.fill", .drinkWater)
        } else {
            return ("You're on track! Keep up the great work.", "star.fill", .themePink)
        }
    }
    
    var body: some View {
        let data = insightData
        
        HStack(spacing: 16) {
            Image(systemName: data.icon)
                .font(.title2)
                .foregroundColor(data.color)
            
            Text(data.message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
        .padding(.horizontal)
    }
}


// MARK: - 🍱 Детализация приема пищи (MealDetailView)
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
        return summaries.first { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }?
                        .meals.first { $0.title == title }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    if let meal = meal, !meal.foodItems.isEmpty {
                        VStack(spacing: 16) {
                            Text("\(meal.totalCalories) kcal").font(.system(size: 36, weight: .bold, design: .rounded))
                            HStack(spacing: 20) {
                                let user = users.first
                                let targetP = user?.targetProtein ?? 150.0
                                let targetF = user?.targetFats ?? 70.0
                                let targetC = user?.targetCarbs ?? 250.0
                                
                                MiniProgressView(title: "Protein", progress: meal.totalProtein / max(targetP, 1), color: Color.themePeach)
                                MiniProgressView(title: "Fats", progress: meal.totalFats / max(targetF, 1), color: Color.themeYellow)
                                MiniProgressView(title: "Carbs", progress: meal.totalCarbs / max(targetC, 1), color: Color.drinkWater)
                            }
                        }
                        .ultraPremiumCardStyle()
                        
                        VStack(spacing: 0) {
                            ForEach(meal.foodItems) { food in
                                FoodItemRow(name: food.name, weight: "\(Int(food.weight))g", calories: food.calories)
                                if food.id != meal.foodItems.last?.id {
                                    Divider().padding(.leading, 20)
                                }
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(20)
                        
                    } else {
                        EmptyStateView(
                            imageName: "fork.knife.circle",
                            title: "No Food Logged",
                            description: "Tap 'Add Food' to log your \(title)."
                        )
                        .frame(height: 300)
                        .ultraPremiumCardStyle()
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
            
            Button(action: { showingAddFood.toggle() }) {
                HStack { Image(systemName: "plus"); Text("Add Food") }
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding().background(Color.themePink).cornerRadius(16).padding()
            }
            .buttonStyle(BounceButtonStyle())
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // ИСПРАВЛЕНО: Безопасное использование `if let` внутри ToolbarItem
                if let meal = meal, !meal.foodItems.isEmpty {
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
        
        if let existingSummary = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
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

// MARK: - ➕ Экран добавления еды (AddFoodSelectionView)
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
        for meal in pastMeals.prefix(20) { for item in meal.foodItems { if uniqueItems[item.name] == nil { uniqueItems[item.name] = item } } }
        var results = Array(uniqueItems.values)
        if results.isEmpty {
            results = [
                FoodItem(name: "Grilled Chicken", weight: 150, calories: 240, protein: 31, fats: 3.6, carbs: 0),
                FoodItem(name: "Avocado", weight: 100, calories: 160, protein: 2, fats: 15, carbs: 9),
                FoodItem(name: "Salmon", weight: 120, calories: 208, protein: 22, fats: 13, carbs: 0)
            ]
        }
        if !searchText.isEmpty { results = results.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
        return results.sorted { $0.name < $1.name }
    }
    
    var filteredRecipes: [CustomRecipe] {
        if searchText.isEmpty { return customRecipes }
        else { return customRecipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    HStack {
                        Text("Add Food").font(.system(size: 28, weight: .bold, design: .rounded))
                        Spacer()
                        Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.gray.opacity(0.6)) }
                    }
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search foods...", text: $searchText)
                    }
                    .padding(12).background(Color.black.opacity(0.05)).cornerRadius(12)
                    Picker("Source", selection: $selectedTab) { Text("Recents").tag("Recents"); Text("My Recipes").tag("My Recipes") }.pickerStyle(.segmented)
                }
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 12)
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        if selectedTab == "Recents" { ForEach(recentFoods, id: \.name) { food in foodRowView(for: food, isRecipe: false) } }
                        else {
                            if filteredRecipes.isEmpty && searchText.isEmpty {
                                Text("No custom recipes yet.\nGo to 'Chefs' tab to create one!").font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center).padding(.top, 40)
                            } else { ForEach(filteredRecipes, id: \.name) { recipe in foodRowView(for: recipe.toFoodItem(), isRecipe: true) } }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, temporarilySelectedFoods.isEmpty ? 20 : 100)
                }
            }
            if !temporarilySelectedFoods.isEmpty {
                Button(action: { HapticManager.shared.impact(style: .heavy); onSave(temporarilySelectedFoods); dismiss() }) {
                    HStack { Text("Add \(temporarilySelectedFoods.count) Items").font(.headline); Image(systemName: "arrow.right.circle.fill") }
                    .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(16).shadow(color: Color.themePink.opacity(0.4), radius: 10, y: 5)
                }
                .padding(.horizontal, 20).padding(.bottom, 10).transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: temporarilySelectedFoods.isEmpty)
    }
    
    @ViewBuilder private func foodRowView(for food: FoodItem, isRecipe: Bool) -> some View {
        let isSelected = temporarilySelectedFoods.contains { $0.name == food.name }
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(isRecipe ? Color.themeYellow.opacity(0.15) : Color.green.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: isRecipe ? "star.fill" : "leaf.fill").foregroundColor(isRecipe ? Color.themeYellow : .green).font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name).font(.system(size: 16, weight: .semibold, design: .rounded))
                HStack(spacing: 6) {
                    Text("\(food.calories) kcal").font(.caption).bold().foregroundColor(Color.themePink)
                    Text("•").foregroundColor(.gray.opacity(0.5))
                    Text("\(Int(food.weight))g").font(.caption).foregroundColor(.gray)
                }
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").font(.title2).foregroundColor(isSelected ? Color.themePink : .gray.opacity(0.2)).symbolEffect(.bounce, value: isSelected)
        }
        .padding(16).background(Color.white).cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? Color.themePink : Color.clear, lineWidth: 2))
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .medium)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                if isSelected { temporarilySelectedFoods.removeAll { $0.name == food.name } }
                else { temporarilySelectedFoods.append(food) }
            }
        }
    }
}
