import SwiftUI
import SwiftData

struct AICoachDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]

    @Environment(DIContainer.self) private var di
    @State private var viewModel: AICoachViewModel?
    @State private var bgPhase = 0.0
    @State private var selectedTipIndex = 0
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

    private var moodColors: [Color] {
        guard let viewModel = viewModel else { return [.themePink, .themeOrange] }
        switch viewModel.verdictMood.lowercased() {
        case "perfect": return [.green, .mint]
        case "danger": return [.red, .themePink]
        case "warning": return [.orange, .themeYellow]
        default: return [.themePink, .themeOrange]
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel = viewModel {
                    ZStack {
                        Color.themeBg.ignoresSafeArea()

                        // Dynamic animated background blobs
                        ZStack {
                            Circle()
                                .fill(moodColors[0].opacity(0.18))
                                .frame(width: 350, height: 350)
                                .blur(radius: 90)
                                .offset(x: bgPhase == 0 ? -120 : -60, y: bgPhase == 0 ? -220 : -140)

                            Circle()
                                .fill(moodColors[1].opacity(0.18))
                                .frame(width: 400, height: 400)
                                .blur(radius: 95)
                                .offset(x: bgPhase == 0 ? 160 : 80, y: bgPhase == 0 ? 240 : 160)
                        }
                        .ignoresSafeArea()
                        .onAppear {
                            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                                bgPhase = 1.0
                            }
                        }

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 24) {

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("AI Coach")
                                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                                            .foregroundStyle(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                                        
                                        Text("Your proactive nutritionist")
                                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()

                                    NavigationLink(destination: AICoachChatView(
                                        userGoal: currentUser?.dailyCaloriesGoal ?? 2000,
                                        consumed: currentSummary.totalCalories,
                                        activeDiet: currentUser?.activeDietPlan?.name ?? String(localized: "Balanced")
                                    )) {
                                        ZStack {
                                            Circle()
                                                .stroke(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
                                                .scaleEffect((viewModel.isAnalyzing || viewModel.isGeneratingRecipe) ? 1.2 : (bgPhase == 0 ? 1.0 : 1.15))
                                                .opacity((viewModel.isAnalyzing || viewModel.isGeneratingRecipe) ? 0.8 : (bgPhase == 0 ? 0.6 : 0.0))
                                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: bgPhase)

                                            Circle()
                                                .fill(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .frame(width: 50, height: 50)
                                                .shadow(color: Color.themePink.opacity(0.35), radius: 10, x: 0, y: 5)
                                                .opacity(viewModel.isAnalyzing || viewModel.isGeneratingRecipe ? 0.5 : 1.0)
                                                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: viewModel.isAnalyzing || viewModel.isGeneratingRecipe)

                                            Image(systemName: "message.fill")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .padding(.horizontal)

                                DailyVerdictGlassCard(
                                    title: viewModel.verdictTitle,
                                    message: viewModel.verdictMessage,
                                    moodColor: moodColors[0],
                                    isLoading: viewModel.isAnalyzing,
                                    hasAnalyzed: viewModel.hasAnalyzedToday,
                                    onAnalyze: { if let u = currentUser { viewModel.runDailyAnalysis(currentSummary: currentSummary, currentUser: u) } }
                                )

                                HStack(spacing: 16) {
                                    AIFixCard(
                                        title: "Fix Macros",
                                        icon: "chart.pie.fill",
                                        color: .themeYellow,
                                        isLoading: viewModel.isFixingMacros,
                                        action: { if let u = currentUser { viewModel.analyzeMacros(currentSummary: currentSummary, currentUser: u) } }
                                    )

                                    AIFixCard(
                                        title: "Hydration",
                                        icon: "drop.fill",
                                        color: .cyan,
                                        isLoading: viewModel.isFixingHydration,
                                        action: { viewModel.analyzeHydration(currentSummary: currentSummary) }
                                    )
                                }
                                .padding(.horizontal)

                                bioHackingTipsSection

                                fridgeToRecipeSection

                                // МЕДИЦИНСКИЙ ДИСКЛЕЙМЕР (Guideline 1.4.1)
                                Text("FoodTracker AI provides general nutritional information. It is not a substitute for professional medical advice, diagnosis, or treatment.")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.secondary.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 28)
                                    .padding(.top, 16)
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
                    MacroFixResultSheet(advice: advice, color: .themeYellow)
                        .presentationDetents([.medium, .large])
                        .presentationCornerRadius(32)
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: Binding(get: { viewModel?.hydrationAdvice != nil }, set: { if !$0 { viewModel?.hydrationAdvice = nil } })) {
                if let advice = viewModel?.hydrationAdvice {
                    HydrationFixResultSheet(advice: advice, color: .cyan)
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
        }
    }

    private let tips: [BioHackingTip] = [
        BioHackingTip(
            title: "Iron Synergy",
            text: "Pair iron-rich foods (spinach, lentils) with Vitamin C (citrus, peppers) to increase iron absorption by up to 300%.",
            icon: "leaf.fill",
            category: "🧬 NUTRIENT SYNERGY",
            gradientColors: [.green, .mint]
        ),
        BioHackingTip(
            title: "Protein Pacing",
            text: "Distribute your protein intake in 30-40g portions every 3-4 hours to keep muscle protein synthesis optimized.",
            icon: "flame.fill",
            category: "🔋 MUSCLE RECOVERY",
            gradientColors: [.themePink, .themeOrange]
        ),
        BioHackingTip(
            title: "Circadian Fasting",
            text: "Finish eating at least 3 hours before sleep. This lowers insulin levels and improves deep sleep recovery phases.",
            icon: "moon.stars.fill",
            category: "🌙 SLEEP & DIGESTION",
            gradientColors: [.purple, .indigo]
        ),
        BioHackingTip(
            title: "Hydration Window",
            text: "Drink 500ml of water immediately upon waking to kickstart metabolism and offset overnight dehydration.",
            icon: "drop.fill",
            category: "💧 CELLULAR HYDRATION",
            gradientColors: [.cyan, .blue]
        ),
        BioHackingTip(
            title: "Sodium Balance",
            text: "Feeling bloated? Increase potassium intake (avocados, bananas) to assist kidneys in flushing out excess sodium.",
            icon: "sparkles",
            category: "⚖️ FLUID BALANCE",
            gradientColors: [.themeYellow, .themeOrange]
        )
    ]

    private var bioHackingTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle().fill(Color.purple.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: "lightbulb.fill").foregroundColor(.purple)
                }
                
                Text("Bio-hacking Tips")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                
                Spacer()
                
                Text("Swipe")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
            }
            .padding(.horizontal)
            
            TabView(selection: $selectedTipIndex) {
                ForEach(0..<tips.count, id: \.self) { index in
                    let tip = tips[index]
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(tip.category)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(LinearGradient(colors: tip.gradientColors, startPoint: .leading, endPoint: .trailing))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tip.gradientColors[0].opacity(0.08))
                                .cornerRadius(6)
                            Spacer()
                        }
                        
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: tip.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 48, height: 48)
                                    .shadow(color: tip.gradientColors[0].opacity(0.35), radius: 8)
                                
                                Image(systemName: tip.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tip.title)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
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
                    .padding(18)
                    .background(
                        ZStack {
                            Color.primary.opacity(0.01)
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.ultraThinMaterial)
                        }
                    )
                    .cornerRadius(24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.18),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: 155)
            
            // Custom premium page indicator
            HStack(spacing: 6) {
                Spacer()
                ForEach(0..<tips.count, id: \.self) { index in
                    Capsule()
                        .fill(selectedTipIndex == index ? LinearGradient(colors: tips[index].gradientColors, startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: selectedTipIndex == index ? 16 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTipIndex)
                }
                Spacer()
            }
            .padding(.top, -4)
        }
    }

    private var fridgeToRecipeSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                ZStack {
                    Circle().fill(Color.themePink.opacity(0.12)).frame(width: 36, height: 36)
                    Image(systemName: "refrigerator.fill").foregroundColor(.themePink)
                }
                Text("Fridge to Recipe")
                    .font(.system(.title3, design: .rounded, weight: .bold))
            }

            Text("Tell me what you have, and I'll generate a recipe that perfectly fits your remaining calories.")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundColor(isSearchFocused ? .themePink : .secondary)
                        .font(.system(size: 16))
                        .padding(.leading, 12)
                    
                    TextField("E.g. Eggs, chicken, rice...", text: Binding(get: { viewModel?.fridgeInput ?? "" }, set: { viewModel?.fridgeInput = $0 }))
                        .focused($isSearchFocused)
                        .font(.system(.body, design: .rounded))
                        .padding(.vertical, 12)
                        .padding(.trailing, 12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isSearchFocused ? LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing) : LinearGradient(colors: [.clear], startPoint: .leading, endPoint: .trailing),
                            lineWidth: 1.5
                        )
                        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
                )

                Button(action: { if let u = currentUser { viewModel?.generateSmartRecipe(currentSummary: currentSummary, currentUser: u) } }) {
                    if viewModel?.isGeneratingRecipe == true {
                        ProgressView().tint(.white)
                            .padding()
                            .background(Color.themePink)
                            .cornerRadius(14)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(14)
                            .shimmer()
                            .shadow(color: Color.themePink.opacity(0.3), radius: 6)
                    }
                }
                .disabled((viewModel?.fridgeInput.isEmpty ?? true) || (viewModel?.isGeneratingRecipe ?? true))
            }

            if let recipe = viewModel?.generatedRecipe {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().padding(.vertical, 4)
                    
                    HStack {
                        Text("🍳 AI RECIPE SUGGESTION")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.themePink.opacity(0.08))
                            .cornerRadius(6)
                        Spacer()
                    }
                    
                    Text(recipe.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(recipe.info)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CALORIES")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("\(recipe.calories) kcal")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.themeOrange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.themeOrange.opacity(0.08))
                        .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PROTEIN")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("\(recipe.protein)g")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.themePeach)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.themePeach.opacity(0.08))
                        .cornerRadius(10)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("COOKING")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("\(recipe.cookingTime) min")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                    }

                    Button(action: { saveGeneratedRecipe(recipe) }) {
                        Text("Save to My Recipes")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(12)
                            .shimmer()
                            .shadow(color: Color.themePink.opacity(0.2), radius: 6)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(20)
        .background(
            ZStack {
                Color.primary.opacity(0.01)
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
            }
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.horizontal)
    }

    private func saveGeneratedRecipe(_ recipeDTO: AIRecipeDTO) {
        let newRecipe = CustomRecipe(
            name: recipeDTO.name, info: recipeDTO.info,
            foodItems: [FoodItem(name: recipeDTO.name, weight: 100, calories: recipeDTO.calories, protein: recipeDTO.protein, fats: recipeDTO.fats, carbs: recipeDTO.carbs)],
            cookingTime: recipeDTO.cookingTime, difficulty: "Medium")
        context.insert(newRecipe); try? context.save()
        withAnimation { viewModel?.generatedRecipe = nil }; HapticManager.shared.impact(style: .light)
    }
}

