import SwiftUI
import SwiftData
import Charts

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case day = "Daily"
    case week = "Weekly"
    case month = "Monthly"
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

enum AnalyticsMicro: String, CaseIterable, Identifiable {
    case omega3 = "Omega-3"
    case potassium = "Potassium"
    case magnesium = "Magnesium"
    case calcium = "Calcium"
    case iron = "Iron"
    case vitaminC = "Vitamin C"
    case vitaminD = "Vitamin D"

    var id: String { self.rawValue }

    var unit: String {
        switch self {
        case .omega3: return "g"
        case .potassium, .magnesium, .calcium, .iron, .vitaminC: return "mg"
        case .vitaminD: return "mcg"
        }
    }

    var rda: Double {
        switch self {
        case .omega3: return 1.6
        case .potassium: return 3500.0
        case .magnesium: return 400.0
        case .calcium: return 1000.0
        case .iron: return 12.0
        case .vitaminC: return 90.0
        case .vitaminD: return 20.0
        }
    }

    var icon: String {
        switch self {
        case .omega3: return "brain.fill"
        case .potassium: return "heart.fill"
        case .magnesium: return "bolt.fill"
        case .calcium: return "bone.fill"
        case .iron: return "dumbbell.fill"
        case .vitaminC: return "sparkles"
        case .vitaminD: return "sun.max.fill"
        }
    }

    var color: Color {
        switch self {
        case .omega3: return .purple
        case .potassium: return .pink
        case .magnesium: return .themeOrange
        case .calcium: return .orange
        case .iron: return .red
        case .vitaminC: return .themeYellow
        case .vitaminD: return .green
        }
    }
}



struct AnalyticsTabView: View {
    @Environment(DIContainer.self) private var di
    @Query private var users: [User]

