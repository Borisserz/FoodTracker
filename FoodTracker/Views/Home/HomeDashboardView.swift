import SwiftUI
import SwiftData

// MARK: - 🎨 Глобальные стили и UX-модификаторы
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
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
            .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 6)
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
    @State private var navigateToProfile = false
    
    @State private var showingQuickAddSheet = false
    @State private var quickAddMealType: String = "Breakfast"
    @State private var selectedMealForDetail: String? = nil
    
    private var currentUser: User? { users.first }
    
    private var currentSummary: DailySummary {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        if let existing = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            return existing
        } else {
            return DailySummary(date: startOfDay)
        }
    }
    
    private func getRecommendedCalories(for mealType: String) -> Int {
        let goal = Double(currentUser?.dailyCaloriesGoal ?? 2000)
        switch mealType {
        case "Breakfast": return Int(goal * 0.25)
        case "Lunch":     return Int(goal * 0.35)
        case "Dinner":    return Int(goal * 0.30)
        case "Snack":     return Int(goal * 0.10)
        default:          return 0
        }
    }
    
    private var allTimeCalories: Int {
        summaries.reduce(0) { $0 + $1.totalCalories }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        HeaderView(selectedDate: selectedDate) { navigateToProfile = true }
                        CalendarCarouselView(selectedDate: $selectedDate)
                        InsightsWidget(summary: currentSummary, user: currentUser)
                        NutritionCarouselView(summary: currentSummary, user: currentUser)
                        
                        VStack(spacing: 16) {
                            ForEach(["Breakfast", "Lunch", "Snack", "Dinner"], id: \.self) { mealType in
                                let meal = currentSummary.meals.first(where: { $0.title == mealType })
                                
                                MealCardView(
                                    title: mealType,
                                    calories: meal?.totalCalories,
                                    recommendedCalories: getRecommendedCalories(for: mealType),
                                    time: meal?.date,
                                    onCardTap: { self.selectedMealForDetail = mealType },
                                    onQuickAdd: { self.quickAddMealType = mealType; self.showingQuickAddSheet = true }
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        WaterGridTrackerView(summary: currentSummary).padding(.horizontal)
                        WeightTrackerCardView(summary: currentSummary).padding(.horizontal)
                        AllTimeStatsCardView(totalCalories: allTimeCalories)
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationBarHidden(true)
            .task(id: selectedDate) {
                await fetchHealthData(for: currentSummary)
            }
            .navigationDestination(isPresented: $navigateToProfile) {
                ProfileWrapperView()
            }
            .sheet(isPresented: $showingQuickAddSheet) {
                SmartAddFoodView(mealTitle: quickAddMealType) { selectedItems in
                    addFoodsToMeal(title: quickAddMealType, items: selectedItems)
                }
                .presentationDetents([.fraction(0.85), .large])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.hidden)
            }
            .navigationDestination(item: Binding(
                get: { selectedMealForDetail.map { IdentifiableString(value: $0) } },
                set: { selectedMealForDetail = $0?.value }
            )) { mealItem in
                MealDetailView(title: mealItem.value, date: selectedDate)
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
                if summary.modelContext == nil { context.insert(summary) }
                try? context.save()
            }
        } catch {
            print("Failed to fetch health data: \(error.localizedDescription)")
        }
    }
    
    private func addFoodsToMeal(title: String, items: [FoodItem]) {
        let summary = currentSummary
        var newFoodItems: [FoodItem] = []
        
        for item in items {
            let copiedItem = FoodItem(
                name: item.name, weight: item.weight, calories: item.calories,
                protein: item.protein, fats: item.fats, carbs: item.carbs,
                omega3: item.omega3, calcium: item.calcium, potassium: item.potassium,
                magnesium: item.magnesium, iron: item.iron, vitaminC: item.vitaminC, vitaminD: item.vitaminD
            )
            context.insert(copiedItem)
            newFoodItems.append(copiedItem)
        }
        
        if let existingMeal = summary.meals.first(where: { $0.title == title }) {
            existingMeal.foodItems.append(contentsOf: newFoodItems)
            existingMeal.date = .now
        } else {
            let newMeal = Meal(title: title, date: .now, foodItems: newFoodItems)
            context.insert(newMeal)
            summary.meals.append(newMeal)
        }
        
        if summary.modelContext == nil {
            context.insert(summary)
        }
        
        try? context.save()
    }
}

