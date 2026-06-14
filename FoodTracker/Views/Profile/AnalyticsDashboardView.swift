import SwiftUI
import SwiftData
import Charts

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

    var id: String { self.rawValue }

    var color: Color {
        switch self {
        case .protein: return .themePeach
        case .fat: return .themeYellow
        case .carbs: return .drinkWater
        }
    }
}



struct AnalyticsTabView: View {
    @Environment(DIContainer.self) private var di
    @Query private var users: [User]

    @State private var viewModel: AnalyticsViewModel?
    @State private var globalPeriod: AnalyticsPeriod = .day

    var body: some View {
        NavigationStack {
            ZStack {

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

                            GlobalPeriodPicker(selection: $globalPeriod)
                                .padding(.horizontal, 20)
                                .onChange(of: globalPeriod) { _, newValue in
                                    viewModel?.loadData(for: newValue)
                                }

                            AIWeeklyInsightCard(summaries: viewModel?.summaries ?? [], user: user, period: globalPeriod)
                                .padding(.horizontal, 20)

                            if globalPeriod == .day {
                                DailyAnalyticsInsightView(summaries: viewModel?.summaries ?? [], user: user)
                                    .padding(.horizontal, 20)
                            } else {
                                TrendsAnalyticsInsightView(summaries: viewModel?.summaries ?? [], user: user, period: globalPeriod)
                                    .padding(.horizontal, 20)
                            }

                            ConsistencyHeatmapCard(summaries: viewModel?.summaries ?? [], user: user)
                                .padding(.horizontal, 20)

                        }
                        .padding(.bottom, 120)
                        .onAppear {
                            if viewModel == nil {
                                viewModel = di.makeAnalyticsViewModel()
                            }
                            viewModel?.loadData(for: globalPeriod)
                        }
                    }
                } else {
                    EmptyStateView(imageName: "chart.bar.xaxis", title: "No Data", description: "User data not found.")
                }
            }
            .navigationBarHidden(true)
        }
    }
}

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
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.5))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

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
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [insight.color.opacity(0.25), insight.color.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .stroke(insight.color.opacity(0.35), lineWidth: 1.5)
                    )
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(insight.color)
                    .symbolEffect(.pulse)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text(insight.text)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
            }
            Spacer()
        }
        .ultraPremiumCardStyle()
    }
}

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

            FitnessRingsCard(summary: todaySummary, user: user) { macro in
                selectedMacroForTop = macro
            }

            MealDistributionCard(summary: todaySummary)

            AIHydrationAnalyticsCard(summary: todaySummary)
        }
        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))

        .sheet(item: $selectedMacroForTop) { macro in
            TopSourcesSheetView(macro: macro, summary: todaySummary)
                .presentationDetents([.height(400)])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
        }
    }
}

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
                ZStack {
                    RingView(progress: p/tp, color: .themePeach, radius: 130, width: 14, delay: 0.0)
                    RingView(progress: f/tf, color: .themeYellow, radius: 98, width: 14, delay: 0.2)
                    RingView(progress: c/tc, color: .drinkWater, radius: 66, width: 14, delay: 0.4)
                }
                .frame(width: 130, height: 130)

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
        .ultraPremiumCardStyle()
    }
}

struct RingView: View {
    var progress: Double; var color: Color; var radius: CGFloat; var width: CGFloat
    var delay: Double = 0.0
    @State private var show = false

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.12), lineWidth: width)
            Circle()
                .trim(from: 0, to: show ? min(progress, 1.0) : 0)
                .stroke(
                    LinearGradient(colors: [color, color.opacity(0.85)], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: width, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.4), radius: 6, x: 0, y: 3)
        }
        .frame(width: radius, height: radius)
        .onAppear {
            withAnimation(
                .spring(response: 1.2, dampingFraction: 0.85)
                .delay(delay)
            ) {
                show = true
            }
        }
    }
}