    @State private var viewModel: AnalyticsViewModel?
    @State private var globalPeriod: AnalyticsPeriod = .day
    @State private var bgPhase = 0.0

    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.themeBg.ignoresSafeArea()

                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 400, height: 400)
                        .blur(radius: 80)
                        .offset(x: bgPhase == 0 ? -150 : -50, y: bgPhase == 0 ? -250 : -150)

                    Circle()
                        .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 350, height: 350)
                        .blur(radius: 90)
                        .offset(x: bgPhase == 0 ? 150 : 50, y: bgPhase == 0 ? 350 : 250)
                }
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        bgPhase = 1.0
                    }
                }

                if let user = users.first {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            // Header
                            VStack(spacing: 16) {
                                HStack {
                                    Text(LocalizedStringKey("Dashboard"))
                                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                                    Spacer()
                                    Image(systemName: "chart.bar.xaxis")
                                        .font(.title2.bold())
                                        .foregroundStyle(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom))
                                }
                                .padding(.horizontal, 24)
                                
                                GlobalPeriodPicker(selection: $globalPeriod)
                                    .padding(.horizontal, 20)
                                    .onChange(of: globalPeriod) { _, newValue in
                                        viewModel?.loadData(for: newValue)
                                    }
                            }
                            .padding(.top, 10)
                            .opacity(animateIn ? 1 : 0)
                            .offset(y: animateIn ? 0 : -20)

                            MetabolicScoreCard(summaries: viewModel?.summaries ?? [], user: user, period: globalPeriod)
                                .padding(.horizontal, 20)
                                .opacity(animateIn ? 1 : 0)
                                .offset(y: animateIn ? 0 : 30)
                                .zIndex(2)

                            if globalPeriod == .day {
                                DailyAnalyticsInsightView(summaries: viewModel?.summaries ?? [], user: user) {
                                    viewModel?.loadData(for: globalPeriod)
                                }
                                .padding(.horizontal, 20)
                            } else {
                                TrendsAnalyticsInsightView(summaries: viewModel?.summaries ?? [], user: user, period: globalPeriod)
                                    .padding(.horizontal, 20)
                            }

                        }
                        .padding(.bottom, 120)
                        .onAppear {
                            if viewModel == nil {
                                viewModel = di.makeAnalyticsViewModel()
                            }
                            viewModel?.loadData(for: globalPeriod)
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                animateIn = true
                            }
                        }
                    }
                    
                } else {
                    EmptyStateView(imageName: "chart.bar.xaxis", title: String(localized: "No Data"), description: String(localized: "User data not found."))
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Metabolic Score Hero
struct MetabolicScoreCard: View {
    let summaries: [DailySummary]
    let user: User
    let period: AnalyticsPeriod

    @State private var animScore: Double = 0
    @State private var tiltAngle: Double = 0
    @State private var tiltAxis: (CGFloat, CGFloat, CGFloat) = (0, 1, 0)

    private var subScores: (cal: Double, hyd: Double, macro: Double) {
        var totalCals = 0.0
        var totalHydration = 0.0
        let sortedSummaries = summaries.sorted { $0.date > $1.date }
        let days = max(1, min(sortedSummaries.count, period.daysCount))

        for s in sortedSummaries.prefix(days) {
            totalCals += Double(s.totalFoodCalories)
            totalHydration += s.totalHydrationLiters
        }

        let avgCals = days > 0 ? totalCals / Double(days) : 0
        let avgHydration = days > 0 ? totalHydration / Double(days) : 0

        // Calorie Score (0-50)
        let targetCals = user.dailyCaloriesGoal
        let calRatio = targetCals > 0 ? min(avgCals / Double(targetCals), 1.5) : 0
        var calScore = 0.0
        if calRatio <= 1.0 {
            calScore = calRatio * 50
        } else {
            calScore = max(0, 50 - ((calRatio - 1.0) * 100))
        }

        // Hydration Score (0-30)
        let hydRatio = min(avgHydration / 2.5, 1.0)
        let hydScore = hydRatio * 30

        // Consistency/Macros (0-20)
        var macroScore = 0.0
        if days > 0 {
            var totalP = 0.0, totalF = 0.0, totalC = 0.0
            for s in sortedSummaries.prefix(days) {
                totalP += s.totalProtein
                totalF += s.totalFats
                totalC += s.totalCarbs
            }
            let avgP = totalP / Double(days)
            let avgF = totalF / Double(days)
            let avgC = totalC / Double(days)
            
            let targetP = user.targetProtein > 0 ? user.targetProtein : 1
            let targetF = user.targetFats > 0 ? user.targetFats : 1
            let targetC = user.targetCarbs > 0 ? user.targetCarbs : 1
            
            let pRatio = min(avgP / Double(targetP), 1.0)
            let fRatio = min(avgF / Double(targetF), 1.0)
            let cRatio = min(avgC / Double(targetC), 1.0)
            
            let avgMacroRatio = (pRatio + fRatio + cRatio) / 3.0
            macroScore = avgMacroRatio * 20.0
        }

        return (calScore, hydScore, macroScore)
    }

    private var score: Int {
        let subs = subScores
        let finalScore = Int(subs.cal + subs.hyd + subs.macro)
        return min(max(finalScore, 0), 100)
    }

    private var scoreColor: Color {
        if score >= 90 { return .green }
        if score >= 70 { return .themeOrange }
        return .themePink
    }

    var body: some View {
        let subs = subScores
        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Metabolic Health")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    Text("Calculated overall synergy")
                        .font(.caption.bold())
                        .foregroundColor(.primary.opacity(0.75))
                }
                Spacer()
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundColor(scoreColor)
            }

            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.1), lineWidth: 20)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: CGFloat(animScore / 100.0))
                    .stroke(
                        AngularGradient(gradient: Gradient(colors: [scoreColor.opacity(0.5), scoreColor, scoreColor.opacity(0.5)]), center: .center),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 200, height: 200)
                    .shadow(color: scoreColor.opacity(0.6), radius: 15, x: 0, y: 0)

                VStack(spacing: -5) {
                    Text("\(Int(animScore))")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                    Text("out of 100")
                        .font(.caption.bold())
                        .foregroundColor(.primary.opacity(0.75))
                }
            }
            .padding(.vertical, 10)
            .rotation3DEffect(.degrees(tiltAngle), axis: tiltAxis)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let maxTilt: CGFloat = 20
                        let w = 200.0
                        let h = 200.0
                        let x = min(max(value.location.x, 0), w) - (w / 2)
                        let y = min(max(value.location.y, 0), h) - (h / 2)
                        
                        let pctX = x / (w / 2)
                        let pctY = y / (h / 2)
                        
                        tiltAxis = (-pctY, pctX, 0)
                        withAnimation(.interactiveSpring) {
                            tiltAngle = maxTilt * sqrt(pctX*pctX + pctY*pctY)
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.5)) {
                            tiltAngle = 0
                        }
                    }
            )

            // Detailed Breakdown
            VStack(alignment: .leading, spacing: 14) {
                Divider()
                
                Text("Metabolic Health Breakdown")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                VStack(spacing: 10) {
                    MetabolicBreakdownRow(icon: "flame.fill", title: String(localized: "Caloric Adherence"), value: subs.cal, total: 50, color: .themeOrange)
                    MetabolicBreakdownRow(icon: "drop.fill", title: String(localized: "Hydration Status"), value: subs.hyd, total: 30, color: .blue)
                    MetabolicBreakdownRow(icon: "chart.bar.fill", title: String(localized: "Macro & Logging Stability"), value: subs.macro, total: 20, color: .green)
                }
                
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(scoreColor)
                        .font(.system(size: 22, weight: .bold))
                    
                    Text("Your metabolic score shows energy & hydration efficiency. Keep it above **90** for peak performance!")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(scoreColor.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(scoreColor.opacity(0.4), lineWidth: 2.0)
                )
                .shadow(color: scoreColor.opacity(0.12), radius: 8, x: 0, y: 4)
                .padding(.top, 8)
            }
            .padding(.top, 4)
        }
        .divineCardStyle()
        .onAppear {
            withAnimation(.spring(response: 1.5, dampingFraction: 0.7)) {
                animScore = Double(score)
            }
        }
        .onChange(of: score) { _, nv in
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animScore = Double(nv)
            }
        }
    }
}

