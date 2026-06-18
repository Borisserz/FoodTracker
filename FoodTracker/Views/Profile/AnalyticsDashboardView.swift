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

// MARK: - Glassmorphism 2.0
struct DivineCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white.opacity(0.65))
                    .shadow(color: Color.black.opacity(0.08), radius: 25, x: 0, y: 15)
            )
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(LinearGradient(colors: [.white, .white.opacity(0.1), .white.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            )
    }
}

extension View {
    func divineCardStyle() -> some View {
        self.modifier(DivineCardModifier())
    }
}

struct AnalyticsTabView: View {
    @Environment(DIContainer.self) private var di
    @Query private var users: [User]

    @State private var viewModel: AnalyticsViewModel?
    @State private var globalPeriod: AnalyticsPeriod = .day

    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.themeBg.ignoresSafeArea()

                // Dynamic background
                GeometryReader { proxy in
                    ZStack {
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.themePink.opacity(0.2),
                                Color.themeOrange.opacity(0.15),
                                Color.blue.opacity(0.1),
                                Color.themePink.opacity(0.2)
                            ]),
                            center: .center,
                            angle: .degrees(animateIn ? 360 : 0)
                        )
                        .frame(width: proxy.size.width * 1.5, height: proxy.size.height * 1.5)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .blur(radius: 60)
                        .drawingGroup()
                        .animation(.linear(duration: 40).repeatForever(autoreverses: false), value: animateIn)
                    }
                }
                .ignoresSafeArea()

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
                                DailyAnalyticsInsightView(summaries: viewModel?.summaries ?? [], user: user, period: globalPeriod)
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
        .background(Color.white.opacity(0.8))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
    }
}

// MARK: - Typewriter AI Text
struct AITypewriterCard: View {
    let score: Int
    let period: AnalyticsPeriod
    
    @State private var displayedText: String = ""
    @State private var currentIndex: String.Index?
    
    private var fullText: String {
        if score >= 90 {
            return "Your metabolic synergy is absolutely flawless. You are consistently hitting calorie goals while maintaining perfect hydration and macro balance. Maintain this protocol."
        } else if score >= 70 {
            return "You are on a strong path. Your macros are decent, but there's room for optimization in your hydration or caloric adherence. Keep pushing."
        } else {
            return String(localized: "Your protocol requires recalibration. Focus on hitting your daily targets more consistently. Start by prioritizing protein and drinking at least 2 liters of water.")
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.themePink)
                    .symbolEffect(.pulse)
                Text("AI Synthesis")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
            }
            
            Text(displayedText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.95))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 80, alignment: .topLeading)
        }
        .divineCardStyle()
        .onAppear {
            startTypewriter()
        }
        .onChange(of: period) { _, _ in
            startTypewriter()
        }
    }
    
    private func startTypewriter() {
        displayedText = ""
        currentIndex = fullText.startIndex
        
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            guard let idx = currentIndex, idx < fullText.endIndex else {
                timer.invalidate()
                return
            }
            
            displayedText.append(fullText[idx])
            currentIndex = fullText.index(after: idx)
            
            if displayedText.count % 4 == 0 {
                // Removed haptic feedback
            }
        }
    }
}

// MARK: - Daily Insight
struct DailyAnalyticsInsightView: View {
    let summaries: [DailySummary]
    let user: User
    let period: AnalyticsPeriod
    @State private var animateIn = false

    @State private var selectedMacroForTop: AnalyticsMacro? = nil

    private var todaySummary: DailySummary? {
        let calendar = Calendar.current
        return summaries.first(where: { calendar.isDateInToday($0.date) })
    }

    let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        VStack(spacing: 24) {
            
            AITypewriterCard(score: calculateScore(), period: period)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)

            FitnessRingsCard(summary: todaySummary, user: user) { macro in
                selectedMacroForTop = macro
            }
            .opacity(animateIn ? 1 : 0)
            .offset(y: animateIn ? 0 : 30)

