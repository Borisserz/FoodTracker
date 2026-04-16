//
//  AnalyticsDashboardView.swift
//  FoodTracker
//

import SwiftUI
import SwiftData
import Charts

// MARK: - ПЕРИОДЫ АНАЛИТИКИ И ENUMS
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
enum AnalyticsMacro: String, Identifiable {
    case protein = "Protein"
    case fat = "Fat"
    case carbs = "Carbs"
    
    // Требование протокола Identifiable
    var id: String { self.rawValue }
    
    var color: Color {
        switch self {
        case .protein: return .themePeach
        case .fat: return .themeYellow
        case .carbs: return .drinkWater
        }
    }
}

// MARK: - ПРЕМИУМ СТИЛЬ КАРТОЧЕК (Glassmorphism)
struct DivineCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(.ultraThinMaterial)
            .background(Color.white.opacity(0.65))
            .cornerRadius(32)
            .overlay(
                RoundedRectangle(cornerRadius: 32)
                    .stroke(LinearGradient(colors: [.white, .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func divineCardStyle() -> some View {
        self.modifier(DivineCardModifier())
    }
}

// MARK: - КОРНЕВОЙ VIEW
struct AnalyticsTabView: View {
    @Query private var users: [User]
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]
    
    @State private var globalPeriod: AnalyticsPeriod = .day
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 1. АНИМИРОВАННЫЙ ФОН (Mesh Gradient Effect)
                Color.themeBg.ignoresSafeArea()
                
                Circle()
                    .fill(Color.themePink.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -100, y: -200)
                
                Circle()
                    .fill(Color.themeOrange.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: 150, y: 300)
                
                if let user = users.first {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            // ЗАГОЛОВОК
                            HStack {
                                Text("Analytics")
                                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                                Spacer()
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.title2.bold())
                                    .foregroundStyle(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom))
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            
                            // ПЕРЕКЛЮЧАТЕЛЬ ПЕРИОДА
                            GlobalPeriodPicker(selection: $globalPeriod)
                                .padding(.horizontal, 20)
                            
                            // AI АНАЛИТИКА ТРЕНДА
                            AIWeeklyInsightCard(summaries: summaries, user: user, period: globalPeriod)
                                .padding(.horizontal, 20)
                            
                            // РОУТИНГ ИНТЕРФЕЙСА
                            if globalPeriod == .day {
                                DailyAnalyticsInsightView(summaries: summaries, user: user)
                                    .padding(.horizontal, 20)
                            } else {
                                TrendsAnalyticsInsightView(summaries: summaries, user: user, period: globalPeriod)
                                    .padding(.horizontal, 20)
                            }
                            
                            // КАЛЕНДАРЬ ПОСТОЯНСТВА (Глобальный для всех вкладок)
                            ConsistencyHeatmapCard(summaries: summaries, user: user)
                                .padding(.horizontal, 20)
                            
                        }
                        .padding(.bottom, 120) // Отступ под TabBar
                    }
                } else {
                    EmptyStateView(imageName: "chart.bar.xaxis", title: "No Data", description: "User data not found.")
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - ПЕРЕКЛЮЧАТЕЛЬ ПЕРИОДОВ
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
                        .padding(.vertical, 12)
                        .background(
                            ZStack {
                                if selection == period {
                                    Capsule()
                                        .fill(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                                        .shadow(color: Color.themePink.opacity(0.3), radius: 8, y: 4)
                                        .matchedGeometryEffect(id: "TAB", in: animation)
                                }
                            }
                        )
                }
            }
        }
        .padding(6)
        .background(Color.white.opacity(0.8))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
    }
}

// =========================================================================
// MARK: - ИИ АНАЛИТИКА (СОВЕТЫ)
// =========================================================================
struct AIWeeklyInsightCard: View {
    let summaries: [DailySummary]
    let user: User
    let period: AnalyticsPeriod
    