// MARK: - Metabolic Breakdown Row
struct MetabolicBreakdownRow: View {
    let icon: String
    let title: String
    let value: Double
    let total: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 12, weight: .bold))
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("\(Int(value)) / \(Int(total)) pts")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Custom premium progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.06))
                        .frame(height: 6)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * CGFloat(value / total)), height: 6)
                        .shadow(color: color.opacity(0.2), radius: 2, y: 1)
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color.gray.opacity(0.03))
        .cornerRadius(14)
    }
}

// MARK: - Period Picker
struct GlobalPeriodPicker: View {
    @Binding var selection: AnalyticsPeriod
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AnalyticsPeriod.allCases) { period in
                Button(action: {
                    selection = period
                }) {
                    ZStack {
                        Text("Monthly").font(.system(size: 15, weight: .bold)).hidden()
                        Text(LocalizedStringKey(period.rawValue))
                            .font(.system(size: 15, weight: selection == period ? .bold : .medium, design: .rounded))
                            .foregroundColor(selection == period ? .white : .primary.opacity(0.7))
                    }
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

// MARK: - Typewriter AI Text
struct AITypewriterCard: View {
    let score: Int
    let period: AnalyticsPeriod

    private var insight: (title: String, text: String, color: Color) {
        let activeSummaries = Array(summaries.suffix(period.daysCount))
        let validSummaries = activeSummaries.filter { $0.totalFoodCalories > 0 }

        let avgCals = validSummaries.isEmpty ? 0 : validSummaries.reduce(0) { $0 + $1.totalFoodCalories } / validSummaries.count
        let avgWater = activeSummaries.isEmpty ? 0.0 : activeSummaries.reduce(0.0) { $0 + $1.totalHydrationLiters } / Double(activeSummaries.count)

        // Find the lowest micronutrient percentage today or weekly avg
        let micronutrients = AnalyticsMicro.allCases
        var lowestMicro: AnalyticsMicro?
        var lowestPct = 1.0

        if period == .day {
            let today = summaries.first(where: { Calendar.current.isDateInToday($0.date) })
            if let today = today {
                for micro in micronutrients {
                    let amount = getValue(for: micro, in: today)
                    let pct = amount / micro.rda
                    if pct < lowestPct {
                        lowestPct = pct
                        lowestMicro = micro
                    }
                }
            }

            let water = today?.totalHydrationLiters ?? 0.0
            if water < 1.0 {
                return ("Hydration Alert", "You've logged \(String(format: "%.1f", water))L of water today. Drink a glass now to boost metabolism and energy!", .cyan)
            } else if let lowest = lowestMicro, lowestPct < 0.6 {
                let hint = getHint(for: lowest)
                return ("\(lowest.rawValue) Focus", "Your \(lowest.rawValue) is only at \(Int(lowestPct * 100))% of RDA. \(hint)", lowest.color)
            } else if let eaten = today?.totalFoodCalories, eaten > user.dailyCaloriesGoal {
                return ("Caloric Limit", "You've exceeded your daily calorie goal by \(eaten - user.dailyCaloriesGoal) kcal. Keep dinner light today.", .themeOrange)
            } else {
                return ("Daily Focus", "All parameters are in range! Continue logging your meals to sustain this streak.", .green)
            }
        } else {
            // Weekly/Monthly trend
            if avgCals == 0 {
                return ("Start Tracking", "Log your meals and fluids to activate personal AI analytics and dynamic trend insights.", .gray)
            }
            
            // Check average micro levels
            for micro in micronutrients {
                let totalAmount = validSummaries.reduce(0.0) { $0 + getValue(for: micro, in: $1) }
                let avgAmount = totalAmount / Double(max(1, validSummaries.count))
                let pct = avgAmount / micro.rda
                if pct < lowestPct {
                    lowestPct = pct
                    lowestMicro = micro
                }
            }

            if avgWater < 1.5 {
                return ("Hydration Trend", "Your average hydration (\(String(format: "%.2f", avgWater))L) is below the 2.5L target. Focus on drinking more fluids.", .cyan)
            } else if let lowest = lowestMicro, lowestPct < 0.7 {
                let hint = getHint(for: lowest)
                return ("\(lowest.rawValue) Trend", "Your average \(lowest.rawValue) is low (\(Int(lowestPct * 100))%). \(hint)", lowest.color)
            } else if avgCals > user.dailyCaloriesGoal + 100 {
                return ("Calorie Trend", "Your daily average is \(avgCals) kcal, slightly above your goal. Consider adjusting portion sizes.", .themeOrange)
            } else {
                return ("Perfect Streak", "Excellent consistency! Your average is \(avgCals) kcal. You are perfectly hitting your goals! Keep it up.", .green)
            }
        }
    }

    private func getValue(for micro: AnalyticsMicro, in summary: DailySummary) -> Double {
        switch micro {
        case .omega3: return summary.totalOmega3
        case .potassium: return summary.totalPotassium
        case .magnesium: return summary.totalMagnesium
        case .calcium: return summary.totalCalcium
        case .iron: return summary.totalIron
        case .vitaminC: return summary.totalVitaminC
        case .vitaminD: return summary.totalVitaminD
        }
    }

    private func getHint(for micro: AnalyticsMicro) -> String {
        switch micro {
        case .omega3: return "Try adding fatty fish (salmon), flaxseeds, or walnuts to your meals."
        case .potassium: return "Foods like bananas, avocados, spinach, and sweet potatoes are rich in potassium."
        case .magnesium: return "Try eating pumpkin seeds, dark chocolate, almonds, or spinach."
        case .calcium: return "Add yogurt, cheese, milk, tofu, or almonds to boost your calcium."
        case .iron: return "Eat red meat, spinach, lentils, or fortified cereals to increase iron."
        case .vitaminC: return "Oranges, bell peppers, strawberries, and broccoli are great sources."
        case .vitaminD: return "Consider egg yolks, mushrooms, fatty fish, or brief sun exposure."
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
            
            Text(displayedText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.95))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 80, alignment: .topLeading)
        }
        .ultraPremiumCardStyle()
    }
}

