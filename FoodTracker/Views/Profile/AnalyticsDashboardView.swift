//
//  AnalyticsDashboardView.swift
//  FoodTracker
//

import SwiftUI
import SwiftData
import Charts

// MARK: - ПЕРИОДЫ АНАЛИТИКИ
enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    var id: String { self.rawValue }
    
    var daysCount: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        }
    }
}

// MARK: - КОРНЕВОЙ VIEW
struct AnalyticsTabView: View {
    @Query private var users: [User]
    @State private var globalPeriod: AnalyticsPeriod = .day
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                if let user = users.first {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 24, pinnedViews: [.sectionHeaders]) {
                            
                            HStack {
                                Text("Analytics")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            
                            // Залипающий переключатель периода (Теперь с чистым фоном)
                            Section(header: GlobalPeriodPicker(selection: $globalPeriod)) {
                                
                                // УМНЫЙ РОУТИНГ ИНТЕРФЕЙСА
                                if globalPeriod == .day {
                                    DailyAnalyticsInsightView(user: user)
                                        .padding(.horizontal, 20)
                                } else {
                                    TrendsAnalyticsInsightView(user: user, period: globalPeriod)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                        // Добавляем отступ в самом низу, чтобы контент не прятался за TabBar
                        .padding(.bottom, 120)
                    }
                } else {
                    EmptyStateView(imageName: "chart.bar.xaxis", title: "No Data", description: "User data not found.")
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - ПЛАВАЮЩИЙ ПЕРЕКЛЮЧАТЕЛЬ (ИСПРАВЛЕННЫЙ ФОН)
struct GlobalPeriodPicker: View {
    @Binding var selection: AnalyticsPeriod
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsPeriod.allCases) { period in
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selection = period
                    }
                }) {
                    Text(period.rawValue)
                        .font(.system(size: 15, weight: selection == period ? .bold : .medium, design: .rounded))
                        .foregroundColor(selection == period ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            ZStack {
                                if selection == period {
                                    Capsule()
                                        .fill(Color.themePink)
                                        .shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4)
                                        .matchedGeometryEffect(id: "TAB", in: animation)
                                }
                            }
                        )
                }
            }
        }
        .padding(4)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        // Чистый фон, который сливается с приложением и перекрывает контент при скролле
        .background(
            Color.themeBg.ignoresSafeArea(edges: .top)
        )
    }
}

// =========================================================================
// MARK: - ВАРИАНТ 1: АНАЛИТИКА ЗА ОДИН ДЕНЬ (КОЛЬЦА И РАСПРЕДЕЛЕНИЕ)
// =========================================================================
struct DailyAnalyticsInsightView: View {
    @Query private var summaries: [DailySummary]
    let user: User
    
    // Берем данные за сегодня
    private var todaySummary: DailySummary? {
        let calendar = Calendar.current
        return summaries.first(where: { calendar.isDateInToday($0.date) })
    }
    
    var body: some View {
        VStack(spacing: 24) {
            DailyEnergyProgressCard(summary: todaySummary, user: user)
            NutrientDistributionCard(summary: todaySummary, user: user)
            MealDistributionCard(summary: todaySummary)
            DailyWaterCard(summary: todaySummary)
        }
        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
    }
}

// MARK: Карточка: Горизонтальный прогресс энергии
struct DailyEnergyProgressCard: View {
    let summary: DailySummary?
    let user: User
    