// MARK: - Header
struct HeaderView: View {
    let selectedDate: Date
    var onProfileTap: () -> Void
    
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
            
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                onProfileTap()
            }) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: Color.themePink.opacity(0.3), radius: 5, y: 2)
            }
            .buttonStyle(BounceButtonStyle())
        }
        .padding(.horizontal)
        .padding(.top, 10)
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

// MARK: - 🍱 Детализация приема пищи (Full Page)
struct MealDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var summaries: [DailySummary]
    @Query private var users: [User]
    
    let title: String
    let date: Date
    
    @State private var selectedFoodForDetail: FoodItem? = nil
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
                VStack(spacing: 24) {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                        if let mealDate = meal?.date {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                Text("Logged at \(mealDate.formatted(date: .omitted, time: .shortened))")
                            }
                            .font(.subheadline)
                            .foregroundColor(.themeOrange)
                        } else {
                            Text("No foods logged yet")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    
                    if let meal = meal, !meal.foodItems.isEmpty {
                        VStack(spacing: 16) {
                            Text("\(meal.totalCalories) kcal")
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .foregroundColor(.themePink)
                            
                            HStack(spacing: 20) {
                                let user = users.first
                                let targetP = (user?.targetProtein ?? 150.0) / 3
                                let targetF = (user?.targetFats ?? 70.0) / 3
                                let targetC = (user?.targetCarbs ?? 250.0) / 3
                                
                                MiniProgressView(title: "Protein", progress: meal.totalProtein / max(targetP, 1), color: .themePeach)
                                MiniProgressView(title: "Fats", progress: meal.totalFats / max(targetF, 1), color: .themeYellow)
                                MiniProgressView(title: "Carbs", progress: meal.totalCarbs / max(targetC, 1), color: .drinkWater)
                            }
                        }
                        .ultraPremiumCardStyle()
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("What you ate")
                                .font(.title3.bold())
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                            
                            VStack(spacing: 0) {
                                ForEach(meal.foodItems) { food in
                                    Button(action: {
                                        HapticManager.shared.impact(style: .light)
                                        selectedFoodForDetail = food
                                    }) {
                                        FoodItemDetailedRow(food: food)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    if food.id != meal.foodItems.last?.id {
                                        Divider().padding(.leading, 20)
                                    }
                                }
                            }
                            .background(Color.white)
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                        }
                        .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Key Micronutrients")
                                .font(.title3.bold())
                                .padding(.horizontal)
                            
                            MicronutrientRingsView(meal: meal)
                                .padding(.horizontal)
                        }
                    } else {
                        EmptyStateView(
                            imageName: "fork.knife.circle",
                            title: "No Food Logged",
                            description: "Tap 'Add Food' below to log your \(title)."
                        )
                        .frame(height: 300)
                        .ultraPremiumCardStyle()
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 120)
            }
            
            Button(action: { showingAddFood.toggle() }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Food")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.themePink)
                .cornerRadius(20)
                .shadow(color: Color.themePink.opacity(0.3), radius: 8, y: 4)
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .buttonStyle(BounceButtonStyle())
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingAddFood) {
            SmartAddFoodView(mealTitle: title) { selectedItems in
                addFoodsToMeal(items: selectedItems)
            }
            .presentationDetents([.fraction(0.85), .large])
            .presentationCornerRadius(32)
        }
        .fullScreenCover(item: $selectedFoodForDetail) { food in
            FoodDetailNutritionView(food: food, mealTitle: title) { addedFood in
                addFoodsToMeal(items: [addedFood])
            }
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
        
        var newFoodItems: [FoodItem] = []
        for item in items {
            let copiedItem = FoodItem(
                name: item.name, weight: item.weight, calories: item.calories,
                protein: item.protein, fats: item.fats, carbs: item.carbs,
                omega3: item.omega3, calcium: item.calcium, potassium: item.potassium,
                magnesium: item.magnesium, iron: item.iron, vitaminC: item.vitaminC, vitaminD: item.vitaminD
            )
            context.insert(copiedItem)
            newFoodItems.append(copiedItem)
        }
        
        if let existingMeal = summary.meals.first(where: { $0.title == title }) {
            existingMeal.foodItems.append(contentsOf: newFoodItems)
            existingMeal.date = .now
        } else {
            let newMeal = Meal(title: title, date: .now, foodItems: newFoodItems)
            context.insert(newMeal)
            summary.meals.append(newMeal)
        }
        
        if summary.modelContext == nil {
            context.insert(summary)
        }
        
        try? context.save()
    }
}