// MARK: - Daily Insight
struct DailyAnalyticsInsightView: View {
    let summaries: [DailySummary]
    let user: User
    var onUpdate: () -> Void = {}

    @State private var selectedMicroForTop: AnalyticsMicro? = nil

    private var todaySummary: DailySummary? {
        let calendar = Calendar.current
        return summaries.first(where: { calendar.isDateInToday($0.date) })
    }

    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(spacing: 24) {
            CompactDailySummaryCard(summary: todaySummary, user: user)

            AIHydrationAnalyticsCard(summary: todaySummary, onUpdate: onUpdate)

            MicronutrientsGridCard(summary: todaySummary) { micro in
                selectedMicroForTop = micro
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
        .sheet(item: $selectedMicroForTop) { micro in
            TopMicroSourcesSheetView(micro: micro, summary: todaySummary)
                .presentationDetents([.height(420)])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
        }
    }
    
    private func calculateScore() -> Int {
        var totalCals = 0.0
        var totalHydration = 0.0
        let sortedSummaries = summaries.sorted { $0.date > $1.date }
        let days = 1
        for s in sortedSummaries.prefix(days) {
            totalCals += Double(s.totalFoodCalories)
            totalHydration += s.totalHydrationLiters
        }
        let avgCals = days > 0 ? totalCals / Double(days) : 0
        let avgHydration = days > 0 ? totalHydration / Double(days) : 0
        let targetCals = user.dailyCaloriesGoal
        let calRatio = targetCals > 0 ? min(avgCals / Double(targetCals), 1.5) : 0
        var calScore = 0.0
        if calRatio <= 1.0 { calScore = calRatio * 50 } else { calScore = max(0, 50 - ((calRatio - 1.0) * 100)) }
        let hydRatio = min(avgHydration / 2.5, 1.0)
        let hydScore = hydRatio * 30
        let macroScore = 20.0
        let finalScore = Int(calScore + hydScore + macroScore)
        return min(max(finalScore, 0), 100)
    }
}

struct CompactDailySummaryCard: View {
    let summary: DailySummary?
    let user: User