struct DailyVerdictGlassCard: View {
    let title: String
    let message: String
    let moodColor: Color
    let isLoading: Bool
    let hasAnalyzed: Bool
    let onAnalyze: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Verdict")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .textCase(.uppercase)
                    .foregroundColor(hasAnalyzed ? moodColor : .secondary)
                Spacer()
                if isLoading { ProgressView().tint(moodColor) }
            }

            Text(title)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
                .contentTransition(.interpolate)

            FoodTypewriterTextView(fullText: message, isAnimating: !isLoading && hasAnalyzed)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundColor(.primary.opacity(0.85))
                .lineSpacing(4)

            if !hasAnalyzed && !isLoading {
                Button(action: onAnalyze) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Analyze My Day")
                    }
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(16)
                    .shimmer()
                    .shadow(color: Color.themePink.opacity(0.35), radius: 8, y: 4)
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            ZStack {
                // Glow aura circle
                Circle()
                    .fill(moodColor.opacity(hasAnalyzed ? 0.12 : 0.05))
                    .frame(width: 260, height: 260)
                    .blur(radius: 50)
                    .offset(x: -60, y: -40)
                    .animation(.easeInOut(duration: 2), value: moodColor)

                Color.primary.opacity(0.01)
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
            }
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            (hasAnalyzed ? moodColor : Color.gray).opacity(0.35),
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: hasAnalyzed ? moodColor.opacity(0.12) : .black.opacity(0.04), radius: 15, y: 5)
        .padding(.horizontal)
    }
}