    private var insight: (title: String, text: String, color: Color) {
        if period == .day {
            return ("Daily Focus", "Keep an eye on your hydration today. You're doing great with proteins!", .themePink)
        } else {
            let validSummaries = summaries.prefix(period.daysCount).filter { $0.totalFoodCalories > 0 }
            let avg = validSummaries.isEmpty ? 0 : validSummaries.reduce(0) { $0 + $1.totalFoodCalories } / validSummaries.count
            
            if avg == 0 {
                return ("Start Tracking", "Log your meals to see advanced analytics and AI recommendations.", .gray)
            } else if avg > user.dailyCaloriesGoal {
                return ("Trend Alert", "Your average is \(avg) kcal. Slightly above your goal. Try reducing evening snacks.", .themeOrange)
            } else {
                return ("Perfect Streak", "Your average is \(avg) kcal. You are perfectly hitting your goals! Keep it up.", .green)
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle().fill(insight.color.opacity(0.2)).frame(width: 48, height: 48)
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(insight.color)
                    .symbolEffect(.pulse)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(insight.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(insight.text)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineSpacing(4)
            }
            Spacer()
        }
        .divineCardStyle()
    }
}

// =========================================================================
// MARK: - ДНЕВНАЯ АНАЛИТИКА
// =========================================================================
struct DailyAnalyticsInsightView: View {
    let summaries: [DailySummary]
    let user: User
    
    @State private var selectedMacroForTop: AnalyticsMacro? = nil
    
    private var todaySummary: DailySummary? {
        let calendar = Calendar.current
        return summaries.first(where: { calendar.isDateInToday($0.date) })
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // КОЛЬЦА МАКРОСОВ (ИНТЕРАКТИВНЫЕ)
            FitnessRingsCard(summary: todaySummary, user: user) { macro in
                selectedMacroForTop = macro
            }
            
            // РАСПРЕДЕЛЕНИЕ ПО ПРИЕМАМ ПИЩИ
            MealDistributionCard(summary: todaySummary)
            
            // ВОДА
            DailyWaterCard(summary: todaySummary)
        }
        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
        // ПОПАП С ТОП ПРОДУКТАМИ
        .sheet(item: $selectedMacroForTop) { macro in
            TopSourcesSheetView(macro: macro, summary: todaySummary)
                .presentationDetents([.height(400)])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
        }
    }
}

// 🔥 КАРТОЧКА: 3D КОЛЬЦА МАКРОСОВ С КНОПКАМИ ЛЕГЕНДЫ
struct FitnessRingsCard: View {
    let summary: DailySummary?
    let user: User
    var onMacroTap: (AnalyticsMacro) -> Void
    
    var body: some View {
        let c = summary?.totalCarbs ?? 0; let tc = user.targetCarbs
        let f = summary?.totalFats ?? 0;  let tf = user.targetFats
        let p = summary?.totalProtein ?? 0; let tp = user.targetProtein
        
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Macros").font(.title3.bold())
                    Text("Tap a nutrient to see top sources").font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chart.pie.fill").foregroundColor(.gray.opacity(0.5))
            }
            
            HStack(spacing: 30) {
                // КОЛЬЦА
                ZStack {
                    RingView(progress: p/tp, color: .themePeach, radius: 130, width: 14)
                    RingView(progress: f/tf, color: .themeYellow, radius: 98, width: 14)
                    RingView(progress: c/tc, color: .drinkWater, radius: 66, width: 14)
                }
                .frame(width: 130, height: 130)
                
                // КЛИКАБЕЛЬНАЯ ЛЕГЕНДА
                VStack(alignment: .leading, spacing: 16) {
                    Button(action: { onMacroTap(.protein) }) {
                        LegendRow(title: "Protein", current: p, target: tp, color: .themePeach)
                    }.buttonStyle(PlainButtonStyle())
                    
                    Button(action: { onMacroTap(.fat) }) {
                        LegendRow(title: "Fats", current: f, target: tf, color: .themeYellow)
                    }.buttonStyle(PlainButtonStyle())
                    
                    Button(action: { onMacroTap(.carbs) }) {
                        LegendRow(title: "Carbs", current: c, target: tc, color: .drinkWater)
                    }.buttonStyle(PlainButtonStyle())
                }
            }
        }
        .divineCardStyle()
    }
}

struct RingView: View {
    var progress: Double; var color: Color; var radius: CGFloat; var width: CGFloat
    @State private var show = false
    
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: width)
            Circle()
                .trim(from: 0, to: show ? min(progress, 1.0) : 0)
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 5, x: 0, y: 0)
        }
        .frame(width: radius, height: radius)
        .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) { show = true } }
    }
}

struct LegendRow: View {
    let title: String; let current: Double; let target: Double; let color: Color
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 8, height: 8).shadow(color: color, radius: 2)
                    Text(title).font(.system(size: 14, weight: .bold, design: .rounded))
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(current))").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                    Text("/ \(Int(target))g").font(.caption).foregroundColor(.gray)
                }
                .padding(.leading, 14)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(color.opacity(0.5))
        }
        .contentShape(Rectangle())
    }
}