struct LegendRow: View {
    let title: String; let current: Double; let target: Double; let color: Color
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 10, height: 10)
                        .shadow(color: color.opacity(0.4), radius: 3, x: 0, y: 1.5)
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(current))")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("/ \(Int(target))g")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray.opacity(0.8))
                }
                .padding(.leading, 18)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color.opacity(0.6))
                .padding(6)
                .background(color.opacity(0.1))
                .clipShape(Circle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.02))
        .cornerRadius(16)
        .contentShape(Rectangle())
    }
}

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
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        ForEach(meals, id: \.0) { meal in
                            let cals = summary?.meals.first(where: { $0.title == meal.0 })?.totalCalories ?? 0
                            if cals > 0 {
                                let width = max(0, (geo.size.width - 9) * CGFloat(Double(cals) / Double(totalCals)))
                                Rectangle()
                                    .fill(LinearGradient(colors: [meal.1, meal.1.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                                    .frame(width: showAnim ? width : 0)
                            }
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 14)
                .shadow(color: Color.black.opacity(0.03), radius: 3, y: 1.5)
                .onAppear { withAnimation(.spring()) { showAnim = true } }

                VStack(spacing: 10) {
                    ForEach(meals, id: \.0) { meal in
                        let cals = summary?.meals.first(where: { $0.title == meal.0 })?.totalCalories ?? 0
                        if cals > 0 {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(meal.1)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: meal.1, radius: 2)
                                
                                Text(meal.0)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(cals) kcal")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(.secondary)
                                
                                Text("\(Int((Double(cals)/Double(totalCals))*100))%")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(meal.1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(meal.1.opacity(0.1))
                                    .cornerRadius(8)
                                    .frame(width: 55, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.015))
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .ultraPremiumCardStyle()
    }
}

struct AIHydrationAnalyticsCard: View {
    let summary: DailySummary?
    @State private var animProgress: Double = 0
    
    var body: some View {
        let liters = summary?.totalHydrationLiters ?? 0
        let goal = 2.5
        let progress = min(liters / goal, 1.0)
        
        let advice = generateMockAdvice(liters: liters)
        
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Hydration Coach").font(.title3.bold())
                    Text("Optimizing your pH & metabolism").font(.caption).foregroundColor(.gray)
                }
                Spacer()
                ZStack {
                    Circle().fill(Color.cyan.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: "drop.fill").foregroundColor(.cyan).font(.title3)
                }
            }
            
            // Progress Section
            HStack(spacing: 20) {
                // Liquid capsule representing a modern glass
                ZStack(alignment: .bottom) {
                    // Glass background container
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cyan.opacity(0.08))
                        .frame(width: 45, height: 130)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.2), lineWidth: 1.5)
                        )
                    
                    // Liquid level with subtle wave effect using a soft vertical gradient and corner clipping
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.9), Color.blue],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 41, height: max(126 * CGFloat(animProgress), 0))
                        .padding(2)
                        .animation(.spring(response: 0.9, dampingFraction: 0.75), value: animProgress)
                    
                    // Measurement tick marks inside the glass
                    VStack(spacing: 16) {
                        ForEach(0..<4) { _ in
                            Rectangle()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 12, height: 1.5)
                        }
                    }
                    .padding(.bottom, 15)
                }
                .shadow(color: Color.cyan.opacity(0.15), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(String(format: "%.2f", liters)) L")
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.cyan)
                            .contentTransition(.numericText())
                        Text("/ \(String(format: "%.2f", goal)) L")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    
                    // Advice Box
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: advice.icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(advice.color)
                            Text(advice.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        Text(advice.message)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.gray)
                            .lineSpacing(3)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(
                        LinearGradient(
                            colors: [advice.color.opacity(0.12), advice.color.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(advice.color.opacity(0.2), lineWidth: 1)
                    )
                    .cornerRadius(16)
                }
            }
            
            // Educational Nudge
            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.gray.opacity(0.5))
                Text("Water maintains blood volume, flushes out excess sodium, and keeps your body's pH perfectly balanced.")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .ultraPremiumCardStyle()
        .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) { animProgress = progress } }
        .onChange(of: progress) { _, nv in withAnimation { animProgress = nv } }
    }
    
    private func generateMockAdvice(liters: Double) -> (title: String, message: String, color: Color, icon: String) {
        if liters < 1.0 {
            return ("Dehydration Risk", "Drink water now to stabilize your blood pH and prevent sodium retention.", .themeOrange, "exclamationmark.triangle.fill")
        } else if liters < 2.0 {
            return ("Keep Hydrating", "You're on track. A bit more water will help flush excess salt.", .themeYellow, "drop.circle.fill")
        } else {
            return ("Perfect Balance", "Your hydration is optimal! Your body's pH and sodium levels are perfectly balanced.", .green, "checkmark.seal.fill")
        }
    }
}

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
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(Color.themeOrange.opacity(0.8))
                    .annotation(position: .top, alignment: .leading) {
                        Text("GOAL").font(.system(size: 10, weight: .black)).foregroundColor(.themeOrange)
                    }

                ForEach(chartData, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Eaten", point.eaten)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundStyle(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                    .symbol { Circle().fill(.white).overlay(Circle().stroke(Color.themePink, lineWidth: 2)).frame(width: 8, height: 8) }

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Eaten", point.eaten)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Color.themePink.opacity(0.35), Color.clear], startPoint: .top, endPoint: .bottom))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated)).font(.caption2.bold()).foregroundStyle(Color.gray)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.12))
                    if let val = value.as(Double.self) {
                        AxisValueLabel("\(Int(val)) kcal").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.gray.opacity(0.8))
                    }
                }
            }
            .frame(height: 220)
        }
        .ultraPremiumCardStyle()
    }
}

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

            let carbs = s?.totalCarbs ?? 0
            let fats = s?.totalFats ?? 0
            let protein = s?.totalProtein ?? 0

            data.append(MacroData(date: date, type: "Carbs", value: carbs, color: .drinkWater))
            data.append(MacroData(date: date, type: "Fats", value: fats, color: .themeYellow))
            data.append(MacroData(date: date, type: "Protein", value: protein, color: .themePeach))
        }
        return data
    }

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
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Grams", item.value),
                        width: .fixed(10)
                    )
                    .foregroundStyle(by: .value("Type", item.type))
                }
            }
            .chartForegroundStyleScale([
                "Carbs": LinearGradient(colors: [Color.drinkWater, Color.drinkWater.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                "Fats": LinearGradient(colors: [Color.themeYellow, Color.themeYellow.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                "Protein": LinearGradient(colors: [Color.themePeach, Color.themePeach.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            ])
            .chartYScale(domain: 0...maxGrams)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) { AxisValueLabel(format: .dateTime.weekday(.narrow)).font(.caption2.bold()).foregroundStyle(Color.gray) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.12))
                    if let val = value.as(Double.self) {
                        AxisValueLabel("\(Int(val))g").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.gray)
                    }
                }
            }
            .frame(height: 200)

            HStack(spacing: 20) {
                ChartLegendItem(color: .themePeach, text: "Protein")
                ChartLegendItem(color: .themeYellow, text: "Fats")
                ChartLegendItem(color: .drinkWater, text: "Carbs")
            }
        }
        .ultraPremiumCardStyle()
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
        return max(3.0, maxData + 0.5)
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
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(Color.cyan.opacity(0.7))
                    .annotation(position: .top, alignment: .leading) {
                        Text("GOAL (2.5L)")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundColor(.cyan)
                    }

                ForEach(chartData, id: \.date) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Liters", point.liters),
                        width: .fixed(12)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, Color.cyan.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartYScale(domain: 0...maxLiters)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) { AxisValueLabel(format: .dateTime.weekday(.narrow)).font(.caption2.bold()).foregroundStyle(Color.gray) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 1, 2, 3]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.12))
                    if let val = value.as(Double.self), val >= 0 {
                        AxisValueLabel("\(Int(val))L").font(.caption2).foregroundStyle(Color.gray)
                    }
                }
            }
            .frame(height: 200)
        }
        .ultraPremiumCardStyle()
    }
}

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
                    let isToday = Calendar.current.isDateInToday(date)

                    VStack(spacing: 6) {
                        Text(Calendar.current.component(.day, from: date).description)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(isToday ? .themePink : .gray.opacity(0.8))
                        
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(level > 0 ? 0.75 : 1.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 16, height: 42)
                            .overlay(
                                Capsule()
                                    .stroke(isToday ? Color.themePink.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1.5)
                            )
                            .shadow(color: level > 0 ? color.opacity(0.35) : Color.clear, radius: 5, x: 0, y: 3)
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
        .ultraPremiumCardStyle()
    }
}

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