    var body: some View {
        let eaten = summary?.totalFoodCalories ?? 0
        let target = user.dailyCaloriesGoal
        let progress = min(Double(eaten) / Double(max(1, target)), 1.0)

        let p = summary?.totalProtein ?? 0; let tp = user.targetProtein
        let f = summary?.totalFats ?? 0;  let tf = user.targetFats
        let c = summary?.totalCarbs ?? 0; let tc = user.targetCarbs

        VStack(spacing: 18) {
            // Calories Progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Energy & Macros").font(.headline.bold())
                        Text("Today's balance summary").font(.caption2).foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(eaten)").font(.system(size: 22, weight: .heavy, design: .rounded)).foregroundColor(.primary)
                        Text("/ \(target) kcal").font(.caption).foregroundColor(.secondary)
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                        Capsule()
                            .fill(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(progress))
                            .shadow(color: Color.themePink.opacity(0.3), radius: 6, x: 0, y: 3)
                    }
                }
                .frame(height: 10)
            }

            // Macros Row
            HStack(spacing: 20) {
                MacroBar(title: "Protein", current: p, target: tp, color: .themePeach)
                MacroBar(title: "Fats", current: f, target: tf, color: .themeYellow)
                MacroBar(title: "Carbs", current: c, target: tc, color: .drinkWater)
            }
        }
        .ultraPremiumCardStyle()
    }
}

struct MacroBar: View {
    let title: String
    let current: Double
    let target: Double
    let color: Color

    var body: some View {
        let percent = min(current / max(1, target), 1.0)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).bold().foregroundColor(.secondary)
                Spacer()
                Text("\(Int(current))g").font(.caption).bold().foregroundColor(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.04))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(percent))
                }
            }
            .frame(height: 6)
        }
    }
}

struct MicronutrientsGridCard: View {
    let summary: DailySummary?
    let onMicroTap: (AnalyticsMicro) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Micronutrients").font(.title3.bold())
                    Text("Tap to see food sources").font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles.rectangle.stack.fill").foregroundColor(.themePink.opacity(0.8))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AnalyticsMicro.allCases) { micro in
                    let amount = getValue(for: micro)
                    MicronutrientCell(micro: micro, amount: amount) {
                        onMicroTap(micro)
                    }
                }
            }
        }
        .ultraPremiumCardStyle()
    }

    private func getValue(for micro: AnalyticsMicro) -> Double {
        guard let summary = summary else { return 0 }
        switch micro {
        case .omega3: return summary.totalOmega3
        case .potassium: return summary.totalPotassium
        case .magnesium: return summary.totalMagnesium
        case .calcium: return summary.totalCalcium
        case .iron: return summary.totalIron
        case .vitaminC: return summary.totalVitaminC
        case .vitaminD: return summary.totalVitaminD
        }
    }
}

struct MicronutrientCell: View {
    let micro: AnalyticsMicro
    let amount: Double
    let action: () -> Void