// MARK: - Детальная строка для списка продуктов
struct FoodItemDetailedRow: View {
    let food: FoodItem
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.themePink.opacity(0.05)).frame(width: 44, height: 44)
                Text(String(food.name.first ?? "🍲")).font(.headline).foregroundColor(.themePink)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name).font(.subheadline).bold()
                HStack(spacing: 8) {
                    Text("\(Int(food.weight))g")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    Text("P:\(Int(food.protein)) F:\(Int(food.fats)) C:\(Int(food.carbs))")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Text("\(food.calories) kcal").font(.headline).foregroundColor(.themePink)
            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundColor(.gray.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .contentShape(Rectangle())
    }
}

struct MicronutrientRingsView: View {
    let meal: Meal
    private let targetOmega3: Double = 1.6 / 3
    private let targetPotassium: Double = 3500 / 3
    private let targetMagnesium: Double = 400 / 3
    
    var body: some View {
        HStack(spacing: 24) {
            ZStack {
                ActivityRing(progress: meal.totalOmega3 / targetOmega3, color: .themePink, radius: 56, thickness: 12)
                ActivityRing(progress: meal.totalPotassium / targetPotassium, color: .themeYellow, radius: 40, thickness: 12)
                ActivityRing(progress: meal.totalMagnesium / targetMagnesium, color: .themeOrange, radius: 24, thickness: 12)
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.linearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom))
            }
            .frame(width: 112, height: 112)
            
            VStack(alignment: .leading, spacing: 16) {
                RingLegendRow(color: .themePink, title: "Omega-3", value: meal.totalOmega3, unit: "g", target: targetOmega3)
                RingLegendRow(color: .themeYellow, title: "Potassium", value: meal.totalPotassium, unit: "mg", target: targetPotassium)
                RingLegendRow(color: .themeOrange, title: "Magnesium", value: meal.totalMagnesium, unit: "mg", target: targetMagnesium)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 15, x: 0, y: 6)
    }
}

private struct RingLegendRow: View {
    let color: Color
    let title: String
    let value: Double
    let unit: String
    let target: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(color).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary)
                Text("\(value, specifier: "%.1f") / \(Int(target)) \(unit)").font(.system(size: 13, weight: .medium)).foregroundColor(.gray)
            }
        }
    }
}

private struct ActivityRing: View {
    let progress: Double
    let color: Color
    let radius: CGFloat
    let thickness: CGFloat
    
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: thickness)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: radius * 2, height: radius * 2)
        .animation(.spring(response: 0.8), value: progress)
    }
}

private struct RingLegend: View {
    let color: Color; let title: String; let value: Double; let unit: String
    var body: some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.caption).foregroundColor(.gray)
            Text("\(value, specifier: "%.1f")\(unit)").font(.subheadline.bold())
        }
    }
}

// MARK: - 🍱 Meal Card
struct MealCardView: View {
    let title: String
    let calories: Int?
    let recommendedCalories: Int
    let time: Date?
    var onCardTap: () -> Void
    var onQuickAdd: () -> Void
    
    var iconAndColor: (String, Color) {
        switch title {
        case "Breakfast": return ("sunrise.fill", .themeYellow)
        case "Lunch":     return ("sun.max.fill", .green)
        case "Dinner":    return ("moon.fill", .themePink)
        case "Snack":     return ("leaf.fill", .themeOrange)
        default:          return ("fork.knife", .gray)
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            let meta = iconAndColor
            ZStack {
                Circle().fill(meta.1.opacity(0.15)).frame(width: 50, height: 50)
                Image(systemName: meta.0).font(.system(size: 22, weight: .semibold)).foregroundColor(meta.1)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.primary)
                HStack(spacing: 6) {
                    if let cals = calories, cals > 0 {
                        Text("\(cals) kcal").font(.subheadline).foregroundColor(meta.1).bold()
                        if let logTime = time {
                            Text("• \(logTime.formatted(date: .omitted, time: .shortened))").font(.caption2).foregroundColor(.gray)
                        }
                    } else {
                        Text("Log Meal").font(.subheadline).foregroundColor(.gray.opacity(0.7))
                    }
                }
            }
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Target").font(.system(size: 10, weight: .bold)).foregroundColor(.gray.opacity(0.6))
                Text("\(recommendedCalories)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundColor(.gray.opacity(0.8))
                Text("kcal").font(.system(size: 8)).foregroundColor(.gray.opacity(0.5))
            }
            .padding(.trailing, 8)
            
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                onQuickAdd()
            }) {
                ZStack {
                    Circle().fill(Color.gray.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold)).foregroundColor(Color.gray.opacity(0.8))
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.impact(style: .light)
            onCardTap()
        }
    }
}

