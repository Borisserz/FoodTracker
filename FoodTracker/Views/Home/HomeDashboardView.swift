//============================================================
// FILE: FoodTracker/Views/Home/HomeDashboardView.swift
//============================================================

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
    @State private var showingProfileSheet = false
    
    @State private var selectedDate: Date = .now
    @State private var navigateToProfile = false
    // Стейты для умного добавления еды (Шторка)
    @State private var showingQuickAddSheet = false
    @State private var quickAddMealType: String = "Breakfast"
    
    // Стейт для детального просмотра приема пищи (Менюшка)
    @State private var selectedMealForDetail: String? = nil
    
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
    
    private func getRecommendedCalories(for mealType: String) -> Int {
            let goal = Double(currentUser?.dailyCaloriesGoal ?? 2000)
            switch mealType {
            case "Breakfast": return Int(goal * 0.25) // 25%
            case "Lunch":     return Int(goal * 0.35) // 35%
            case "Dinner":    return Int(goal * 0.30) // 30%
            case "Snack":     return Int(goal * 0.10) // 10%
            default:          return 0
            }
        }
    
    // НОВОЕ: Вычисляемое свойство для подсчета всех калорий
    private var allTimeCalories: Int {
        summaries.reduce(0) { $0 + $1.totalCalories }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        HeaderView(selectedDate: selectedDate) {
                            navigateToProfile = true // Меняем вызов
                          }

                        
                        CalendarCarouselView(selectedDate: $selectedDate)
                        
                      
                        
                        InsightsWidget(summary: currentSummary, user: currentUser)
                                                
                        // НОВАЯ СВАЙПАЮЩАЯСЯ КАРУСЕЛЬ ВМЕСТО СТАТИЧНОЙ КАРТОЧКИ
                        NutritionCarouselView(summary: currentSummary, user: currentUser)
                                                
                        
                        // Список приемов пищи с НОВЫМ ДИЗАЙНОМ И ОБНОВЛЕННЫМИ ДЕЙСТВИЯМИ
                        VStack(spacing: 16) {
                            ForEach(["Breakfast", "Lunch", "Snack", "Dinner"], id: \.self) { mealType in
                                let meal = currentSummary.meals.first(where: { $0.title == mealType })
                                
                                MealCardView(
                                           title: mealType,
                                           calories: meal?.totalCalories,
                                           recommendedCalories: getRecommendedCalories(for: mealType), // ПЕРЕДАЕМ РАСЧЕТ
                                           time: meal?.date,
                                           onCardTap: {
                                               self.selectedMealForDetail = mealType
                                           },
                                           onQuickAdd: {
                                               self.quickAddMealType = mealType
                                               self.showingQuickAddSheet = true
                                           }
                                       )
                                   }
                               }
                        .padding(.horizontal)
                        
                        WaterGridTrackerView(summary: currentSummary)
                            .padding(.horizontal)
                        
                        WeightTrackerCardView(summary: currentSummary)
                                                   .padding(.horizontal)
                        
                        // НОВЫЙ БЛОК С ОБЩЕЙ СТАТИСТИКОЙ
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
            // Вызов премиальной шторки для добавления еды
            .sheet(isPresented: $showingQuickAddSheet) {
                SmartAddFoodView(mealTitle: quickAddMealType) { selectedItems in
                    addFoodsToMeal(title: quickAddMealType, items: selectedItems)
                }
                .presentationDetents([.fraction(0.85), .large])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.hidden) // Скрываем стандартный, у нас свой красивый
            } 
            // Шторка детального просмотра приема пищи (Менюшка)
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
                try? context.save()
            }
        } catch {
            print("Failed to fetch health data: \(error.localizedDescription)")
        }
    }
    
    private func addFoodsToMeal(title: String, items: [FoodItem]) {
        let summary = currentSummary // Уже вычисляется корректно
        
        if let existingMeal = summary.meals.first(where: { $0.title == title }) {
            existingMeal.foodItems.append(contentsOf: items)
            existingMeal.date = .now // ОБНОВЛЕНИЕ ВРЕМЕНИ при добавлении новой еды
        } else {
            let newMeal = Meal(title: title, date: .now, foodItems: items)
            context.insert(newMeal)
            summary.meals.append(newMeal)
        }
        
        try? context.save()
    }
}

struct HeaderView: View {
    let selectedDate: Date
    var onProfileTap: () -> Void // НОВОЕ ДЕЙСТВИЕ
    
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
            
            // КНОПКА ПРОФИЛЯ С ТАКТИЛЬНЫМ ОТКЛИКОМ
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
                    // НАВБАР ДЛЯ ПОЛНОЦЕННОГО ЭКРАНА
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
                    
                    // ЗАГОЛОВОК
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
                        