    var body: some View {
        let pct = min(amount / max(0.1, micro.rda), 2.0)

        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // Thin background track
                    Circle()
                        .stroke(micro.color.opacity(0.1), lineWidth: 5)
                        .frame(width: 54, height: 54)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: CGFloat(min(pct, 1.0)))
                        .stroke(
                            LinearGradient(
                                colors: [micro.color, micro.color.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)
                        .shadow(color: micro.color.opacity(0.3), radius: 3, x: 0, y: 2)

                    // Icon in the center
                    Image(systemName: micro.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(micro.color)
                }

                VStack(spacing: 2) {
                    Text(micro.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("\(Int(pct * 100))%")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(micro.color)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.02))
            .cornerRadius(16)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

struct AIHydrationAnalyticsCard: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    let summary: DailySummary?
    var onUpdate: () -> Void = {}
    
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
            
            // Quick Add Water Buttons
            HStack(spacing: 16) {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    let today = Calendar.current.startOfDay(for: Date())
                    var targetSummary: DailySummary? = summary
                    if targetSummary == nil {
                        let descriptor = FetchDescriptor<DailySummary>(
                            predicate: #Predicate<DailySummary> { $0.date == today }
                        )
                        if let existing = try? context.fetch(descriptor).first {
                            targetSummary = existing
                        }
                    }
                    if let targetSummary = targetSummary {
                        if let lastWater = targetSummary.beverages.last(where: { $0.name == "Water" }) {
                            if let index = targetSummary.beverages.firstIndex(of: lastWater) {
                                targetSummary.beverages.remove(at: index)
                            }
                            context.delete(lastWater)
                            try? context.save()
                            onUpdate()
                        }
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.cyan)
                        .frame(width: 50, height: 50)
                        .background(Color.cyan.opacity(0.15))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    let today = Calendar.current.startOfDay(for: Date())
                    var targetSummary: DailySummary? = summary
                    if targetSummary == nil {
                        let descriptor = FetchDescriptor<DailySummary>(
                            predicate: #Predicate<DailySummary> { $0.date == today }
                        )
                        if let existing = try? context.fetch(descriptor).first {
                            targetSummary = existing
                        } else {
                            let newSummary = DailySummary(date: today)
                            context.insert(newSummary)
                            targetSummary = newSummary
                        }
                    }
                    if let targetSummary = targetSummary {
                        let newBeverage = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 250.0)
                        context.insert(newBeverage)
                        targetSummary.beverages.append(newBeverage)
                        try? context.save()
                        onUpdate()
                        
                        if let user = users.first, user.isHealthKitEnabled {
                            Task {
                                await HealthKitManager.shared.saveWater(liters: 0.25, date: Date())
                            }
                        }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add 250ml")
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(25)
                    .shadow(color: Color.cyan.opacity(0.3), radius: 8, y: 4)
                }
            }
            .padding(.top, 4)
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
    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 24) {
            
            AITypewriterCard(score: calculateScore(), period: period)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)

            DivineCaloriesChart(summaries: summaries, user: user, period: period)
            TrendsMicroChart(summaries: summaries, period: period)
            TrendsWaterChart(summaries: summaries, period: period)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateIn = true
            }
        }
    }
    
    private func calculateScore() -> Int {
        var totalCals = 0.0
        var totalHydration = 0.0
        let sortedSummaries = summaries.sorted { $0.date > $1.date }
        let days = max(1, min(sortedSummaries.count, period.daysCount))
        for s in sortedSummaries.prefix(days) {
            totalCals += Double(s.totalFoodCalories)
            totalHydration += s.totalHydrationLiters
        }
        let avgCals = days > 0 ? totalCals / Double(days) : 0
        let avgHydration = days > 0 ? totalHydration / Double(days) : 0
        let targetCals = user.dailyCaloriesGoal
        let calRatio = targetCals > 0 ? min(avgCals / Double(targetCals), 1.5) : 0
        var calScore = 0.0
        if calRatio <= 1.0 { calScore = calRatio * 50 } else { calScore = max(0, 50 - ((calRatio - 1.0) * 100)) }
        let hydRatio = min(avgHydration / 2.5, 1.0)
        let hydScore = hydRatio * 30
        let macroScore = 20.0
        let finalScore = Int(calScore + hydScore + macroScore)
        return min(max(finalScore, 0), 100)
    }
}

// MARK: - Interactive Calories Chart
struct DivineCaloriesChart: View {
    let summaries: [DailySummary]; let user: User; let period: AnalyticsPeriod
    
    @State private var selectedDate: Date?

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
                    Text(LocalizedStringKey("Energy Trend")).font(.title3.bold())
                    Text(LocalizedStringKey("Daily Caloric Intake")).font(.caption.bold()).foregroundColor(.primary.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chart.xyaxis.line").font(.title2).foregroundColor(.themePink)
            }