// MARK: - 🔥 Smart Add Food View (С РЕАЛИЗОВАННЫМ ПОИСКОМ СЕТИ И DEBOUNCE)
struct SmartAddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query private var customRecipes: [CustomRecipe]
    @Query(sort: \Meal.date, order: .reverse) private var pastMeals: [Meal]
    
    @State private var selectedFoodForDetail: FoodItem? = nil
    let mealTitle: String
    var onSave: ([FoodItem]) -> Void
    
    @State private var showingScanner = false
    @State private var selectedFoods: [FoodItem] = []
    @State private var searchText = ""
    @State private var selectedCategory = "Recent"
    
    // --- СТЕЙТЫ ДЛЯ СЕТЕВОГО ПОИСКА ---
    @State private var apiSearchResults: [FoodItem] = []
    @State private var isSearchingAPI = false
    @State private var searchTask: Task<Void, Never>? = nil
    
    let categories = ["Recent", "Frequent", "Favorites", "My Recipes"]
    
    var allAvailableFoods: [FoodItem] {
        var uniqueItems: [String: FoodItem] = [:]
        for meal in pastMeals {
            for item in meal.foodItems {
                if uniqueItems[item.name] == nil { uniqueItems[item.name] = item }
            }
        }
        var results = Array(uniqueItems.values)
        if results.isEmpty {
            results = [
                FoodItem(name: "Grilled Chicken Breast", weight: 150, calories: 240, protein: 31, fats: 3.6, carbs: 0),
                FoodItem(name: "Avocado Toast", weight: 120, calories: 220, protein: 5, fats: 12, carbs: 20),
                FoodItem(name: "Scrambled Eggs", weight: 100, calories: 155, protein: 13, fats: 11, carbs: 1),
                FoodItem(name: "Black Coffee", weight: 250, calories: 2, protein: 0, fats: 0, carbs: 0)
            ]
        }
        return results
    }
    
    var filteredLocalFoods: [FoodItem] {
        var items: [FoodItem] = []
        var foodCounts: [String: Int] = [:]
        
        for meal in pastMeals {
            for food in meal.foodItems { foodCounts[food.name, default: 0] += 1 }
        }
        
        switch selectedCategory {
        case "Recent": items = allAvailableFoods
        case "Frequent": items = allAvailableFoods.sorted { (foodCounts[$0.name] ?? 0) > (foodCounts[$1.name] ?? 0) }
        case "Favorites": items = allAvailableFoods.filter { (foodCounts[$0.name] ?? 0) >= 2 && $0.name != "Quick Entry" }
        case "My Recipes": items = customRecipes.map { $0.toFoodItem() }
        default: items = allAvailableFoods
        }
        
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        if selectedCategory == "Recent" || selectedCategory == "My Recipes" {
            items.sort { $0.name < $1.name }
        }
        return items
    }
    
    var cartCalories: Int { selectedFoods.reduce(0) { $0 + $1.calories } }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ШАПКА
                VStack(spacing: 16) {
                    Capsule().fill(Color.gray.opacity(0.3)).frame(width: 40, height: 5).padding(.top, 10)
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mealTitle).font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("What did you eat?").font(.subheadline).foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { dismiss() }) { Image(systemName: "xmark.circle.fill").font(.system(size: 28)).foregroundColor(Color.gray.opacity(0.3)) }
                    }.padding(.horizontal, 20)
                    
                    ActionSearchBar(text: $searchText, onBarcodeTap: { showingScanner = true })
                        .padding(.horizontal, 20)
                    
                    if searchText.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(categories, id: \.self) { category in
                                    Button(action: {
                                        withAnimation(.spring()) { selectedCategory = category }
                                        HapticManager.shared.impact(style: .light)
                                    }) {
                                        Text(category).font(.subheadline).bold().padding(.horizontal, 18).padding(.vertical, 10)
                                            .background(selectedCategory == category ? Color.themePink : Color.white)
                                            .foregroundColor(selectedCategory == category ? .white : .primary)
                                            .cornerRadius(20).shadow(color: selectedCategory == category ? Color.themePink.opacity(0.3) : Color.black.opacity(0.03), radius: 4, y: 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 20).padding(.vertical, 4)
                        }
                    }
                }
                .padding(.bottom, 10)
                .background(Rectangle().fill(.ultraThinMaterial).ignoresSafeArea().shadow(color: .black.opacity(0.03), radius: 8, y: 4))
                .zIndex(2)
                
                // СПИСОК РЕЗУЛЬТАТОВ
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        if !searchText.isEmpty {
                            if isSearchingAPI {
                                ProgressView("Searching global database...")
                                    .padding(.top, 40)
                            } else {
                                if !filteredLocalFoods.isEmpty {
                                    Text("From your history").font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading)
                                    ForEach(filteredLocalFoods, id: \.name) { food in
                                        FoodSearchResultRow(food: food) { selectedFoodForDetail = food }
                                    }
                                }
                                
                                if !apiSearchResults.isEmpty {
                                    Text("Global database").font(.caption.bold()).foregroundColor(.gray).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
                                    ForEach(apiSearchResults, id: \.name) { food in
                                        FoodSearchResultRow(food: food) { selectedFoodForDetail = food }
                                    }
                                } else if filteredLocalFoods.isEmpty {
                                    EmptyStateView(imageName: "magnifyingglass", title: "No foods found", description: "Try searching for something else.")
                                        .padding(.top, 40)
                                }
                            }
                        } else {
                            if filteredLocalFoods.isEmpty {
                                EmptyStateView(imageName: "tray", title: "No history", description: "Your recent meals will appear here.")
                                    .padding(.top, 60)
                            } else {
                                ForEach(filteredLocalFoods, id: \.name) { food in
                                    FoodSearchResultRow(food: food) { selectedFoodForDetail = food }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, selectedFoods.isEmpty ? 40 : 120)
                }
            }
            
            if !selectedFoods.isEmpty {
                FloatingCartButton(count: selectedFoods.count, calories: cartCalories) {
                    HapticManager.shared.impact(style: .heavy)
                    onSave(selectedFoods)
                    dismiss()
                }.transition(.move(edge: .bottom).combined(with: .opacity)).zIndex(3)
            }
        }
        // ✅ ВАЖНО: ОТСЛЕЖИВАЕМ ВВОД ТЕКСТА
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
        .fullScreenCover(isPresented: $showingScanner) {
            SmartScannerView { foundFood in selectedFoodForDetail = foundFood }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedFoods.isEmpty)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: searchText)
        .fullScreenCover(item: $selectedFoodForDetail) { food in
            FoodDetailNutritionView(food: food, mealTitle: mealTitle) { addedFood in
                withAnimation(.spring()) { selectedFoods.append(addedFood) }
            }
        }
    }
    
    // MARK: - ЛОГИКА DEBOUNCE ПОИСКА
    private func performSearch(query: String) {
        searchTask?.cancel()
        guard query.count > 2 else {
            apiSearchResults = []
            isSearchingAPI = false
            return
        }
        isSearchingAPI = true
        searchTask = Task {
            do { try await Task.sleep(nanoseconds: 500_000_000) } catch { return }
            let results = await NetworkManager.shared.searchFoodByText(query: query)
            await MainActor.run {
                if !Task.isCancelled {
                    self.apiSearchResults = results
                    self.isSearchingAPI = false
                }
            }
        }
    }
}

