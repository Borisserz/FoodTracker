import SwiftUI
import SwiftData
import UserNotifications

struct AICoachDashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]

    @Environment(DIContainer.self) private var di
    @State private var viewModel: AICoachViewModel?
    @State private var bgPhase = 0.0
    @State private var selectedTipIndex = 0
    @State private var showAIConsentSheet = false
    @State private var pendingConsentedAction: (() -> Void)? = nil
    @FocusState private var isSearchFocused: Bool

    let selectedDate: Date

    init(selectedDate: Date) {
        self.selectedDate = selectedDate
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = #Predicate<DailySummary> { $0.date >= startOfDay && $0.date < endOfDay }
        self._summaries = Query(filter: predicate)
    }

    private var currentUser: User? { users.first }
    private var currentSummary: DailySummary {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        if let existing = summaries.first {
            return existing
        } else {
            return DailySummary(date: startOfDay)
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

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    ZStack {
                        Color(UIColor.systemBackground).ignoresSafeArea()

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 20) {

                                HStack(alignment: .center) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("AI Coach")
                                            .font(.system(size: 28, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                        
                                        Text("Proactive Nutrition Intelligence")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()

                                    NavigationLink(destination: AICoachChatView(
                                        userGoal: currentUser?.dailyCaloriesGoal ?? 2000,
                                        consumed: currentSummary.totalCalories,
                                        activeDiet: currentUser?.activeDietPlan?.name ?? String(localized: "Balanced"),
                                        consumedProtein: currentSummary.totalProtein,
                                        targetProtein: currentUser?.targetProtein ?? 0,
                                        consumedFats: currentSummary.totalFats,
                                        targetFats: currentUser?.targetFats ?? 0,
                                        consumedCarbs: currentSummary.totalCarbs,
                                        targetCarbs: currentUser?.targetCarbs ?? 0,
                                        hydrationLiters: currentSummary.totalPureWaterLiters,
                                        activeCaloriesBurned: currentSummary.activeCaloriesBurned
                                    )) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                                .font(.system(size: 13, weight: .semibold))
                                            Text("Chat")
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                        }
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(UIColor.secondarySystemGroupedBackground))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(BounceButtonStyle())
                                }
                                .padding(.horizontal)

                                DailyVerdictGlassCard(
                                    title: viewModel.verdictTitle,
                                    message: viewModel.verdictMessage,
                                    moodColor: moodAccentColor,
                                    isLoading: viewModel.isAnalyzing,
                                    hasAnalyzed: viewModel.hasAnalyzedToday,
                                    onAnalyze: {
                                        guard let u = currentUser else { return }
                                        performWithAIConsent { viewModel.runDailyAnalysis(currentSummary: currentSummary, currentUser: u) }
                                    }
                                )

                                HStack(spacing: 16) {
                                    AIFixCard(
                                        title: "Fix Macros",
                                        icon: "chart.pie.fill",
                                        color: .themeYellow,
                                        isLoading: viewModel.isFixingMacros,
                                        action: {
                                            guard let u = currentUser else { return }
                                            performWithAIConsent { viewModel.analyzeMacros(currentSummary: currentSummary, currentUser: u) }
                                        }
                                    )

                                    AIFixCard(
                                        title: "Hydration",
                                        icon: "drop.fill",
                                        color: .cyan,
                                        isLoading: viewModel.isFixingHydration,
                                        action: {
                                            performWithAIConsent { viewModel.analyzeHydration(currentSummary: currentSummary) }
                                        }
                                    )
                                }
                                .padding(.horizontal)

                                bioHackingTipsSection

                                fridgeToRecipeSection

                                NutritionMethodologyDisclaimerView(
                                    citations: [.dietaryGuidelines, .bmrAndTdee],
                                    compact: true
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 16)

                                ReportAIContentButton(surface: "ai_coach_dashboard")
                                    .padding(.top, 4)
                            }
                            .padding(.bottom, 120)
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .sheet(isPresented: Binding(get: { viewModel?.macroAdvice != nil }, set: { if !$0 { viewModel?.macroAdvice = nil } })) {
                if let advice = viewModel?.macroAdvice {
                    MacroFixResultSheet(advice: advice, color: .themeYellow, selectedDate: selectedDate)
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
            .onAppear {
                if viewModel == nil {
                    viewModel = di.makeAICoachViewModel()
                }
            }
            .onChange(of: selectedDate) { _, _ in
                viewModel?.resetDailyAnalysis()
            }
            .alert(
                "AI Coach",
                isPresented: Binding(
                    get: { viewModel?.errorMessage != nil },
                    set: { if !$0 { viewModel?.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel?.errorMessage = nil }
            } message: {
                Text(viewModel?.errorMessage ?? "")
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
    }

    private func performWithAIConsent(_ action: @escaping () -> Void) {
        if AIPhotoConsentManager.shared.hasConsented {
            action()
        } else {
            pendingConsentedAction = action
            showAIConsentSheet = true
        }
    }

    private func logQuickWaterGlass() {
        let logDate = Calendar.current.isDateInToday(selectedDate) ? Date() : selectedDate
        let result = WorkoutSyncManager.shared.logWaterAndReconcile(
            volumeMl: 250,
            for: selectedDate,
            in: context
        )
        WidgetReloader.reloadAll()
        HapticManager.shared.notification(type: .success)

        if currentUser?.isHealthKitEnabled == true {
            let container = context.container
            let water = result.beverage
            let deletedSamples = result.deletedHealthKitSamples
            let summaryDate = selectedDate
            Task { @MainActor in
                for sample in deletedSamples {
                    await HealthKitManager.shared.deleteWaterSample(
                        idString: sample.sampleID,
                        litersFallback: sample.volumeMl / 1000.0,
                        date: summaryDate
                    )
                }
                if let uuid = await HealthKitManager.shared.saveWater(liters: 0.25, date: logDate) {
                    water.healthKitSampleID = uuid.uuidString
                    try? container.mainContext.save()
                }
            }
        }
    }

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

    private var fridgeToRecipeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "refrigerator.fill")
                    .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                    .font(.system(size: 15, weight: .bold))
                Text("Fridge to Recipe")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
            }

            Text("Tell me what ingredients you have, and I'll generate a recipe matching your remaining calories.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .foregroundColor(isSearchFocused ? Color.primary : .secondary)
                        .font(.system(size: 15))
                    
                    TextField("E.g. Eggs, chicken, spinach...", text: Binding(get: { viewModel?.fridgeInput ?? "" }, set: { viewModel?.fridgeInput = $0 }))
                        .focused($isSearchFocused)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button(action: {
                    guard let u = currentUser else { return }
                    performWithAIConsent { viewModel?.generateSmartRecipe(currentSummary: currentSummary, currentUser: u) }
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
                        .lineSpacing(3)
                    
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("CALORIES")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("\(recipe.calories) kcal")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("PROTEIN")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("\(recipe.protein)g")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("COOKING")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("\(recipe.cookingTime) min")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(UIColor.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    Button(action: { saveGeneratedRecipe(recipe) }) {
                        Text("Save to My Recipes")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(Color(UIColor.systemBackground))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(BounceButtonStyle())
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func saveGeneratedRecipe(_ recipeDTO: AIRecipeDTO) {
        let directions = recipeDTO.info.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [recipeDTO.info]
        let micros = MicronutrientEstimator.estimate(
            name: recipeDTO.name,
            calories: recipeDTO.calories,
            protein: recipeDTO.protein,
            fat: recipeDTO.fats,
            carbs: recipeDTO.carbs,
            weight: 250.0
        )
        let food = FoodItem(
            name: recipeDTO.name,
            weight: 250,
            calories: recipeDTO.calories,
            protein: recipeDTO.protein,
            fats: recipeDTO.fats,
            carbs: recipeDTO.carbs,
            omega3: micros.omega3,
            calcium: micros.calcium,
            potassium: micros.potassium,
            magnesium: micros.magnesium,
            iron: micros.iron,
            vitaminC: micros.vitaminC,
            vitaminD: micros.vitaminD
        )
        let newRecipe = CustomRecipe(
            name: recipeDTO.name, info: recipeDTO.info,
            foodItems: [food],
            cookingTime: recipeDTO.cookingTime, difficulty: "Medium",
            directions: directions)
        context.insert(newRecipe); try? context.save()
        withAnimation { viewModel?.generatedRecipe = nil }; HapticManager.shared.impact(style: .light)
    }
}

// MARK: - Daily Verdict Card (Apple HIG HUD Standard)
struct DailyVerdictGlassCard: View {
    let title: String
    let message: String
    let moodColor: Color
    let isLoading: Bool
    let hasAnalyzed: Bool
    let onAnalyze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(hasAnalyzed ? moodColor : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                    Text(hasAnalyzed ? "DAILY VERDICT" : "NUTRITION STATUS")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(hasAnalyzed ? moodColor : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((hasAnalyzed ? moodColor : Color.secondary).opacity(0.10))
                .clipShape(Capsule())

                Spacer()
                if isLoading { ProgressView().tint(moodColor) }
            }

            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .contentTransition(.interpolate)

            FoodTypewriterTextView(fullText: message, isAnimating: !isLoading && hasAnalyzed)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))
                .lineSpacing(4)

            if !hasAnalyzed && !isLoading {
                Button(action: onAnalyze) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                        Text("Analyze Today's Nutrition")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Color.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.top, 4)
            }
        }
        .padding(18)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(hasAnalyzed ? moodColor.opacity(0.25) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

// MARK: - Tactical AI Action Card (Apple HIG HUD Bento)
struct AIFixCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isLoading { action() }
        }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color.opacity(0.14))
                            .frame(width: 38, height: 38)
                        Image(systemName: icon)
                            .foregroundColor(color)
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: color))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text(isLoading ? "Analyzing..." : "Auto-balance")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
}

struct MacroFixResultSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    let advice: MacroFixAdviceDTO
    let color: Color
    let selectedDate: Date

    @State private var loggedIndices: Set<Int> = []

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(y: -100)
            
            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(color)
                        Text("AI Coach Recommendation")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(color)
                            .textCase(.uppercase)
                    }

                    Text(advice.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text(advice.explanation)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                if !advice.suggestedSnacks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Perfect Matches for You:")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(Array(advice.suggestedSnacks.enumerated()), id: \.offset) { index, snack in
                                    let isLogged = loggedIndices.contains(index)
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(snack.name)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .lineLimit(2)
                                            .foregroundColor(.primary)

                                        HStack(spacing: 8) {
                                            Label("\(snack.calories) kcal", systemImage: "flame.fill")
                                                .foregroundColor(.themeOrange)
                                            Spacer()
                                            Text("\(snack.protein)g P")
                                                .bold()
                                                .foregroundColor(.themePeach)
                                        }
                                        .font(.system(size: 11, weight: .semibold))

                                        if snack.fats > 0 || snack.carbs > 0 {
                                            HStack(spacing: 10) {
                                                Text("F: \(snack.fats)g")
                                                    .foregroundColor(.orange)
                                                Text("C: \(snack.carbs)g")
                                                    .foregroundColor(.blue)
                                            }
                                            .font(.system(size: 10, weight: .semibold))
                                        }

                                        Spacer(minLength: 0)

                                        Button(action: {
                                            guard !isLogged else { return }
                                            logSuggestedSnack(snack, index: index)
                                        }) {
                                            HStack(spacing: 4) {
                                                Image(systemName: isLogged ? "checkmark.circle.fill" : "plus.circle.fill")
                                                Text(isLogged ? "Logged" : "Log Snack")
                                            }
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundColor(isLogged ? .green : .white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(isLogged ? Color.green.opacity(0.14) : Color.themeOrange)
                                            .cornerRadius(12)
                                        }
                                        .disabled(isLogged)
                                    }
                                    .padding(14)
                                    .frame(width: 215, height: 165)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [color.opacity(0.4), color.opacity(0.1)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 1.5
                                            )
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }

                Spacer()

                Button(action: { dismiss() }) {
                    Text("Got it")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(color == .themeYellow ? Color.black.opacity(0.85) : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(color)
                        .cornerRadius(20)
                        .shimmer()
                        .shadow(color: color.opacity(0.35), radius: 8, y: 4)
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private func logSuggestedSnack(_ snack: MacroFixAdviceDTO.SnackIdea, index: Int) {
        let logDate = Calendar.current.isDateInToday(selectedDate) ? Date() : selectedDate
        let summary = DailySummary.fetchOrCreate(for: selectedDate, in: context)
        let micros = MicronutrientEstimator.estimate(
            name: snack.name,
            calories: snack.calories,
            protein: Double(snack.protein),
            fat: Double(snack.fats),
            carbs: Double(snack.carbs),
            weight: snack.weight > 0 ? snack.weight : 100.0
        )
        let food = FoodItem(
            name: snack.name,
            weight: snack.weight,
            calories: snack.calories,
            protein: Double(snack.protein),
            fats: Double(snack.fats),
            carbs: Double(snack.carbs),
            omega3: micros.omega3,
            calcium: micros.calcium,
            potassium: micros.potassium,
            magnesium: micros.magnesium,
            iron: micros.iron,
            vitaminC: micros.vitaminC,
            vitaminD: micros.vitaminD
        )
        context.insert(food)

        if let existingSnack = (summary.meals ?? []).first(where: { DailySummary.canonicalMealSlot($0.title) == "Snack" }) {
            existingSnack.addFoodItem(food)
            existingSnack.date = logDate
        } else {
            let snackMeal = Meal(title: "Snack", date: logDate, foodItems: [food])
            context.insert(snackMeal)
            summary.addMeal(snackMeal)
        }

        try? context.save()
        WidgetReloader.reloadAll()
        AppReviewManager.shared.userDidLogMeal()
        HapticManager.shared.notification(type: .success)
        withAnimation(.spring()) {
            _ = loggedIndices.insert(index)
        }

        if users.first?.isHealthKitEnabled == true && snack.calories > 0 {
            let container = context.container
            Task { @MainActor in
                if let uuid = await HealthKitManager.shared.saveDietaryEnergy(calories: snack.calories, date: logDate) {
                    food.healthKitSampleID = uuid.uuidString
                    try? container.mainContext.save()
                }
            }
        }
    }
}

struct HydrationFixResultSheet: View {
    @Environment(\.dismiss) var dismiss
    let advice: HydrationAdviceDTO
    let color: Color
    var onDrinkNow: (() -> Void)? = nil
    @State private var reminderScheduled = false

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 200, height: 200)
                .blur(radius: 40)
                .offset(y: -50)
            
            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 76, height: 76)
                    Circle()
                        .stroke(color.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 88, height: 88)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 36))
                        .foregroundColor(color)
                }
                .padding(.top, 10)

                VStack(spacing: 8) {
                    Text(advice.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    Text(advice.message)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 32)

                    if advice.nextGlassTimeMinutes > 0 {
                        Button(action: scheduleHydrationReminder) {
                            Label(
                                reminderScheduled
                                    ? String(localized: "Reminder set for \(advice.nextGlassTimeMinutes) min")
                                    : String(localized: "Next glass in \(advice.nextGlassTimeMinutes) min • Tap to remind"),
                                systemImage: reminderScheduled ? "bell.badge.fill" : "clock.fill"
                            )
                            .font(.caption.bold())
                            .foregroundColor(reminderScheduled ? .green : color)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background((reminderScheduled ? Color.green : color).opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .disabled(reminderScheduled)
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text("Close")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(20)
                    }

                    Button(action: {
                        onDrinkNow?()
                        dismiss()
                    }) {
                        Text("Drink Now")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(color)
                            .cornerRadius(20)
                            .shimmer()
                            .shadow(color: color.opacity(0.4), radius: 8, y: 4)
                    }
                    .buttonStyle(BounceButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private func scheduleHydrationReminder() {
        let minutes = max(1, advice.nextGlassTimeMinutes)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Time to Hydrate 💧")
            content.body = String(localized: "Drink your next glass of water to hit today's hydration target.")
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(minutes * 60), repeats: false)
            let request = UNNotificationRequest(identifier: "ft_hydration_coach_reminder", content: content, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: ["ft_hydration_coach_reminder"])
            center.add(request) { error in
                if error == nil {
                    DispatchQueue.main.async {
                        HapticManager.shared.notification(type: .success)
                        withAnimation { reminderScheduled = true }
                    }
                }
            }
        }
    }
}

struct BioHackingTip: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let icon: String
    let category: String
    let gradientColors: [Color]
}

struct ShimmerEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.35), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + (phase * geo.size.width * 2))
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                            phase = 1.0
                        }
                    }
                }
                .mask(content)
            )
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(ShimmerEffect())
    }
}