struct AIFixCard: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            if !isLoading { action() }
        }) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Circle()
                        .stroke(color.opacity(0.25), lineWidth: 1)
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 18, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    HStack {
                        Text(isLoading ? "Analyzing..." : "Auto-analyze")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        Spacer()

                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: color))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(color)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                ZStack {
                    RadialGradient(colors: [color.opacity(0.06), .clear], center: .center, startRadius: 0, endRadius: 80)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                }
            )
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isLoading ? color.opacity(0.4) : Color.clear, lineWidth: 2)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: isLoading)
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
}

struct MacroFixResultSheet: View {
    @Environment(\.dismiss) var dismiss
    let advice: MacroFixAdviceDTO
    let color: Color

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
                                ForEach(advice.suggestedSnacks, id: \.self) { snack in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(snack.name)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .lineLimit(2)
                                            .foregroundColor(.primary)

                                        Spacer()

                                        HStack {
                                            Label("\(snack.calories) kcal", systemImage: "flame.fill")
                                                .foregroundColor(.themeOrange)
                                            Spacer()
                                            Text("\(snack.protein)g Protein")
                                                .bold()
                                                .foregroundColor(.themePeach)
                                        }
                                        .font(.system(size: 11, weight: .semibold))
                                    }
                                    .padding(16)
                                    .frame(width: 200, height: 125)
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
                        .foregroundColor(.white)
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
}

struct HydrationFixResultSheet: View {
    @Environment(\.dismiss) var dismiss
    let advice: HydrationAdviceDTO
    let color: Color

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

                    Button(action: { dismiss() }) {
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