    var body: some View {
        let eaten = summary?.totalFoodCalories ?? 0
        let target = user.dailyCaloriesGoal
        let left = max(target - eaten, 0)
        let c = summary?.totalCarbs ?? 0; let tc = user.targetCarbs
        let f = summary?.totalFats ?? 0;  let tf = user.targetFats
        let p = summary?.totalProtein ?? 0; let tp = user.targetProtein
        
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "flame.fill").foregroundColor(.themeOrange)
                Text("Calories").font(.headline).foregroundColor(.primary)
            }
            
            // Главный бар калорий
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(eaten) kcal").font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text("\(left) kcal left").font(.subheadline).foregroundColor(.gray)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.15))
                        Capsule()
                            .fill(Color.themeOrange)
                            .frame(width: min(geo.size.width * CGFloat(Double(eaten)/Double(max(target, 1))), geo.size.width))
                    }
                }
                .frame(height: 12)
            }
            
            // Мини-бары макросов
            HStack(spacing: 16) {
                MiniHorizontalMacro(title: "Protein", current: p, target: tp, color: .themePeach)
                MiniHorizontalMacro(title: "Fat", current: f, target: tf, color: .themeYellow)
                MiniHorizontalMacro(title: "Carbs", current: c, target: tc, color: .drinkWater)
            }
        }
        .ultraPremiumCardStyle()
    }
}

struct MiniHorizontalMacro: View {
    let title: String; let current: Double; let target: Double; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).bold().foregroundColor(color)
            Text("\(Int(current)) g").font(.subheadline.bold())
            Text("\(max(Int(target - current), 0)) g left").font(.caption2).foregroundColor(.gray)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: min(geo.size.width * CGFloat(current/max(target, 1)), geo.size.width))
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: Карточка: Кольцевой график макросов (SectorMark)
struct NutrientDistributionCard: View {
    let summary: DailySummary?
    let user: User
    