// 🔥 КАРТОЧКА: РАСПРЕДЕЛЕНИЕ ПО ПРИЕМАМ ПИЩИ (Горизонтальный Stacked Bar)
struct MealDistributionCard: View {
    let summary: DailySummary?
    let meals = [
        ("Breakfast", Color.themeYellow),
        ("Lunch", Color.green),
        ("Dinner", Color.themePink),
        ("Snack", Color.themeOrange)
    ]
    
    @State private var showAnim = false
    
    var body: some View {
        let totalCals = summary?.totalFoodCalories ?? 0
        
        VStack(alignment: .leading, spacing: 20) {
            Text("Meal Distribution").font(.title3.bold())
            
            if totalCals == 0 {
                Text("Log food to see distribution.").font(.subheadline).foregroundColor(.gray)
            } else {
                // Горизонтальный бар
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(meals, id: \.0) { meal in
                            let cals = summary?.meals.first(where: { $0.title == meal.0 })?.totalCalories ?? 0
                            if cals > 0 {
                                let width = geo.size.width * CGFloat(Double(cals) / Double(totalCals))
                                Rectangle()
                                    .fill(meal.1)
                                    .frame(width: showAnim ? width : 0)
                            }
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 16)
                .onAppear { withAnimation(.spring()) { showAnim = true } }
                
                // Легенда
                VStack(spacing: 12) {
                    ForEach(meals, id: \.0) { meal in
                        let cals = summary?.meals.first(where: { $0.title == meal.0 })?.totalCalories ?? 0
                        if cals > 0 {
                            HStack {
                                HStack(spacing: 8) {
                                    Circle().fill(meal.1).frame(width: 8, height: 8)
                                    Text(meal.0).font(.subheadline.bold())
                                }
                                Spacer()
                                Text("\(cals) kcal").font(.subheadline).foregroundColor(.gray)
                                Text("(\(Int((Double(cals)/Double(totalCals))*100))%)").font(.caption.bold()).foregroundColor(meal.1).frame(width: 45, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .divineCardStyle()
    }
}

// 🔥 КАРТОЧКА: ВОДА
struct DailyWaterCard: View {
    let summary: DailySummary?
    @State private var animProgress: Double = 0
    
    var body: some View {
        let liters = summary?.totalHydrationLiters ?? 0
        let goal = 2.5
        let progress = min(liters / goal, 1.0)
        
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Water Balance").font(.title3.bold())
                Spacer()
                Image(systemName: "drop.fill").foregroundColor(.cyan).font(.title3)
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text("\(String(format: "%.2f", liters)) L")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.cyan)
                    .contentTransition(.numericText())
                Text("/ \(String(format: "%.2f", goal)) L Goal")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cyan.opacity(0.15))
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(animProgress))
                        .shadow(color: .cyan.opacity(0.5), radius: 5, y: 0)
                }
            }
            .frame(height: 16)
            .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) { animProgress = progress } }
            .onChange(of: progress) { _, nv in withAnimation { animProgress = nv } }
        }
        .divineCardStyle()
    }
}

// =========================================================================
// MARK: - АНАЛИТИКА ТРЕНДОВ (ГРАФИКИ)
// =========================================================================
struct TrendsAnalyticsInsightView: View {
    let summaries: [DailySummary]
    let user: User
    let period: AnalyticsPeriod
    
    var body: some View {
        VStack(spacing: 24) {
            DivineCaloriesChart(summaries: summaries, user: user, period: period)
            DivineMacrosChart(summaries: summaries, period: period)
            TrendsWaterChart(summaries: summaries, period: period)
        }
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }
}

// 🔥 ГРАФИК КАЛОРИЙ (Градиентные площади + Гладкие кривые)
struct DivineCaloriesChart: View {
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Energy Trend").font(.title3.bold())
                    Text("Daily Caloric Intake").font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "chart.xyaxis.line").font(.title2).foregroundColor(.themePink)
            }
            
            Chart {
                RuleMark(y: .value("Goal", user.dailyCaloriesGoal))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(Color.themeOrange.opacity(0.8))
                    .annotation(position: .top, alignment: .leading) {
                        Text("GOAL").font(.system(size: 10, weight: .black)).foregroundColor(.themeOrange)
                    }
                
                ForEach(chartData, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Eaten", point.eaten)
                    )
                    .interpolationMethod(.catmullRom) // Плавные изгибы
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundStyle(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                    .symbol { Circle().fill(.white).overlay(Circle().stroke(Color.themePink, lineWidth: 2)).frame(width: 8, height: 8) }
                    
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Eaten", point.eaten)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Color.themePink.opacity(0.4), Color.clear], startPoint: .top, endPoint: .bottom))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated)).font(.caption2.bold()).foregroundStyle(Color.gray)
                    }
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 220)
        }
        .divineCardStyle()
    }
}