            Chart {
                RuleMark(y: .value("Goal", user.dailyCaloriesGoal))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(Color.themeOrange.opacity(0.8))
                    .annotation(position: .top, alignment: .leading) {
                        Text(LocalizedStringKey("GOAL")).font(.system(size: 10, weight: .black)).foregroundColor(.themeOrange)
                    }

                ForEach(chartData, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Eaten", point.eaten)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundStyle(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                    .symbol { Circle().fill(.white).overlay(Circle().stroke(Color.themePink, lineWidth: 2)).frame(width: 8, height: 8).shadow(color: .themePink, radius: 5) }

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Eaten", point.eaten)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Color.themePink.opacity(0.35), Color.clear], startPoint: .top, endPoint: .bottom))
                }
                
                // Scrubbing Overlay
                if let selectedDate, let point = chartData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                    RuleMark(x: .value("Date", selectedDate))
                        .foregroundStyle(Color.gray.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .annotation(position: .top, alignment: .center, spacing: 0) {
                            VStack(spacing: 4) {
                                Text("\(Int(point.eaten)) kcal")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text(selectedDate.formatted(.dateTime.month().day()))
                                    .font(.caption2.bold())
                                    .foregroundColor(.primary.opacity(0.75))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .shadow(radius: 5)
                        }
                    
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Eaten", point.eaten)
                    )
                    .symbol { Circle().fill(Color.themePink).frame(width: 12, height: 12).shadow(color: .themePink, radius: 10) }
                }
            }
            .chartXSelection(value: $selectedDate)
            .onChange(of: selectedDate) { _, _ in
                // No haptics on chart drag
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated)).font(.caption2.bold()).foregroundStyle(Color.primary.opacity(0.75))
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

struct TrendsMicroChart: View {
    let summaries: [DailySummary]
    let period: AnalyticsPeriod

    @State private var selectedMicro: AnalyticsMicro = .vitaminC

    private var chartData: [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<period.daysCount).map { i in
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            let summary = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
            let value: Double
            if let s = summary {
                switch selectedMicro {
                case .omega3: value = s.totalOmega3
                case .potassium: value = s.totalPotassium
                case .magnesium: value = s.totalMagnesium
                case .calcium: value = s.totalCalcium
                case .iron: value = s.totalIron
                case .vitaminC: value = s.totalVitaminC
                case .vitaminD: value = s.totalVitaminD
                }
            } else {
                value = 0.0
            }
            return (date: date, value: value)
        }.reversed()
    }

    private var maxVal: Double {
        let maxData = chartData.map { $0.value }.max() ?? 0
        return max(selectedMicro.rda * 1.2, maxData * 1.1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Micronutrient Trend").font(.title3.bold())
                    Text("Weekly & monthly trace").font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "waveform.path.ecg").foregroundColor(selectedMicro.color)
            }

            // Micronutrient horizontal selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AnalyticsMicro.allCases) { micro in
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedMicro = micro
                            }
                        }) {
                            Text(micro.rawValue)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(selectedMicro == micro ? .white : .primary.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedMicro == micro ? micro.color : Color.primary.opacity(0.04))
                                )
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            Chart {
                RuleMark(y: .value("RDA Goal", selectedMicro.rda))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(selectedMicro.color.opacity(0.8))
                    .annotation(position: .top, alignment: .leading) {
                        Text("GOAL (\(Int(selectedMicro.rda))\(selectedMicro.unit))")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(selectedMicro.color)
                    }

                ForEach(chartData, id: \.date) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                    .foregroundStyle(selectedMicro.color)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [selectedMicro.color.opacity(0.35), selectedMicro.color.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .chartYScale(domain: 0...maxVal)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel(format: .dateTime.weekday(.narrow)).font(.caption2.bold()).foregroundStyle(Color.gray)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.12))
                    if let val = value.as(Double.self) {
                        AxisValueLabel("\(Int(val))\(selectedMicro.unit)").font(.system(size: 9, weight: .bold)).foregroundStyle(Color.gray)
                    }
                }
            }
            .frame(height: 200)
            .animation(.easeInOut, value: selectedMicro)
        }
        .ultraPremiumCardStyle()
    }
}