    var body: some View {
        let p = summary?.totalProtein ?? 0
        let f = summary?.totalFats ?? 0
        let c = summary?.totalCarbs ?? 0
        let total = p + f + c
        let totalCals = summary?.totalFoodCalories ?? 0
        
        VStack(alignment: .leading, spacing: 20) {
            Text("Distribution of nutrients")
                .font(.headline)
            
            if total == 0 {
                EmptyStateView(imageName: "chart.pie", title: "No Data", description: "Log food to see distribution").frame(height: 150)
            } else {
                HStack(spacing: 30) {
                    
                    // УЛУЧШЕННЫЙ ГРАФИК
                    ZStack {
                        // 1. Фоновое кольцо (трек)
                        Circle()
                            .stroke(Color.gray.opacity(0.1), lineWidth: 18)
                        
                        // 2. Сам график с сочными градиентами
                        Chart {
                            SectorMark(angle: .value("Carbs", c), innerRadius: .ratio(0.75), angularInset: 2.5)
                                .foregroundStyle(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .cornerRadius(5)
                            
                            SectorMark(angle: .value("Fat", f), innerRadius: .ratio(0.75), angularInset: 2.5)
                                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .cornerRadius(5)
                            
                            SectorMark(angle: .value("Protein", p), innerRadius: .ratio(0.75), angularInset: 2.5)
                                .foregroundStyle(LinearGradient(colors: [.themePink, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .cornerRadius(5)
                        }
                        
                        // 3. Данные внутри кольца
                        VStack(spacing: 2) {
                            Text("\(totalCals)")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(.primary)
                            Text("kcal")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 140, height: 140)
                    // Легкая тень для эффекта объема
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
                    
                    // УЛУЧШЕННАЯ ЛЕГЕНДА
                    VStack(alignment: .leading, spacing: 16) {
                        DonutLegendRow(title: "Protein", percent: p/total, grams: p, color: .themePink)
                        DonutLegendRow(title: "Fat", percent: f/total, grams: f, color: .orange)
                        DonutLegendRow(title: "Carbs", percent: c/total, grams: c, color: .blue)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .ultraPremiumCardStyle()
    }
}

// УЛУЧШЕННАЯ СТРОКА ЛЕГЕНДЫ
struct DonutLegendRow: View {
    let title: String; let percent: Double; let grams: Double; let color: Color
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Цветная точка-маркер
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
                .shadow(color: color.opacity(0.4), radius: 3, y: 1)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(percent * 100))%")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(color)
                    
                    Text("/ \(Int(grams)) g")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

// MARK: Карточка: Распределение по приемам пищи
struct MealDistributionCard: View {
    let summary: DailySummary?
    let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snack"]
    
    var body: some View {
        let totalCals = summary?.totalFoodCalories ?? 0
        
        VStack(alignment: .leading, spacing: 16) {
            Text("Calories intake by meal").font(.headline)
            
            VStack(spacing: 0) {
                ForEach(mealTypes.indices, id: \.self) { index in
                    let mealName = mealTypes[index]
                    let mealCals = summary?.meals.first(where: { $0.title == mealName })?.totalCalories ?? 0
                    let percent = totalCals > 0 ? Double(mealCals) / Double(totalCals) : 0
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(mealName).font(.subheadline.bold()).foregroundColor(colorForMeal(mealName))
                            HStack {
                                Text("\(Int(percent * 100))%").font(.headline)
                                Text("/ \(mealCals) kcal").font(.subheadline).foregroundColor(.gray)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    
                    if index < mealTypes.count - 1 { Divider() }
                }
            }
        }
        .ultraPremiumCardStyle()
    }
    
    private func colorForMeal(_ title: String) -> Color {
        switch title {
        case "Breakfast": return .themeYellow
        case "Lunch": return .green
        case "Dinner": return .themePink
        case "Snack": return .themeOrange
        default: return .gray
        }
    }
}

// MARK: Карточка: Вода (Daily)
struct DailyWaterCard: View {
    let summary: DailySummary?
    
    var body: some View {
        let liters = summary?.totalHydrationLiters ?? 0
        let goal = 2.5
        
        VStack(alignment: .leading, spacing: 16) {
            Text("Water Balance").font(.headline)
            HStack(alignment: .firstTextBaseline) {
                Text("\(String(format: "%.2f", liters)) L").font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundColor(.cyan)
                Text("/ \(String(format: "%.2f", goal)) L Goal").font(.subheadline).foregroundColor(.gray)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cyan.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: min(geo.size.width * CGFloat(liters/goal), geo.size.width))
                }
            }
            .frame(height: 16)
        }
        .ultraPremiumCardStyle()
    }
}

// =========================================================================
// MARK: - ВАРИАНТ 2: АНАЛИТИКА ТРЕНДОВ (НЕДЕЛЯ / МЕСЯЦ)
// =========================================================================
struct TrendsAnalyticsInsightView: View {
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]
    let user: User
    let period: AnalyticsPeriod
    
    var body: some View {
        VStack(spacing: 24) {
            TrendsCaloriesChart(summaries: summaries, user: user, period: period)
            TrendsMacrosChart(summaries: summaries, period: period)
            TrendsWaterChart(summaries: summaries, period: period)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }
}

// MARK: Тренд: Калории (Сложенные столбцы)
struct TrendsCaloriesChart: View {
    let summaries: [DailySummary]; let user: User; let period: AnalyticsPeriod
    
    private var chartData: [(date: Date, eaten: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<period.daysCount).map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let summary = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
            return (date: date, eaten: Double(summary?.totalFoodCalories ?? 0))
        }.reversed()
    }
    
    private var avg: Int {
        let valid = chartData.filter { $0.eaten > 0 }
        return valid.isEmpty ? 0 : Int(valid.reduce(0) { $0 + $1.eaten } / Double(valid.count))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Calories Trend").font(.headline).foregroundColor(.gray)
                    Text("\(avg) kcal avg").font(.system(size: 24, weight: .bold, design: .rounded))
                }
                Spacer()
                Image(systemName: "flame.fill").foregroundColor(.themeOrange).font(.title2)
            }
            
            Chart {
                RuleMark(y: .value("Goal", user.dailyCaloriesGoal))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(Color.themePink.opacity(0.5))
                
                ForEach(chartData, id: \.date) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Eaten", point.eaten)
                    )
                    .foregroundStyle(Color.themeOrange.gradient)
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.day()).font(.caption2).foregroundStyle(Color.gray)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel().font(.caption2).foregroundStyle(Color.gray)
                }
            }
            .frame(height: 200)
        }
        .ultraPremiumCardStyle()
    }
}

// MARK: Тренд: Макросы (Stacked Bars)
struct TrendsMacrosChart: View {
    let summaries: [DailySummary]; let period: AnalyticsPeriod
    