// 🔥 ГРАФИК МАКРОСОВ (Stacked Bar Chart)
struct DivineMacrosChart: View {
    let summaries: [DailySummary]
    let period: AnalyticsPeriod
    
    struct MacroData: Identifiable { let id = UUID(); let date: Date; let type: String; let value: Double; let color: Color }
    
    private var chartData: [MacroData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var data: [MacroData] = []
        for i in (0..<period.daysCount).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let s = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
            
            // Если данных нет, кладем нули, чтобы график не ломался
            let carbs = s?.totalCarbs ?? 0
            let fats = s?.totalFats ?? 0
            let protein = s?.totalProtein ?? 0
            
            data.append(MacroData(date: date, type: "Carbs", value: carbs, color: .drinkWater))
            data.append(MacroData(date: date, type: "Fats", value: fats, color: .themeYellow))
            data.append(MacroData(date: date, type: "Protein", value: protein, color: .themePeach))
        }
        return data
    }
    
    // Умная шкала Y: если нет данных, предел 200g, иначе подстраивается под максимум
    private var maxGrams: Double {
        let maxData = chartData.map { $0.value }.max() ?? 0
        return max(200.0, maxData * 1.5)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Macros Balance").font(.title3.bold())
            
            Chart {
                ForEach(chartData) { item in
                    BarMark(
                        // 🔥 ГЛАВНЫЙ ФИКС: unit: .day
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Grams", item.value),
                        width: .fixed(16) // Жестко фиксируем толщину
                    )
                    // Правильное "склеивание" (Stacked)
                    .foregroundStyle(by: .value("Type", item.type))
                    .cornerRadius(4)
                }
            }
            // Назначаем наши кастомные цвета градиентов для каждого типа
            .chartForegroundStyleScale([
                "Carbs": Color.drinkWater.gradient,
                "Fats": Color.themeYellow.gradient,
                "Protein": Color.themePeach.gradient
            ])
            .chartYScale(domain: 0...maxGrams) // Убираем улет в 1000g
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) { AxisValueLabel(format: .dateTime.weekday(.narrow)).font(.caption2.bold()).foregroundStyle(Color.gray) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.15))
                    if let val = value.as(Double.self) {
                        AxisValueLabel("\(Int(val))g").font(.caption2).foregroundStyle(Color.gray)
                    }
                }
            }
            .frame(height: 200)
            
            // Легенда (ручная, так как мы скрыли стандартную от графика)
            HStack(spacing: 20) {
                ChartLegendItem(color: .themePeach, text: "Protein")
                ChartLegendItem(color: .themeYellow, text: "Fats")
                ChartLegendItem(color: .drinkWater, text: "Carbs")
            }
        }
        .divineCardStyle()
    }
}
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
    
    private var maxLiters: Double {
        let maxData = chartData.map { $0.liters }.max() ?? 0
        return max(3.0, maxData + 0.5) // Минимум 3 литра для оси Y
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Fluid Intake Trend").font(.title3.bold())
                Spacer()
                Image(systemName: "drop.fill").foregroundColor(.cyan).font(.title2)
            }
            
            Chart {
                RuleMark(y: .value("Goal", 2.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(Color.cyan.opacity(0.8))
                    .annotation(position: .top, alignment: .leading) {
                        Text("GOAL").font(.system(size: 10, weight: .black)).foregroundColor(.cyan)
                    }
                
                ForEach(chartData, id: \.date) { point in
                    BarMark(
                        // 🔥 ГЛАВНЫЙ ФИКС: unit: .day
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Liters", point.liters),
                        width: .fixed(16) // Толстые столбики!
                    )
                    .foregroundStyle(Color.cyan.gradient)
                    .cornerRadius(6)
                }
            }
            .chartYScale(domain: 0...maxLiters) // Защита от "висящих" баров
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) { AxisValueLabel(format: .dateTime.weekday(.narrow)).font(.caption2.bold()).foregroundStyle(Color.gray) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 1, 2, 3]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.15))
                    if let val = value.as(Double.self), val >= 0 {
                        AxisValueLabel("\(Int(val))L").font(.caption2).foregroundStyle(Color.gray)
                    }
                }
            }
            .frame(height: 200)
        }
        .divineCardStyle()
    }
}
// =========================================================================
// MARK: - ТЕПЛОВАЯ КАРТА АКТИВНОСТИ (GITHUB STYLE)
// =========================================================================
struct ConsistencyHeatmapCard: View {
    let summaries: [DailySummary]
    let user: User
    