            MealDistributionGridCard(summary: todaySummary)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)
            
            AIHydrationCard(summary: todaySummary)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                animateIn = true
            }
        }
        .sheet(item: $selectedMacroForTop) { macro in
            TopSourcesSheetView(macro: macro, summary: todaySummary)
                .presentationDetents([.height(400)])
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

// MARK: - Daily Grid Cards
struct MealDistributionGridCard: View {
    let summary: DailySummary?
    let meals = [
        ("Breakfast", Color.themeYellow),
        ("Lunch", Color.green),
        ("Dinner", Color.themePink),
        ("Snack", Color.themeOrange)
    ]

    var body: some View {
        let totalCals = summary?.totalFoodCalories ?? 0

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.title2)
                    .foregroundColor(.themeOrange)
                Spacer()
            }
            Text("Distribution")
                .font(.headline)

            if totalCals == 0 {
                Text("No data").font(.caption.bold()).foregroundColor(.primary.opacity(0.7))
            } else {
                // Horizontal Bar Chart
                GeometryReader { geo in
                    HStack(spacing: 4) {
                        ForEach(meals, id: \.0) { meal in
                            let cals = summary?.meals?.first(where: { $0.title.hasPrefix(meal.0.prefix(5)) })?.totalCalories ?? 0
                            if cals > 0 {
                                let ratio = Double(cals) / Double(totalCals)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(meal.1)
                                    .frame(width: max(0, geo.size.width * CGFloat(ratio) - 4))
                            }
                        }
                    }
                }
                .frame(height: 12)
                .padding(.bottom, 8)

                VStack(spacing: 8) {
                    ForEach(meals, id: \.0) { meal in
                        let cals = summary?.meals?.first(where: { $0.title.hasPrefix(meal.0.prefix(5)) })?.totalCalories ?? 0
                        if cals > 0 {
                            HStack {
                                Circle().fill(meal.1).frame(width: 8, height: 8)
                                Text(meal.0).font(.caption.bold()).lineLimit(1)
                                Spacer()
                                Text("\(Int((Double(cals)/Double(totalCals))*100))%")
                                    .font(.caption2.bold())
                                    .foregroundColor(.primary.opacity(0.8))
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .divineCardStyle()
    }
}

struct WaveShape: Shape {
    var progress: CGFloat
    var waveHeight: CGFloat
    var phase: CGFloat
    
    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let progressHeight = height * (1.0 - progress)
        
        path.move(to: CGPoint(x: 0, y: progressHeight))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin(relativeX * 2 * .pi + phase)
            let y = progressHeight + sine * waveHeight
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        
        return path
    }
}

struct BeakerOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.35, y: 0))
        path.addLine(to: CGPoint(x: w * 0.65, y: 0))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.2))
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.85))
        path.addQuadCurve(to: CGPoint(x: w * 0.8, y: h), control: CGPoint(x: w * 0.9, y: h))
        path.addLine(to: CGPoint(x: w * 0.2, y: h))
        path.addQuadCurve(to: CGPoint(x: w * 0.1, y: h * 0.85), control: CGPoint(x: w * 0.1, y: h))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.2))
        path.closeSubpath()
        return path
    }
}

struct BeautifulBeakerView: View {
    var progress: Double
    
    @State private var phase: CGFloat = 0.0
    @State private var bubbleOffsets: [CGSize] = (0..<6).map { _ in
        CGSize(width: CGFloat.random(in: -15...15), height: CGFloat.random(in: 40...80))
    }
    
    var body: some View {
        ZStack {
            BeakerOutline()
                .fill(Color.cyan.opacity(0.1))
                .frame(width: 80, height: 110)
            
            WaveShape(progress: CGFloat(progress), waveHeight: 4, phase: phase)
                .fill(LinearGradient(colors: [.cyan.opacity(0.8), .drinkWater], startPoint: .top, endPoint: .bottom))
                .frame(width: 80, height: 110)
                .clipShape(BeakerOutline())
            
            if progress > 0.05 {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: CGFloat.random(in: 3...6), height: CGFloat.random(in: 3...6))
                        .offset(x: bubbleOffsets[i].width, y: bubbleOffsets[i].height)
                        .onAppear {
                            animateBubble(index: i)
                        }
                }
                .clipShape(BeakerOutline())
            }
            
            VStack(alignment: .trailing, spacing: 14) {
                ForEach(0..<4) { j in
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: j == 0 ? 12 : 8, height: 2)
                    }
                }
            }
            .frame(width: 80, height: 110)
            .padding(.trailing, 10)
            .allowsHitTesting(false)
            
            BeakerOutline()
                .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3)
                .frame(width: 80, height: 110)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
    }
    
    private func animateBubble(index: Int) {
        let randomDelay = Double.random(in: 0...1.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) {
            withAnimation(.linear(duration: Double.random(in: 2.0...3.5)).repeatForever(autoreverses: false)) {
                bubbleOffsets[index].height = -50
                bubbleOffsets[index].width = CGFloat.random(in: -15...15)
            }
        }
    }
}