// MARK: - Search Bar & Action Buttons
struct ActionSearchBar: View {
    @Binding var text: String
    var onBarcodeTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search foods...", text: $text).font(.body)
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill").foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
            
            Button(action: { HapticManager.shared.impact(style: .medium) }) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20))
                    .foregroundColor(.themePink)
                    .frame(width: 46, height: 46)
                    .background(Color.themePink.opacity(0.1))
                    .cornerRadius(14)
            }
            
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                onBarcodeTap()
            }) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 20))
                    .foregroundColor(.themeOrange)
                    .frame(width: 46, height: 46)
                    .background(Color.themeOrange.opacity(0.1))
                    .cornerRadius(14)
            }
        }
    }
}

struct InteractiveFoodRow: View {
    let food: FoodItem
    let isSelected: Bool
    @State private var weight: Double
    let action: () -> Void
    
    init(food: FoodItem, isSelected: Bool, action: @escaping () -> Void) {
        self.food = food
        self.isSelected = isSelected
        self.action = action
        self._weight = State(initialValue: food.weight)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 16) {
                    Text("🥘")
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(isSelected ? Color.white : Color.gray.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                        let currentCals = Int((Double(food.calories) / food.weight) * weight)
                        Text("\(currentCals) kcal • \(Int(weight))g").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(isSelected ? .themePink : .gray)
                    }
                    Spacer()
                    ZStack {
                        Circle().fill(isSelected ? Color.themePink : Color.gray.opacity(0.1)).frame(width: 32, height: 32)
                        Image(systemName: isSelected ? "checkmark" : "plus").font(.system(size: 14, weight: .black)).foregroundColor(isSelected ? .white : .themePink)
                    }
                }.padding(16)
            }.buttonStyle(PlainButtonStyle())
            
            if isSelected {
                HStack(spacing: 20) {
                    HStack {
                        Button(action: { weight = max(10, weight - 10); HapticManager.shared.impact(style: .light) }) { Image(systemName: "minus.circle.fill").foregroundColor(.gray.opacity(0.3)) }
                        Text("\(Int(weight)) g").font(.system(size: 15, weight: .bold, design: .monospaced)).frame(width: 70)
                        Button(action: { weight += 10; HapticManager.shared.impact(style: .light) }) { Image(systemName: "plus.circle.fill").foregroundColor(.gray.opacity(0.3)) }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach([100, 200, 300], id: \.self) { val in
                            Button(action: { withAnimation(.spring()) { weight = Double(val) }; HapticManager.shared.impact(style: .medium) }) {
                                Text("\(val)").font(.system(size: 12, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4).background(weight == Double(val) ? Color.themePink.opacity(0.2) : Color.gray.opacity(0.1)).cornerRadius(8)
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.bottom, 16).transition(.move(edge: .top).combined(with: .opacity))
            }
        }.background(Color.white).cornerRadius(24).overlay(RoundedRectangle(cornerRadius: 24).stroke(isSelected ? Color.themePink.opacity(0.3) : Color.clear, lineWidth: 2)).shadow(color: isSelected ? Color.themePink.opacity(0.1) : Color.black.opacity(0.03), radius: 10, y: 5).padding(.horizontal, 4)
    }
}

struct MacroText: View {
    let title: String; let value: Double; let color: Color
    var body: some View {
        HStack(spacing: 2) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(color)
            Text("\(Int(value))g").font(.system(size: 11, weight: .medium)).foregroundColor(.gray)
        }
    }
}