    private var days: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<14).map { cal.date(byAdding: .day, value: -$0, to: today)! }.reversed()
    }
    
    private func completionLevel(for date: Date) -> Int {
        let cal = Calendar.current
        guard let summary = summaries.first(where: { cal.isDate($0.date, inSameDayAs: date) }) else { return 0 }
        let target = user.dailyCaloriesGoal; let eaten = summary.totalFoodCalories
        if eaten == 0 { return 0 }
        if eaten >= target - 200 && eaten <= target + 200 { return 3 }
        if eaten > target { return 2 }
        return 1
    }
    
    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 3: return .green
        case 2: return .themeOrange
        case 1: return .themeYellow
        default: return .gray.opacity(0.15)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Consistency").font(.title3.bold())
                Spacer()
                Text("Last 14 Days").font(.caption).foregroundColor(.gray)
            }
            
            HStack(spacing: 8) {
                ForEach(days, id: \.self) { date in
                    let level = completionLevel(for: date)
                    let color = colorForLevel(level)
                    
                    VStack(spacing: 4) {
                        Text(Calendar.current.component(.day, from: date).description).font(.system(size: 10, weight: .bold)).foregroundColor(.gray)
                        RoundedRectangle(cornerRadius: 6).fill(color.gradient).frame(width: 18, height: 36).shadow(color: level == 3 ? .green.opacity(0.4) : .clear, radius: 4, y: 2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            HStack(spacing: 12) {
                LegendDot(color: .green, text: "Perfect")
                LegendDot(color: .themeOrange, text: "Over")
                LegendDot(color: .themeYellow, text: "Under")
            }.padding(.top, 8)
        }
        .divineCardStyle()
    }
}

// =========================================================================
// MARK: - ПОПАП ТОП ПРОДУКТОВ (GLASSMORPHISM)
// =========================================================================
struct TopSourcesSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let macro: AnalyticsMacro
    let summary: DailySummary?
    
    private var topFoods: [FoodItem] {
        guard let summary = summary else { return [] }
        let allFoods = summary.meals.flatMap { $0.foodItems }
        switch macro {
        case .protein: return Array(allFoods.filter { $0.protein > 0 }.sorted { $0.protein > $1.protein }.prefix(3))
        case .fat: return Array(allFoods.filter { $0.fats > 0 }.sorted { $0.fats > $1.fats }.prefix(3))
        case .carbs: return Array(allFoods.filter { $0.carbs > 0 }.sorted { $0.carbs > $1.carbs }.prefix(3))
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Top \(macro.rawValue) Sources")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .padding(.top, 24)
            
            if topFoods.isEmpty {
                Spacer()
                Text("No foods logged yet.").font(.subheadline).foregroundColor(.gray)
                Spacer()
            } else {
                VStack(spacing: 16) {
                    ForEach(topFoods.indices, id: \.self) { index in
                        let food = topFoods[index]
                        let value = getValue(for: food)
                        
                        HStack(spacing: 16) {
                            Text("\(index + 1)")
                                .font(.headline.bold()).foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(macro.color.opacity(index == 0 ? 1.0 : (index == 1 ? 0.7 : 0.4)))
                                .clipShape(Circle())
                            
                            Text(food.name).font(.system(size: 16, weight: .bold, design: .rounded)).lineLimit(1)
                            Spacer()
                            Text("\(value, specifier: "%.1f") g").font(.headline).foregroundColor(macro.color)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
                    }
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
            }
            
            Button(action: { dismiss() }) {
                Text("Close")
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding(.vertical, 16).background(macro.color).cornerRadius(20)
            }
            .buttonStyle(BounceButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color.themeBg.ignoresSafeArea())
    }
    
    private func getValue(for food: FoodItem) -> Double {
        switch macro {
        case .protein: return food.protein
        case .fat: return food.fats
        case .carbs: return food.carbs
        }
    }
}

// MARK: - ВСПОМОГАТЕЛЬНЫЕ UI КОМПОНЕНТЫ
struct LegendDot: View {
    let color: Color; let text: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption2.bold()).foregroundColor(.gray)
        }
    }
}

struct ChartLegendItem: View {
    let color: Color; let text: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8).shadow(color: color.opacity(0.5), radius: 2)
            Text(text).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(.gray)
        }
    }
}