struct AIHydrationCard: View {
    let summary: DailySummary?
    @State private var animProgress: Double = 0
    
    var body: some View {
        let liters = summary?.totalHydrationLiters ?? 0
        let goal = 2.5
        let progress = min(liters / goal, 1.0)
        
        HStack(spacing: 20) {
            BeautifulBeakerView(progress: animProgress)
                .frame(width: 80, height: 110)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.cyan)
                    Text("Hydration")
                        .font(.headline)
                    Spacer()
                    Text("\(String(format: "%.1f", liters)) / \(String(format: "%.1f", goal)) L")
                        .font(.subheadline.bold())
                        .foregroundColor(.cyan)
                }
                
                Text("Why It Matters")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary.opacity(0.8))
                    .textCase(.uppercase)
                
                Text("Water boosts metabolism, supports muscle function, aids digestion, and helps regulate appetite. Proper hydration is critical for nutrient absorption and optimal energy levels.")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
            }
        }
        .padding(20)
        .divineCardStyle()
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animProgress = progress
            }
        }
        .onChange(of: liters) { _, nv in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animProgress = min(nv / goal, 1.0)
            }
        }
    }
}


// MARK: - Fitness Rings Card
struct FitnessRingsCard: View {
    let summary: DailySummary?
    let user: User
    var onMacroTap: (AnalyticsMacro) -> Void

    var body: some View {
        let tc = user.targetCarbs > 0 ? user.targetCarbs : ((Double(user.dailyCaloriesGoal) * 0.4) / 4.0)
        let tf = user.targetFats > 0 ? user.targetFats : ((Double(user.dailyCaloriesGoal) * 0.3) / 9.0)
        let tp = user.targetProtein > 0 ? user.targetProtein : ((Double(user.dailyCaloriesGoal) * 0.3) / 4.0)
        let fallbackC = tc > 0 ? tc : 250.0
        let fallbackF = tf > 0 ? tf : 70.0
        let fallbackP = tp > 0 ? tp : 150.0

        let c = summary?.totalCarbs ?? 0; let targetC = fallbackC
        let f = summary?.totalFats ?? 0;  let targetF = fallbackF
        let p = summary?.totalProtein ?? 0; let targetP = fallbackP

        VStack(spacing: 24) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Macros").font(.title3.bold())
                    Text("Tap a nutrient to see top sources").font(.caption.bold()).foregroundColor(.primary.opacity(0.85))
                }
                Spacer()
                Image(systemName: "chart.pie.fill").foregroundColor(.primary.opacity(0.55))
            }

            HStack(spacing: 30) {
                ZStack {
                    RingView(progress: p/targetP, color: .themePeach, radius: 130, width: 16)
                    RingView(progress: f/targetF, color: .themeYellow, radius: 94, width: 16)
                    RingView(progress: c/targetC, color: .drinkWater, radius: 58, width: 16)
                }
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 16) {
                    Button(action: { onMacroTap(.protein) }) {
                        LegendRow(title: String(localized: "Protein"), current: p, target: targetP, color: .themePeach)
                    }.buttonStyle(PlainButtonStyle())
                    Button(action: { onMacroTap(.fat) }) {
                        LegendRow(title: String(localized: "Fats"), current: f, target: targetF, color: .themeYellow)
                    }.buttonStyle(PlainButtonStyle())

                    Button(action: { onMacroTap(.carbs) }) {
                        LegendRow(title: String(localized: "Carbs"), current: c, target: targetC, color: .drinkWater)
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
                    Text("/ \(Int(target))g").font(.caption.bold()).foregroundColor(.primary.opacity(0.85))
                }
                .padding(.leading, 14)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(color.opacity(0.75))
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Trends Insight
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
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)

            DivineMacrosChart(summaries: summaries, period: period)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)

            ConsistencyHeatmapCard(summaries: summaries, user: user)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 30)
                
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
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
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
                    .foregroundStyle(LinearGradient(colors: [Color.themePink.opacity(0.4), Color.clear], startPoint: .top, endPoint: .bottom))
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
            .chartYAxis(.hidden)
            .frame(height: 220)
        }
        .divineCardStyle()
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
        let maxDailySum = chartData.reduce(into: [Date: Double]()) { dict, item in
            dict[item.date, default: 0] += item.value
        }.values.max() ?? 0
        return max(200.0, maxDailySum * 1.2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey("Macros Balance")).font(.title3.bold())

            Chart {
                ForEach(chartData) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Grams", item.value),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(by: .value("Type", item.type))
                    .cornerRadius(6)
                }
            }
            .chartForegroundStyleScale([
                "Carbs": Color.drinkWater.gradient,
                "Fats": Color.themeYellow.gradient,
                "Protein": Color.themePeach.gradient
            ])
            .chartLegend(.hidden)
            .chartYScale(domain: 0...maxGrams)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
                    if let date = value.as(Date.self) { AxisValueLabel(format: .dateTime.weekday(.narrow)).font(.caption2.bold()).foregroundStyle(Color.primary.opacity(0.75)) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.25))
                    if let val = value.as(Double.self) {
                        AxisValueLabel("\(Int(val))g").font(.caption2.bold()).foregroundStyle(Color.primary.opacity(0.75))
                    }
                }
            }
            .frame(height: 200)

            HStack(spacing: 20) {
                ChartLegendItem(color: .themePeach, text: String(localized: "Protein"))
                ChartLegendItem(color: .themeYellow, text: String(localized: "Fats"))
                ChartLegendItem(color: .drinkWater, text: String(localized: "Carbs"))
            }
        }
        .divineCardStyle()
    }
}

