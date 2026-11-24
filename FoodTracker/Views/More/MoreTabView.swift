import SwiftUI
import SwiftData
import UserNotifications

// MARK: - AI Coach Mega-Hub (Apple HIG HUD Standard Single-Page Scroll Experience)

enum CoachHubCopy {
    static let insightSubtitle = "Your proactive nutritionist"
    static let dashboardSubtitle = "Your proactive nutritionist"
}

struct MoreTabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(DIContainer.self) private var di
    @Query private var users: [User]
    @Query(sort: \WeightLog.date, order: .forward) private var weightLogs: [WeightLog]
    @AppStorage("useMetricSystem") private var useMetricSystem = true

    @State private var viewModel: AICoachViewModel?
    @State private var selectedTipIndex = 0
    @State private var showAIConsentSheet = false
    @State private var pendingConsentedAction: (() -> Void)? = nil
    @State private var showAddWeightSheet = false
    @State private var showSetGoalSheet = false
    @FocusState private var isFridgeSearchFocused: Bool

    private var user: User? { users.first }
    private var currentWeight: Double { weightLogs.last?.weight ?? user?.weight ?? 0.0 }
    private var targetWeight: Double? { user?.targetWeight }
    
    private var todaySummary: DailySummary {
        let start = Calendar.current.startOfDay(for: Date())
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else {
            return DailySummary(date: start)
        }
        var descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        descriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        } else {
            return DailySummary(date: start)
        }
    }

    private var moodAccentColor: Color {
        guard let viewModel = viewModel else { return Color(red: 0.65, green: 0.55, blue: 0.98) }
        switch viewModel.verdictMood.lowercased() {
        case "perfect": return Color(red: 0.10, green: 0.72, blue: 0.50)
        case "danger": return Color(red: 0.95, green: 0.35, blue: 0.35)
        case "warning": return Color(red: 0.98, green: 0.75, blue: 0.20)
        default: return Color(red: 0.65, green: 0.55, blue: 0.98)
        }
    }

    private let quickPrompts: [(title: String, prompt: String)] = [
        ("Fix my macros 📊", "Can you analyze my macros today and give me specific recommendations to balance protein, carbs and fats?"),
        ("Pre-workout fuel ⚡️", "What is an ideal meal or snack to eat before my workout based on my remaining calories and macros?"),
        ("High-protein snack 🥑", "Suggest 3 quick, high-protein snacks that will help me hit my daily protein target without exceeding fats."),
        ("Hydration check 💧", "How does my current water intake affect my metabolic rate and workout recovery?"),
        ("Late night cravings 🌙", "I have late night cravings. What healthy low-calorie options won't spike my insulin or ruin my sleep?"),
        ("Metabolism biohack 🧬", "What actionable biohacks can I apply today to improve my nutrient absorption and metabolic rate?")
    ]

    private let tips: [BioHackingTip] = [
        BioHackingTip(
            title: String(localized: "Iron Synergy"),
            text: String(localized: "Pair iron-rich foods (spinach, lentils) with Vitamin C (citrus, peppers) to increase iron absorption by up to 300%."),
            icon: "leaf.fill",
            category: String(localized: "🧬 NUTRIENT SYNERGY"),
            gradientColors: [.green, .mint]
        ),
        BioHackingTip(
            title: String(localized: "Protein Pacing"),
            text: String(localized: "Distribute your protein intake in 30-40g portions every 3-4 hours to keep muscle protein synthesis optimized."),
            icon: "flame.fill",
            category: String(localized: "🔋 MUSCLE RECOVERY"),
            gradientColors: [.themePink, .themeOrange]
        ),
        BioHackingTip(
            title: String(localized: "Circadian Fasting"),
            text: String(localized: "Finish eating at least 3 hours before sleep. This lowers insulin levels and improves deep sleep recovery phases."),
            icon: "moon.stars.fill",
            category: String(localized: "🌙 SLEEP & DIGESTION"),
            gradientColors: [.purple, .indigo]
        ),
        BioHackingTip(
            title: String(localized: "Hydration Window"),
            text: String(localized: "Drink 500ml of water immediately upon waking to kickstart metabolism and offset overnight dehydration."),
            icon: "drop.fill",
            category: String(localized: "💧 CELLULAR HYDRATION"),
            gradientColors: [.cyan, .blue]
        ),
        BioHackingTip(
            title: String(localized: "Sodium Balance"),
            text: String(localized: "Feeling bloated? Increase potassium intake (avocados, bananas) to assist kidneys in flushing out excess sodium."),
            icon: "sparkles",
            category: String(localized: "⚖️ FLUID BALANCE"),
            gradientColors: [.themeYellow, .themeOrange]
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic Ambient Aurora Mood Background
                DynamicAuroraBackgroundView()
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 1. Header Greeting
                        headerSection
                            .padding(.top, 4)

                        // 2. Proactive AI Coach Command Hero Card
                        aiCoachHeroCard
                            .padding(.horizontal)

                        // 3. Quick 1-Tap Question Carousel
                        quickPromptsCarousel

                        // 4. Daily AI Verdict & Tactical Action Cards
                        dailyVerdictAndActionsSection

                        // 5. Goals & Bio-Metabolic Engine HUD
                        goalsAndTargetsSection

                        // 6. Bio-Hacking & Micronutrient Intelligence
                        bioHackingTipsSection

                        // 7. Fridge-to-Recipe AI Assistant
                        fridgeToRecipeSection

                        // 8. Visual Transformation Progress (Before/After)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Visual Progress")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .padding(.horizontal)
                            
                            BeforeAfterView()
                                .padding(.horizontal)
                        }

                        // 9. Connected Ecosystem & Profile Access
                        connectedEcosystemSection

                        // 10. Cross-Promo Companion Banner
                        crossPromoBanner
                            .padding(.horizontal)

                        // 11. Disclaimer & App Info Footer
                        NutritionMethodologyDisclaimerView(
                            citations: [.dietaryGuidelines, .bmrAndTdee, .bmi],
                            compact: true
                        )
                        .padding(.horizontal, 20)

                        footerSection
                            .padding(.bottom, 32)
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: ProfileWrapperView()) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(themeManager.current.primaryAccent)
                    }
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = di.makeAICoachViewModel()
            }
        }
        .sheet(isPresented: Binding(get: { viewModel?.macroAdvice != nil }, set: { if !$0 { viewModel?.macroAdvice = nil } })) {
            if let advice = viewModel?.macroAdvice {
                MacroFixResultSheet(advice: advice, color: .themeYellow, selectedDate: Date())
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(32)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: Binding(get: { viewModel?.hydrationAdvice != nil }, set: { if !$0 { viewModel?.hydrationAdvice = nil } })) {
            if let advice = viewModel?.hydrationAdvice {
                HydrationFixResultSheet(advice: advice, color: .cyan) {
                    logQuickWaterGlass()
                }
                .presentationDetents([.height(320)])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAddWeightSheet) {
            AddWeightLogSheet(currentWeight: currentWeight)
                .presentationDetents([.fraction(0.68), .large])
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSetGoalSheet) {
            if let u = user {
                SetGoalSheet(user: u)
                    .presentationDetents([.fraction(0.8)])
                    .presentationCornerRadius(32)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showAIConsentSheet) {
            AIPhotoConsentSheet(
                onAllow: {
                    let action = pendingConsentedAction
                    pendingConsentedAction = nil
                    action?()
                },
                onDecline: {
                    pendingConsentedAction = nil
                }
            )
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(user?.name ?? "Champion")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(themeManager.current.primaryGradient)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return String(localized: "Good morning,")
        case 12..<17: return String(localized: "Good afternoon,")
        case 17..<22: return String(localized: "Good evening,")
        default:      return String(localized: "Good night,")
        }
    }

    // MARK: - Proactive AI Coach Hero Card
    private var aiCoachHeroCard: some View {
        let summary = todaySummary
        let cals = summary.totalCalories
        let goal = user?.dailyCaloriesGoal ?? 2000
        let protein = summary.totalProtein
        let proteinGoal = user?.targetProtein ?? 0
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.65, green: 0.55, blue: 0.95).opacity(0.18))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.65, green: 0.55, blue: 0.95))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Daily Nutrition Insight"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    
                    Text(CoachHubCopy.insightSubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
            }
            
            // Micro Stats Chips
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(cals > goal ? Color.red : Color(red: 0.16, green: 0.72, blue: 0.50))
                        .frame(width: 6, height: 6)
                    Text("\(cals) / \(goal) kcal")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.16, green: 0.72, blue: 0.50))
                        .frame(width: 6, height: 6)
                    Text("\(Int(protein)) / \(Int(proteinGoal))g Protein")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                
                Spacer()
            }
            
            // 1-Tap Direct Chat Navigation Link
            NavigationLink(destination: AICoachChatView(
                userGoal: user?.dailyCaloriesGoal ?? 2000,
                consumed: summary.totalCalories,
                activeDiet: user?.activeDietPlan?.name ?? String(localized: "Balanced"),
                consumedProtein: summary.totalProtein,
                targetProtein: user?.targetProtein ?? 0,
                consumedFats: summary.totalFats,
                targetFats: user?.targetFats ?? 0,
                consumedCarbs: summary.totalCarbs,
                targetCarbs: user?.targetCarbs ?? 0,
                hydrationLiters: summary.totalPureWaterLiters,
                activeCaloriesBurned: summary.activeCaloriesBurned
            )) {
                HStack {
                    Image(systemName: "message.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(String(localized: "Consult with AI Coach"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeManager.current.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(HUDSpringScaleButtonStyle(reduceMotion: reduceMotion))
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(themeManager.current.primaryAccent.opacity(0.22), lineWidth: 1.2)
                )
                .shadow(color: themeManager.current.primaryAccent.opacity(0.08), radius: 12, y: 4)
        }
    }

    // MARK: - Quick Prompts Carousel
    private var quickPromptsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPrompts, id: \.title) { item in
                    NavigationLink(destination: AICoachChatView(
                        userGoal: user?.dailyCaloriesGoal ?? 2000,
                        consumed: todaySummary.totalCalories,
                        activeDiet: user?.activeDietPlan?.name ?? String(localized: "Balanced"),
                        initialContext: item.prompt,
                        consumedProtein: todaySummary.totalProtein,
                        targetProtein: user?.targetProtein ?? 0,
                        consumedFats: todaySummary.totalFats,
                        targetFats: user?.targetFats ?? 0,
                        consumedCarbs: todaySummary.totalCarbs,
                        targetCarbs: user?.targetCarbs ?? 0,
                        hydrationLiters: todaySummary.totalPureWaterLiters,
                        activeCaloriesBurned: todaySummary.activeCaloriesBurned
                    )) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(Color.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .buttonStyle(HUDSpringScaleButtonStyle(reduceMotion: reduceMotion))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Daily Verdict & Actions Section
    private var dailyVerdictAndActionsSection: some View {
        VStack(spacing: 16) {
            if let viewModel = viewModel {
                DailyVerdictGlassCard(
                    title: viewModel.verdictTitle,
                    message: viewModel.verdictMessage,
                    moodColor: moodAccentColor,
                    isLoading: viewModel.isAnalyzing,
                    hasAnalyzed: viewModel.hasAnalyzedToday,
                    onAnalyze: {
                        guard let u = user else { return }
                        performWithAIConsent { viewModel.runDailyAnalysis(currentSummary: todaySummary, currentUser: u) }
                    }
                )
            }

            HStack(spacing: 14) {
                // Fix Macros Action Card
                AIFixCard(
                    title: "Fix Macros",
                    icon: "chart.pie.fill",
                    color: .themeYellow,
                    isLoading: viewModel?.isFixingMacros ?? false,
                    action: {
                        guard let u = user else { return }
                        performWithAIConsent { viewModel?.analyzeMacros(currentSummary: todaySummary, currentUser: u) }
                    }
                )

                // Hydration Quick Action Card
                AIFixCard(
                    title: "Hydration",
                    icon: "drop.fill",
                    color: .cyan,
                    isLoading: viewModel?.isFixingHydration ?? false,
                    action: {
                        performWithAIConsent { viewModel?.analyzeHydration(currentSummary: todaySummary) }
                    }
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Goals & Targets Section
    private var goalsAndTargetsSection: some View {
        let summary = todaySummary
        let goal = user?.dailyCaloriesGoal ?? 2000
        let cals = summary.totalCalories
        let calProgress = goal > 0 ? min(Double(cals) / Double(goal), 1.0) : 0.0
        
        let pGoal = user?.targetProtein ?? 140
        let pCurrent = summary.totalProtein
        let pProgress = pGoal > 0 ? min(pCurrent / pGoal, 1.0) : 0.0
        
        let cGoal = user?.targetCarbs ?? 200
        let cCurrent = summary.totalCarbs
        let cProgress = cGoal > 0 ? min(cCurrent / cGoal, 1.0) : 0.0
        
        let fGoal = user?.targetFats ?? 65
        let fCurrent = summary.totalFats
        let fProgress = fGoal > 0 ? min(fCurrent / fGoal, 1.0) : 0.0

        let weightProgress = GoalsTabView.computeProgressPercentage(
            goalType: user?.weightGoalType ?? "maintain",
            startWeight: weightLogs.first?.weight ?? currentWeight,
            currentWeight: currentWeight,
            targetWeight: targetWeight ?? currentWeight
        )

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.25))
                    Text("Targets & Bio-Metabolic Goals")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                NavigationLink(destination: GoalsTabView()) {
                    HStack(spacing: 3) {
                        Text("Full Goals")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(themeManager.current.primaryAccent)
                }
            }
            .padding(.horizontal)
            
            // Weight Target Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WEIGHT TARGET")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(0.8)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", NutritionMath.displayWeight(currentWeight, useMetric: useMetricSystem)))
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .monospacedDigit()
                            Text(NutritionMath.weightUnit(useMetric: useMetricSystem))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            
                            if let target = targetWeight {
                                Text("→ \(String(format: "%.1f", NutritionMath.displayWeight(target, useMetric: useMetricSystem))) \(NutritionMath.weightUnit(useMetric: useMetricSystem))")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                                    .padding(.leading, 6)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        showAddWeightSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Log Weight")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                    }
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(LinearGradient(colors: [Color.themePink, Color.themeOrange], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, geo.size.width * CGFloat(weightProgress)), height: 8)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("\(Int(weightProgress * 100))% achieved")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        showSetGoalSheet = true
                    }) {
                        Text("Tune Target")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(themeManager.current.primaryAccent)
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal)
            
            // Macro Gauges Card
            VStack(alignment: .leading, spacing: 14) {
                Text("TODAY'S MACRO SPLIT")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundColor(.secondary)
                
                MacroProgressRow(
                    label: "Calories",
                    current: "\(cals)",
                    target: "\(goal) kcal",
                    progress: calProgress,
                    color: Color.themeOrange
                )
                
                MacroProgressRow(
                    label: "Protein",
                    current: "\(Int(pCurrent))g",
                    target: "\(Int(pGoal))g",
                    progress: pProgress,
                    color: Color(red: 0.10, green: 0.72, blue: 0.50)
                )
                
                MacroProgressRow(
                    label: "Carbs",
                    current: "\(Int(cCurrent))g",
                    target: "\(Int(cGoal))g",
                    progress: cProgress,
                    color: Color(red: 0.35, green: 0.55, blue: 0.95)
                )
                
                MacroProgressRow(
                    label: "Fats",
                    current: "\(Int(fCurrent))g",
                    target: "\(Int(fGoal))g",
                    progress: fProgress,
                    color: Color(red: 0.98, green: 0.75, blue: 0.20)
                )
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }

    // MARK: - Bio-Hacking Tips Section
    private var bioHackingTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.98))
                        .font(.system(size: 15, weight: .bold))
                    Text("Bio-hacking Tips")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                
                Spacer()
                
                Text("Swipe")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            
            TabView(selection: $selectedTipIndex) {
                ForEach(0..<tips.count, id: \.self) { index in
                    let tip = tips[index]
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(tip.category)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(tip.gradientColors[0])
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(tip.gradientColors[0].opacity(0.12))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(tip.gradientColors[0].opacity(0.14))
                                    .frame(width: 44, height: 44)
                                Image(systemName: tip.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(tip.gradientColors[0])
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tip.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(tip.text)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer()
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 140)
            
            // Custom page indicator
            HStack(spacing: 6) {
                Spacer()
                ForEach(0..<tips.count, id: \.self) { index in
                    Capsule()
                        .fill(selectedTipIndex == index ? tips[index].gradientColors[0] : Color.secondary.opacity(0.2))
                        .frame(width: selectedTipIndex == index ? 16 : 6, height: 5)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTipIndex)
                }
                Spacer()
            }
            .padding(.top, -2)
        }
    }

    // MARK: - Fridge to Recipe Section
    private var fridgeToRecipeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "refrigerator.fill")
                    .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                    .font(.system(size: 15, weight: .bold))
                Text("Fridge to Recipe")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }
            .padding(.horizontal)

            Text("Tell me what ingredients you have, and I'll generate a recipe matching your remaining calories.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .foregroundColor(isFridgeSearchFocused ? Color.primary : .secondary)
                        .font(.system(size: 15))
                    
                    TextField("E.g. Eggs, chicken, spinach...", text: Binding(get: { viewModel?.fridgeInput ?? "" }, set: { viewModel?.fridgeInput = $0 }))
                        .focused($isFridgeSearchFocused)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button(action: {
                    guard let u = user else { return }
                    performWithAIConsent { viewModel?.generateSmartRecipe(currentSummary: todaySummary, currentUser: u) }
                }) {
                    if viewModel?.isGeneratingRecipe == true {
                        ProgressView().tint(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.primary.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(UIColor.systemBackground))
                            .frame(width: 44, height: 44)
                            .background(Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .disabled((viewModel?.fridgeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) || (viewModel?.isGeneratingRecipe ?? true))
            }
            .padding(.horizontal)

            if let recipe = viewModel?.generatedRecipe {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().padding(.vertical, 2)
                    
                    HStack {
                        Text("AI RECIPE SUGGESTION")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(red: 0.10, green: 0.72, blue: 0.50).opacity(0.12))
                            .clipShape(Capsule())
                        Spacer()
                    }
                    
                    Text(recipe.name)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(recipe.info)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)

                    HStack(spacing: 8) {
                        Text("\(recipe.calories) kcal")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.themeOrange)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("\(Int(recipe.protein))g Protein")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                    }
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color(red: 0.10, green: 0.72, blue: 0.50).opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Connected Ecosystem Section
    private var connectedEcosystemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                    Text("Connected Ecosystem")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                NavigationLink(destination: ProfileWrapperView()) {
                    HStack(spacing: 3) {
                        Text("Profile & Settings")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(themeManager.current.primaryAccent)
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 12) {
                // Apple HealthKit Pill
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.98, green: 0.25, blue: 0.35).opacity(0.14))
                            .frame(width: 36, height: 36)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 0.98, green: 0.25, blue: 0.35))
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple Health")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(user?.isHealthKitEnabled == true ? "Auto Syncing" : "Connected")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
                
                // Units Switcher
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    useMetricSystem.toggle()
                }) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.14))
                                .frame(width: 36, height: 36)
                            Image(systemName: "scalemass.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Units")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text(useMetricSystem ? "Metric (kg, cm)" : "Imperial (lbs, in)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Cross Promo
    private var crossPromoBanner: some View {
        Button(action: {
            TrackingManager.shared.track(.crossPromoTapped(app: "workout_tracker"))
            CrossAppLinkResolver.openWorkoutTracker()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.primary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Workout Tracker")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Track sets, workouts & active burn")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 0)
                
                HStack(spacing: 4) {
                    Text("Open")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(HUDSpringScaleButtonStyle(reduceMotion: reduceMotion))
    }

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("FoodTracker")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(.caption2)
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Helpers & Actions
    private func performWithAIConsent(_ action: @escaping () -> Void) {
        if AIPhotoConsentManager.shared.hasConsented {
            action()
        } else {
            pendingConsentedAction = action
            showAIConsentSheet = true
        }
    }

    private func logQuickWaterGlass() {
        let selectedDate = Date()
        let result = WorkoutSyncManager.shared.logWaterAndReconcile(
            volumeMl: 250,
            for: selectedDate,
            in: modelContext
        )
        WidgetReloader.reloadAll()
        HapticManager.shared.notification(type: .success)

        if user?.isHealthKitEnabled == true {
            let container = modelContext.container
            let water = result.beverage
            let deletedSamples = result.deletedHealthKitSamples
            Task { @MainActor in
                for sample in deletedSamples {
                    await HealthKitManager.shared.deleteWaterSample(
                        idString: sample.sampleID,
                        litersFallback: sample.volumeMl / 1000.0,
                        date: selectedDate
                    )
                }
                if let uuid = await HealthKitManager.shared.saveWater(liters: 0.25, date: Date()) {
                    water.healthKitSampleID = uuid.uuidString
                    try? container.mainContext.save()
                }
            }
        }
    }
}

// MARK: - Macro Progress Bar Helper
private struct MacroProgressRow: View {
    let label: String
    let current: String
    let target: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text("\(current) / \(target)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: max(6, geo.size.width * CGFloat(min(progress, 1.0))), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

private struct HUDSpringScaleButtonStyle: ButtonStyle {
    var reduceMotion: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1.0 : 0.96)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// Compatibility items for tests
enum MoreDestination: Hashable {
    case goals
    case aiCoach
    case profile
}

struct MoreItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let accessibilityId: String
    let destination: MoreDestination
}
