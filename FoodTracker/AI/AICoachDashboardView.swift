import SwiftUI
import SwiftData

struct AICoachDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]

    @Environment(DIContainer.self) private var di
    @State private var viewModel: AICoachViewModel?

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

                        Circle()
                            .fill(moodColors[0].opacity(0.15))
                            .frame(width: 300, height: 300)
                            .blur(radius: 80)
                            .offset(x: -100, y: -200)

                        Circle()
                            .fill(moodColors[1].opacity(0.15))
                            .frame(width: 350, height: 350)
                            .blur(radius: 80)
                            .offset(x: 150, y: 200)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 24) {

                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(LocalizedStringKey("AI Coach"))
                                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                                        Text(LocalizedStringKey("Your proactive nutritionist"))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
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

                                AIChatPromptRow(currentUser: currentUser, currentSummary: currentSummary)
                                fridgeToRecipeSection

                                bioHackingTipsSection

                                
                                Text(LocalizedStringKey("FoodTracker AI provides general nutritional information. It is not a substitute for professional medical advice, diagnosis, or treatment."))
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
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
                        .presentationDetents([.height(300)])
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
            title: String(localized: "Iron Synergy"),
            text: String(localized: "Pair iron-rich foods (spinach, lentils) with Vitamin C (citrus, peppers) to increase iron absorption by up to 300%."),
            icon: "leaf.fill",
            gradientColors: [.green, .mint]
        ),
        BioHackingTip(
            title: String(localized: "Protein Pacing"),
            text: String(localized: "Distribute your protein intake in 30-40g portions every 3-4 hours to keep muscle protein synthesis optimized."),
            icon: "flame.fill",
            gradientColors: [.themePink, .themeOrange]
        ),
        BioHackingTip(
            title: String(localized: "Circadian Fasting"),
            text: String(localized: "Finish eating at least 3 hours before sleep. This lowers insulin levels and improves deep sleep recovery phases."),
            icon: "moon.stars.fill",
            gradientColors: [.purple, .indigo]
        ),
        BioHackingTip(
            title: String(localized: "Hydration Window"),
            text: String(localized: "Drink 500ml of water immediately upon waking to kickstart metabolism and offset overnight dehydration."),
            icon: "drop.fill",
            gradientColors: [.cyan, .blue]
        ),
        BioHackingTip(
            title: String(localized: "Sodium Balance"),
            text: String(localized: "Feeling bloated? Increase potassium intake (avocados, bananas) to assist kidneys in flushing out excess sodium."),
            icon: "sparkles",
            gradientColors: [.themeYellow, .themeOrange]
        )
    ]

    private var bioHackingTipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle().fill(Color.purple.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: "lightbulb.fill").foregroundColor(.purple)
                }
                Text(LocalizedStringKey("Bio-hacking Tips"))
                    .font(.title3).bold()
                
                Spacer()
                
                Text(LocalizedStringKey("Swipe"))
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(6)
            }
            .padding(.horizontal)
            
            TabView {
                ForEach(tips) { tip in
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: tip.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 50, height: 50)
                                .shadow(color: tip.gradientColors[0].opacity(0.3), radius: 8)
                            
                            Image(systemName: tip.icon)
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tip.title)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.black)
                            
                            Text(tip.text)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.black.opacity(0.65))
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.08), radius: 12, y: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .frame(height: 145)
        }
    }

    private var fridgeToRecipeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle().fill(Color.themePink.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: "refrigerator.fill").foregroundColor(.themePink)
                }
                Text(LocalizedStringKey("Fridge to Recipe"))
                    .font(.title3).bold()
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("AI POWERED")
                        .font(.system(size: 9, weight: .black))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: Color.themePink.opacity(0.4), radius: 4, x: 0, y: 2)
            }

            Text(LocalizedStringKey("Tell me what you have, and I'll generate a recipe that perfectly fits your remaining calories."))
                .font(.subheadline).foregroundColor(.gray)

            HStack {
                TextField(String(localized: "E.g. Eggs, chicken, rice..."), text: Binding(get: { viewModel?.fridgeInput ?? "" }, set: { viewModel?.fridgeInput = $0 }))
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )

                Button(action: { if let u = currentUser { viewModel?.generateSmartRecipe(currentSummary: currentSummary, currentUser: u) } }) {
                    if viewModel?.isGeneratingRecipe == true {
                        ProgressView().tint(.white)
                            .padding()
                            .background(Color.themePink)
                            .cornerRadius(12)
                    } else {
                        Image(systemName: "wand.and.stars")
                            .foregroundColor(.white)
                            .padding()
                            .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom))
                            .cornerRadius(12)
                            .shadow(color: Color.themePink.opacity(0.3), radius: 6, y: 3)
                    }
                }
                .disabled((viewModel?.fridgeInput.isEmpty ?? true) || (viewModel?.isGeneratingRecipe ?? true))
            }

            if let recipe = viewModel?.generatedRecipe {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().padding(.vertical, 8)
                    Text(recipe.name).font(.headline)
                    Text(recipe.info).font(.subheadline).foregroundColor(.gray)
                    HStack {
                        Label("\(recipe.calories) kcal", systemImage: "flame.fill").foregroundColor(.themeOrange)
                        Spacer()
                        Label("\(recipe.cookingTime) min", systemImage: "clock.fill").foregroundColor(.gray)
                    }.font(.caption.bold())

                    Button(action: { saveGeneratedRecipe(recipe) }) {
                        Text(LocalizedStringKey("Save to My Recipes")).font(.subheadline.bold()).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.themePink).cornerRadius(12)
                    }
                }.transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [.themePink.opacity(0.4), .themeOrange.opacity(0.2), .themePink.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: Color.black.opacity(0.04), radius: 12, y: 6)
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
                Text(LocalizedStringKey("Daily Verdict"))
                    .font(.caption.bold())
                    .textCase(.uppercase)
                    .foregroundColor(hasAnalyzed ? moodColor : .gray)
                Spacer()
                if isLoading { ProgressView().tint(moodColor) }
            }

            Text(title)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .contentTransition(.interpolate)

            FoodTypewriterTextView(fullText: message, isAnimating: !isLoading && hasAnalyzed)
                .font(.body)
                .foregroundColor(.textGray)
                .lineSpacing(4)

            if !hasAnalyzed && !isLoading {
                Button(action: onAnalyze) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text(LocalizedStringKey("Analyze My Day"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(16)
                    .shadow(color: Color.themePink.opacity(0.3), radius: 8, y: 4)
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(hasAnalyzed ? moodColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1.5))
        .shadow(color: hasAnalyzed ? moodColor.opacity(0.15) : .black.opacity(0.05), radius: 15, y: 5)
        .padding(.horizontal)
    }
}