struct ChartLegendItem: View {
    let color: Color; let text: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption.bold()).foregroundColor(.primary.opacity(0.85))
        }
    }
}

// MARK: - Interactive Water Chart
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
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .foregroundStyle(Color.cyan.opacity(0.8))
                    .annotation(position: .top, alignment: .leading) {
                        Text(LocalizedStringKey("GOAL")).font(.system(size: 10, weight: .black)).foregroundColor(.cyan)
                    }

                ForEach(chartData, id: \.date) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Liters", point.liters),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(Color.cyan.gradient)
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
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(Color.gray.opacity(0.25))
                    if let val = value.as(Double.self), val >= 0 {
                        AxisValueLabel("\(Int(val))L").font(.caption2.bold()).foregroundStyle(Color.primary.opacity(0.75))
                    }
                }
            }
            .frame(height: 200)
        }
        .divineCardStyle()
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

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { date in
                        let level = completionLevel(for: date)
                        let color = colorForLevel(level)

                        VStack(spacing: 4) {
                            Text(Calendar.current.component(.day, from: date).description).font(.system(size: 10, weight: .bold)).foregroundColor(.primary.opacity(0.8))
                            RoundedRectangle(cornerRadius: 6).fill(color.gradient).frame(width: 18, height: 36).shadow(color: level == 3 ? .green.opacity(0.4) : .clear, radius: 4, y: 2)
                        }
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
        .divineCardStyle()
    }
}

struct LegendDot: View {
    let color: Color; let text: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption.bold()).foregroundColor(.primary.opacity(0.75))
        }
    }
}

struct TopSourcesSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let macro: AnalyticsMacro
    let summary: DailySummary?

    private var topFoods: [FoodItem] {
        guard let summary = summary else { return [] }
        let allFoods = (summary.meals ?? []).flatMap { $0.foodItems ?? [] }
        switch macro {
        case .protein: return Array(allFoods.filter { $0.protein > 0 }.sorted { $0.protein > $1.protein }.prefix(3))
        case .fat: return Array(allFoods.filter { $0.fats > 0 }.sorted { $0.fats > $1.fats }.prefix(3))
        case .carbs: return Array(allFoods.filter { $0.carbs > 0 }.sorted { $0.carbs > $1.carbs }.prefix(3))
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(String(localized: "Top \(macro.rawValue) Sources"))
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .padding(.top, 24)

            if topFoods.isEmpty {
                Spacer()
                Text("No foods logged yet.").font(.subheadline).foregroundColor(.primary.opacity(0.75))
                Spacer()
            } else {
                VStack(spacing: 16) {
                    ForEach(topFoods) { food in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(food.name).font(.headline)
                                Text("\(Int(food.weight))g").font(.caption.bold()).foregroundColor(.primary.opacity(0.75))
                            }
                            Spacer()
                            Text("\(val(for: food))g").font(.title3.bold()).foregroundColor(macro.color)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 24)
                Spacer()
            }
        }
    }

    private func val(for food: FoodItem) -> Int {
        switch macro {
        case .protein: return Int(food.protein)
        case .fat: return Int(food.fats)
        case .carbs: return Int(food.carbs)
        }
    }
}