    struct MacroData: Identifiable { let id = UUID(); let date: Date; let type: String; let value: Double; let color: Color }
    
    private var chartData: [MacroData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var data: [MacroData] = []
        for i in (0..<period.daysCount).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let s = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
            if let s = s, s.totalFoodCalories > 0 {
                data.append(MacroData(date: date, type: "Carbs", value: s.totalCarbs, color: .drinkWater))
                data.append(MacroData(date: date, type: "Fats", value: s.totalFats, color: .themeYellow))
                data.append(MacroData(date: date, type: "Protein", value: s.totalProtein, color: .themePeach))
            }
        }
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macronutrients").font(.headline).foregroundColor(.gray)
            
            Chart {
                ForEach(chartData) { item in
                    BarMark(
                        x: .value("Date", item.date),
                        y: .value("Grams", item.value)
                    )
                    .foregroundStyle(item.color)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.day()).font(.caption2).foregroundStyle(Color.gray)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.2))
                    AxisValueLabel().font(.caption2).foregroundStyle(Color.gray)
                }
            }
            .frame(height: 200)
            
            HStack(spacing: 16) {
                ChartLegendItem(color: .themePeach, text: "Protein")
                ChartLegendItem(color: .themeYellow, text: "Fats")
                ChartLegendItem(color: .drinkWater, text: "Carbs")
            }
        }
        .ultraPremiumCardStyle()
    }
}

// MARK: Тренд: Вода
struct TrendsWaterChart: View {
    let summaries: [DailySummary]; let period: AnalyticsPeriod
    
    private var chartData: [(date: Date, liters: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<period.daysCount).map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let summary = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
            return (date: date, liters: summary?.totalHydrationLiters ?? 0)
        }.reversed()
    }
    
    private var avg: Double {
        let valid = chartData.filter { $0.liters > 0 }
        return valid.isEmpty ? 0 : valid.reduce(0) { $0 + $1.liters } / Double(valid.count)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fluid Intake").font(.headline).foregroundColor(.gray)
                    HStack(spacing: 30) {
                        VStack(alignment: .leading) {
                            Text("Daily average").font(.caption).foregroundColor(.gray)
                            Text("\(String(format: "%.2f", avg)) L").font(.headline)
                        }
                        VStack(alignment: .leading) {
                            Text("Daily goal").font(.caption).foregroundColor(.gray)
                            Text("2.50 L").font(.headline)
                        }
                    }
                }
                Spacer()
                Image(systemName: "drop.fill").foregroundColor(.cyan).font(.title2)
            }
            
            Chart {
                RuleMark(y: .value("Goal", 2.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(Color.cyan.opacity(0.5))
                
                ForEach(chartData, id: \.date) { point in
                    BarMark(
                        x: .value("Date", point.date),
                        y: .value("Liters", point.liters)
                    )
                    .foregroundStyle(Color.cyan.gradient)
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.day()).font(.caption2).foregroundStyle(Color.gray)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 1, 2, 3]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.2))
                    if let val = value.as(Double.self) { AxisValueLabel("\(Int(val)) L").font(.caption2).foregroundStyle(Color.gray) }
                }
            }
            .frame(height: 200)
        }
        .ultraPremiumCardStyle()
    }
}

// MARK: - ВСПОМОГАТЕЛЬНЫЕ UI КОМПОНЕНТЫ
struct ChartLegendItem: View {
    let color: Color
    let text: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundColor(.gray)
        }
    }
}