                        // 1. HERO CARD С ОСНОВНЫМИ ДАННЫМИ
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
                        
                        // 2. СПИСОК ПРОДУКТОВ
                        VStack(alignment: .leading, spacing: 0) {
                            Text("What you ate")
                                .font(.title3.bold())
                                .padding(.horizontal)
                                .padding(.bottom, 12)
                            
                            VStack(spacing: 0) {
                                ForEach(meal.foodItems) { food in
                                    FoodItemDetailedRow(food: food)
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
                        
                        // 3. БЛОК МИКРОНУТРИЕНТОВ
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
                .padding(.bottom, 120) // Отступ под плавающую кнопку
            }
            
            // ПЛАВАЮЩАЯ КНОПКА ДОБАВЛЕНИЯ
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
        .navigationBarHidden(true) // Скрываем стандартный бар, так как у нас свой красивый
        .sheet(isPresented: $showingAddFood) {
            SmartAddFoodView(mealTitle: title) { selectedItems in
                addFoodsToMeal(items: selectedItems)
            }
            .presentationDetents([.fraction(0.85), .large])
            .presentationCornerRadius(32)
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
            existingMeal.date = .now
        } else {
            let newMeal = Meal(title: title, date: .now, foodItems: items)
            context.insert(newMeal)
            summary.meals.append(newMeal)
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
                Text(String(food.name.first ?? "🍲"))
                    .font(.headline)
                    .foregroundColor(.themePink)
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
            
            Text("\(food.calories) kcal")
                .font(.headline)
                .foregroundColor(.themePink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
    }
}
// MARK: - Новый встроенный виджет с кольцами (Full Width Horizontal Layout)
struct MicronutrientRingsView: View {
    let meal: Meal
    
    // Рекомендуемые дневные нормы (делим на 3 приема пищи)
    private let targetOmega3: Double = 1.6 / 3
    private let targetPotassium: Double = 3500 / 3
    private let targetMagnesium: Double = 400 / 3
    
    var body: some View {
        HStack(spacing: 24) {
            // КОЛЬЦА СЛЕВА
            ZStack {
                ActivityRing(progress: meal.totalOmega3 / targetOmega3, color: .themePink, radius: 56, thickness: 12)
                ActivityRing(progress: meal.totalPotassium / targetPotassium, color: .themeYellow, radius: 40, thickness: 12)
                ActivityRing(progress: meal.totalMagnesium / targetMagnesium, color: .themeOrange, radius: 24, thickness: 12)
                
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.linearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom))
            }
            .frame(width: 112, height: 112)
            
            // ПОДРОБНАЯ ЛЕГЕНДА СПРАВА
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

// Вспомогательная структура для легенды с целями
private struct RingLegendRow: View {
    let color: Color
    let title: String
    let value: Double
    let unit: String
    let target: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("\(value, specifier: "%.1f") / \(Int(target)) \(unit)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
}

// Вспомогательный компонент для отрисовки кольца (Остается без изменений)
private struct ActivityRing: View {
    let progress: Double; let color: Color; let radius: CGFloat; let thickness: CGFloat
    
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


// MARK: - 🍱 REDESIGNED Meal Card (Apple Style)
struct MealCardView: View {
    let title: String
    let calories: Int?
    let recommendedCalories: Int // НОВОЕ ПОЛЕ
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
            
            // Иконка
            ZStack {
                Circle()
                    .fill(meta.1.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: meta.0)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(meta.1)
            }
            
            // Текстовый блок
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    if let cals = calories, cals > 0 {
                        Text("\(cals) kcal")
                            .font(.subheadline)
                            .foregroundColor(meta.1)
                            .bold()
                        
                        if let logTime = time {
                            Text("• \(logTime.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("Log Meal")
                            .font(.subheadline)
                            .foregroundColor(.gray.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            
            // БЛОК РЕКОМЕНДАЦИИ (Справа перед кнопкой +)
            VStack(alignment: .trailing, spacing: 2) {
                Text("Target")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray.opacity(0.6))
                
                Text("\(recommendedCalories)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.gray.opacity(0.8))
                
                Text("kcal")
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.trailing, 8)
            
            // Кнопка "+"
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                onQuickAdd()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.12))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.gray.opacity(0.8))
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
    
    // Новые расширенные категории
    let categories = ["Recent", "Frequent", "Favorites", "My Recipes"]
    
    var allAvailableFoods: [FoodItem] {
        var uniqueItems: [String: FoodItem] = [:]
        for meal in pastMeals { for item in meal.foodItems { if uniqueItems[item.name] == nil { uniqueItems[item.name] = item } } }
        var results = Array(uniqueItems.values)
        if results.isEmpty {
            // Mock data if empty
            results = [
                FoodItem(name: "Grilled Chicken Breast", weight: 150, calories: 240, protein: 31, fats: 3.6, carbs: 0),
                FoodItem(name: "Avocado Toast", weight: 120, calories: 220, protein: 5, fats: 12, carbs: 20),
                FoodItem(name: "Scrambled Eggs", weight: 100, calories: 155, protein: 13, fats: 11, carbs: 1),
                FoodItem(name: "Black Coffee", weight: 250, calories: 2, protein: 0, fats: 0, carbs: 0)
            ]
        }
        return results
    }
    
    var filteredFoods: [FoodItem] {
        var items: [FoodItem] = []
        if selectedCategory == "My Recipes" {
            items = customRecipes.map { $0.toFoodItem() }
        } else {
            items = allAvailableFoods
        }
        
        if !searchText.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return items.sorted { $0.name < $1.name }
    }
    
    var cartCalories: Int {
        selectedFoods.reduce(0) { $0 + $1.calories }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - STICKY HEADER
                VStack(spacing: 16) {
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 5)
                        .padding(.top, 10)
                    
                    // Заголовок
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mealTitle)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text("What did you eat?")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color.gray.opacity(0.3))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: ОПТИМИЗИРОВАННЫЙ БЛОК ПОИСКА И КАМЕРЫ
                    ActionSearchBar(text: $searchText, onBarcodeTap: {
                        showingScanner = true
                    })
                    .padding(.horizontal, 20)
                    
                    // MARK: КАТЕГОРИИ (PILL TABS)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedCategory = category
                                    }
                                    HapticManager.shared.impact(style: .light)
                                }) {
                                    Text(category)
                                        .font(.subheadline).bold()
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(selectedCategory == category ? Color.themePink : Color.white)
                                        .foregroundColor(selectedCategory == category ? .white : .primary)
                                        .cornerRadius(20)
                                        .shadow(color: selectedCategory == category ? Color.themePink.opacity(0.3) : Color.black.opacity(0.03), radius: 4, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 10)
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .shadow(color: .black.opacity(0.03), radius: 8, y: 4)
                )
                .zIndex(2)
                
                // MARK: - СПИСОК ПРОДУКТОВ
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        if filteredFoods.isEmpty {
                            EmptyStateView(
                                imageName: "magnifyingglass",
                                title: "No foods found",
                                description: "Try scanning a barcode or using our AI camera."
                            )
                            .padding(.top, 60)
                        } else {
                            // Внутри ScrollView -> LazyVStack:
                            ForEach(filteredFoods, id: \.name) { food in
                                // Обычная строка еды, без инлайн-редактирования
                                FoodSearchResultRow(food: food) {
                                    // По тапу открываем детальный экран
                                    selectedFoodForDetail = food
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, selectedFoods.isEmpty ? 40 : 120) // Отступ под корзину
                }
            }
            
            // MARK: - ПЛАВАЮЩАЯ КОРЗИНА (FAB)
            if !selectedFoods.isEmpty {
                FloatingCartButton(count: selectedFoods.count, calories: cartCalories) {
                    HapticManager.shared.impact(style: .heavy)
                    onSave(selectedFoods)
                    dismiss()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }
        }
        // ДОБАВЛЯЕМ ОТКРЫТИЕ СКАНЕРА:
        .fullScreenCover(isPresented: $showingScanner) {
                    SmartScannerView { foundFood in
                        // Как только сканер нашел продукт, мы кладем его в эту переменную.
                        // А так как на эту переменную у тебя уже завязан другой .fullScreenCover,
                        // карточка продукта откроется АВТОМАТИЧЕСКИ! Магия SwiftUI ✨
                        selectedFoodForDetail = foundFood
                    }
                }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedFoods.isEmpty)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: searchText)
        // В конце body внутри SmartAddFoodView:
        .fullScreenCover(item: $selectedFoodForDetail) { food in
            FoodDetailNutritionView(food: food, mealTitle: mealTitle) { addedFood in
                // Когда пользователь нажал "Add" на экране деталей
                withAnimation(.spring()) {
                    selectedFoods.append(addedFood)
                }
            }
        }
    }
    