struct AIChatPromptRow: View {
    let currentUser: User?
    let currentSummary: DailySummary
    
    @State private var isAnimating = false
    
    var body: some View {
        NavigationLink(destination: AICoachChatView(
            userGoal: currentUser?.dailyCaloriesGoal ?? 2000,
            consumed: currentSummary.totalCalories,
            activeDiet: currentUser?.activeDietPlan?.name ?? String(localized: "Balanced")
        )) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4)
                        
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isAnimating ? 10 : -10))
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("Ask AI Coach"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(LocalizedStringKey("Get instant diet advice..."))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.themePink)
                    .shadow(color: Color.themePink.opacity(0.3), radius: 5, y: 2)
            }
            .padding(14)
            .background(Color.white)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(LinearGradient(colors: [Color.themePink.opacity(0.3), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 12, y: 6)
            .padding(.horizontal)
            .onAppear {
                isAnimating = true
            }
        }
        .buttonStyle(BounceButtonStyle())
    }
}
struct MacroFixResultSheet: View {
    @Environment(\.dismiss) var dismiss
    let advice: MacroFixAdviceDTO
    let color: Color

    var body: some View {
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
                        .font(.caption.bold())
                        .foregroundColor(color)
                        .textCase(.uppercase)
                }

                Text(advice.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text(advice.explanation)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            if !advice.suggestedSnacks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Perfect Matches for You:")
                        .font(.headline)
                        .padding(.horizontal, 24)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(advice.suggestedSnacks, id: \.self) { snack in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(snack.name)
                                        .font(.headline)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer()

                                    HStack {
                                        Label("\(snack.calories) kcal", systemImage: "flame.fill")
                                            .foregroundColor(.themeOrange)
                                        Spacer()
                                        Text("\(snack.protein)g P")
                                            .bold()
                                            .foregroundColor(.themePeach)
                                    }
                                    .font(.caption)
                                }
                                .padding(16)
                                .frame(width: 200, height: 120)
                                .background(Color.themeBg)
                                .cornerRadius(20)
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.3), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }

            Spacer()

            Button(action: { dismiss() }) {
                Text("Got it")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(color)
                    .cornerRadius(20)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color.white)
    }
}

struct HydrationFixResultSheet: View {
    @Environment(\.dismiss) var dismiss
    let advice: HydrationAdviceDTO
    let color: Color

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 80, height: 80)
                Image(systemName: "drop.fill").font(.system(size: 40)).foregroundColor(color)
            }

            VStack(spacing: 8) {
                Text(advice.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text(advice.message)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            HStack(spacing: 16) {
                Button(action: { dismiss() }) {
                    Text("Close")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)
                }

                Button(action: { dismiss() }) {
                    Text("Drink Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(color)
                        .cornerRadius(20)
                        .shadow(color: color.opacity(0.4), radius: 8, y: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color.white)
    }
}

struct BioHackingTip: Identifiable {
    let id = UUID()
    let title: String
    let text: String
    let icon: String
    let gradientColors: [Color]
}