struct FloatingCartButton: View {
    let count: Int; let calories: Int; let action: () -> Void
    var body: some View {
        VStack {
            Spacer()
            Button(action: action) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(count) items selected").font(.caption).foregroundColor(.white.opacity(0.8))
                        Text("Add • \(calories) kcal").font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").font(.title).foregroundColor(.white)
                }.padding(.horizontal, 24).padding(.vertical, 16).background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing)).cornerRadius(24).shadow(color: Color.themePink.opacity(0.4), radius: 15, y: 8)
            }.padding(.horizontal, 20).padding(.bottom, 30)
        }
    }
}

struct MacroDot: View {
    let color: Color; let val: Double
    var body: some View { VStack(spacing: 2) { Circle().fill(color).frame(width: 6, height: 6); Text("\(Int(val))").font(.system(size: 10, weight: .bold)).foregroundColor(.gray) } }
}

struct FoodSearchResultRow: View {
    let food: FoodItem
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text("🍲").font(.system(size: 24)).frame(width: 44, height: 44).background(Color.gray.opacity(0.05)).clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(.primary)
                    Text("\(food.calories) kcal • 100g").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundColor(.gray.opacity(0.5))
            }.padding(16).background(Color.white).cornerRadius(20).shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)
        }.buttonStyle(BounceButtonStyle())
    }
}

struct AllTimeStatsCardView: View {
    let totalCalories: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "flame.circle.fill").font(.largeTitle).foregroundStyle(LinearGradient(colors: [.white, .white.opacity(0.7)], startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 2) {
                    Text("All-Time Total").font(.headline).foregroundColor(.white)
                    Text("Since your first entry").font(.caption).foregroundColor(.white.opacity(0.8))
                }
            }
            Spacer(minLength: 20)
            HStack(alignment: .firstTextBaseline) {
                Text(totalCalories, format: .number).font(.system(size: 44, weight: .heavy, design: .rounded)).contentTransition(.numericText())
                Text("kcal").font(.title2.bold()).foregroundColor(.white.opacity(0.9))
            }.foregroundColor(.white)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(LinearGradient(colors: [Color.themePink.opacity(0.9), Color.themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)).cornerRadius(28).shadow(color: .themePink.opacity(0.3), radius: 15, x: 0, y: 8).padding(.horizontal)
    }
}