    private func toggleFoodSelection(_ food: FoodItem) {
        HapticManager.shared.impact(style: .medium)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if let index = selectedFoods.firstIndex(where: { $0.name == food.name }) {
                selectedFoods.remove(at: index)
            } else {
                selectedFoods.append(food)
            }
        }
    }
}// MARK: - НОВЫЙ БЛОК ПОИСКА С КНОПКАМИ (SearchBar + AI/Barcode)
struct ActionSearchBar: View {
    @Binding var text: String
    var onBarcodeTap: () -> Void // <--- ДОБАВИЛИ ЭТО
    
    var body: some View {
        HStack(spacing: 12) {
            // Текстовое поле
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                TextField("Search foods...", text: $text)
                    .font(.body)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray.opacity(0.5))
                    }
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
            
            // Кнопка AI Камеры
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                // TODO: Camera logic
            }) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 20))
                    .foregroundColor(.themePink)
                    .frame(width: 46, height: 46)
                    .background(Color.themePink.opacity(0.1))
                    .cornerRadius(14)
            }
            
            // Кнопка Штрихкода
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                onBarcodeTap() // <--- ВЫЗЫВАЕМ ОТКРЫТИЕ СКАНЕРА ЗДЕСЬ
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

// MARK: - РЕДИЗАЙН СТРОКИ ПРОДУКТА
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
            Button(action: {
                action()
            }) {
                HStack(spacing: 16) {
                    // Красивая иконка или эмодзи (если есть в базе)
                    Text("🥘") // Можно заменить на логику иконок
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(isSelected ? Color.white : Color.gray.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        // Динамический расчет калорий в зависимости от выбранного веса
                        let currentCals = Int((Double(food.calories) / food.weight) * weight)
                        
                        Text("\(currentCals) kcal • \(Int(weight))g")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(isSelected ? .themePink : .gray)
                    }
                    
                    Spacer()
                    
                    // Кнопка добавления с крутым эффектом
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.themePink : Color.gray.opacity(0.1))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: isSelected ? "checkmark" : "plus")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(isSelected ? .white : .themePink)
                    }
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())

            // MARK: ИНЛАЙН РЕДАКТОР ВЕСА (Раскрывается только при выборе)
            if isSelected {
                HStack(spacing: 20) {
                    // Слайдер или Степпер для веса
                    HStack {
                        Button(action: { weight = max(10, weight - 10); HapticManager.shared.impact(style: .light) }) {
                            Image(systemName: "minus.circle.fill").foregroundColor(.gray.opacity(0.3))
                        }
                        
                        Text("\(Int(weight)) g")
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .frame(width: 70)
                        
                        Button(action: { weight += 10; HapticManager.shared.impact(style: .light) }) {
                            Image(systemName: "plus.circle.fill").foregroundColor(.gray.opacity(0.3))
                        }
                    }
                    
                    Spacer()
                    
                    // Быстрые пресеты веса
                    HStack(spacing: 8) {
                        ForEach([100, 200, 300], id: \.self) { val in
                            Button(action: {
                                withAnimation(.spring()) { weight = Double(val) }
                                HapticManager.shared.impact(style: .medium)
                            }) {
                                Text("\(val)")
                                    .font(.system(size: 12, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(weight == Double(val) ? Color.themePink.opacity(0.2) : Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.white)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isSelected ? Color.themePink.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .shadow(color: isSelected ? Color.themePink.opacity(0.1) : Color.black.opacity(0.03), radius: 10, y: 5)
        .padding(.horizontal, 4) // Чтобы тень не обрезалась
    }
}

// Вспомогательный UI элемент для макросов
struct MacroText: View {
    let title: String
    let value: Double
    let color: Color
    
    var body: some View {
        HStack(spacing: 2) {
            Text(title).font(.system(size: 10, weight: .bold)).foregroundColor(color)
            Text("\(Int(value))g").font(.system(size: 11, weight: .medium)).foregroundColor(.gray)
        }
    }
}

// MARK: - ПЛАВАЮЩАЯ КНОПКА (Корзина)
struct FloatingCartButton: View {
    let count: Int
    let calories: Int
    let action: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            Button(action: action) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(count) items selected")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("Add • \(calories) kcal")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(24)
                .shadow(color: Color.themePink.opacity(0.4), radius: 15, y: 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
}


struct MacroDot: View {
    let color: Color
    let val: Double
    var body: some View {
        VStack(spacing: 2) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(Int(val))").font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
        }
    }
}
struct FoodSearchResultRow: View {
    let food: FoodItem
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text("🍲")
                    .font(.system(size: 24))
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("\(food.calories) kcal • 100g")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.02), radius: 8, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - НОВЫЙ КОМПОНЕНТ СТАТИСТИКИ
struct AllTimeStatsCardView: View {
    let totalCalories: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "flame.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("All-Time Total")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Since your first entry")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer(minLength: 20)
            
            HStack(alignment: .firstTextBaseline) {
                Text(totalCalories, format: .number)
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
                Text("kcal")
                    .font(.title2.bold())
                    .foregroundColor(.white.opacity(0.9))
            }
            .foregroundColor(.white)
            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.themePink.opacity(0.9), Color.themeOrange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(28)
        .shadow(color: .themePink.opacity(0.3), radius: 15, x: 0, y: 8)
        .padding(.horizontal)
    }
}