struct TrendsWaterChart: View {
    let summaries: [DailySummary]; let period: AnalyticsPeriod
    @State private var selectedDate: Date?

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
                Text(LocalizedStringKey("Fluid Intake")).font(.title3.bold())
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
                    .cornerRadius(6)
                }
                
                if let selectedDate, let point = chartData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                    RuleMark(x: .value("Date", selectedDate))
                        .foregroundStyle(Color.cyan.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                        .annotation(position: .top, alignment: .center, spacing: 0) {
                            VStack(spacing: 4) {
                                Text("\(String(format: "%.1f", point.liters)) L")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.cyan)
                                Text(selectedDate.formatted(.dateTime.month().day()))
                                    .font(.caption2.bold())
                                    .foregroundColor(.primary.opacity(0.75))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                            .shadow(radius: 5)
                        }
                }
            }
            .chartXSelection(value: $selectedDate)
            .onChange(of: selectedDate) { _, _ in
                // No haptics on chart drag
            }
            .chartYScale(domain: 0...maxLiters)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) { AxisValueLabel(format: .dateTime.weekday(.narrow)).font(.caption2.bold()).foregroundStyle(Color.primary.opacity(0.75)) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 1, 2, 3]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.12))
                    if let val = value.as(Double.self), val >= 0 {
                        AxisValueLabel("\(Int(val))L").font(.caption2.bold()).foregroundStyle(Color.primary.opacity(0.75))
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
                Text("Last 14 Days").font(.caption.bold()).foregroundColor(.primary.opacity(0.75))
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
                .padding(.horizontal, 2)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 12) {
                LegendDot(color: .green, text: String(localized: "Perfect"))
                LegendDot(color: .themeOrange, text: String(localized: "Over"))
                LegendDot(color: .themeYellow, text: String(localized: "Under"))
            }.padding(.top, 8)
        }
        .ultraPremiumCardStyle()
    }
}

struct TopMicroSourcesSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let micro: AnalyticsMicro
    let summary: DailySummary?

    private var topFoods: [FoodItem] {
        guard let summary = summary else { return [] }
        let allFoods = summary.meals.flatMap { $0.foodItems }
        switch micro {
        case .omega3: return Array(allFoods.filter { $0.omega3 > 0 }.sorted { $0.omega3 > $1.omega3 }.prefix(3))
        case .potassium: return Array(allFoods.filter { $0.potassium > 0 }.sorted { $0.potassium > $1.potassium }.prefix(3))
        case .magnesium: return Array(allFoods.filter { $0.magnesium > 0 }.sorted { $0.magnesium > $1.magnesium }.prefix(3))
        case .calcium: return Array(allFoods.filter { $0.calcium > 0 }.sorted { $0.calcium > $1.calcium }.prefix(3))
        case .iron: return Array(allFoods.filter { $0.iron > 0 }.sorted { $0.iron > $1.iron }.prefix(3))
        case .vitaminC: return Array(allFoods.filter { $0.vitaminC > 0 }.sorted { $0.vitaminC > $1.vitaminC }.prefix(3))
        case .vitaminD: return Array(allFoods.filter { $0.vitaminD > 0 }.sorted { $0.vitaminD > $1.vitaminD }.prefix(3))
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Top \(micro.rawValue) Sources")
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .padding(.top, 24)

            if topFoods.isEmpty {
                Spacer()
                Text("No sources logged yet today.").font(.subheadline).foregroundColor(.gray)
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
                                .background(micro.color.opacity(index == 0 ? 1.0 : (index == 1 ? 0.7 : 0.4)))
                                .clipShape(Circle())

                            Text(food.name).font(.system(size: 16, weight: .bold, design: .rounded)).lineLimit(1)
                            Spacer()
                            Text("\(value, specifier: "%.1f") \(micro.unit)").font(.headline).foregroundColor(micro.color)
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
            }

            Button(action: { dismiss() }) {
                Text("Close")
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding(.vertical, 16).background(micro.color).cornerRadius(20)
            }
            .buttonStyle(BounceButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private func getValue(for food: FoodItem) -> Double {
        switch micro {
        case .omega3: return food.omega3
        case .potassium: return food.potassium
        case .magnesium: return food.magnesium
        case .calcium: return food.calcium
        case .iron: return food.iron
        case .vitaminC: return food.vitaminC
        case .vitaminD: return food.vitaminD
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
