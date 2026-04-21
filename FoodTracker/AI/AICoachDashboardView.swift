// FILE: FoodTracker/Views/AICoach/AICoachDashboardView.swift

import SwiftUI
import SwiftData


// MARK: - 1. ГЛАВНЫЙ ЭКРАН (Bento Box + Кнопка чата)
struct AICoachDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]
    
    // Стейты агентов
    @State private var isFixingMacros = false
    @State private var isFixingHydration = false
    @State private var macroAdvice: MacroFixAdviceDTO? = nil
    @State private var hydrationAdvice: HydrationAdviceDTO? = nil

    let selectedDate: Date
    
    // Стейты основного анализа (✅ ТУТ БЫЛА ОШИБКА, ДОБАВЛЕН @)
    @State private var isAnalyzing = false
    @State private var hasAnalyzedToday = false
    @State private var verdictTitle: String = "AI Daily Review"
    @State private var verdictMessage: String = "Tap the button below to analyze your calories, macros, and get a personalized summary for today."
    @State private var verdictMood: String = "neutral"
    
    // Стейты рецептов из холодильника
    @State private var fridgeInput: String = ""
    @State private var isGeneratingRecipe = false
    @State private var generatedRecipe: AIRecipeDTO? = nil
    
    private var currentUser: User? { users.first }
    private var currentSummary: DailySummary {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        if let existing = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            return existing
        } else {
            return DailySummary(date: startOfDay)
        }
    }
    
    // Динамические цвета для ауры на фоне
    private var moodColors: [Color] {
        switch verdictMood.lowercased() {
        case "perfect": return [.green, .mint]
        case "danger": return [.red, .themePink]
        case "warning": return [.orange, .themeYellow]
        default: return [.themePink, .themeOrange]
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                // 1. ДИНАМИЧЕСКИЕ АУРЫ (ЛЕВИТИРУЮЩИЕ ПЯТНА)
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
                        
                        // 2. ШАПКА С КНОПКОЙ ЧАТА
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Coach")
                                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                                Text("Your proactive nutritionist")
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            
                            // КНОПКА ПЕРЕХОДА В ЧАТ
                            NavigationLink(destination: AICoachChatView(
                                userGoal: currentUser?.dailyCaloriesGoal ?? 2000,
                                consumed: currentSummary.totalCalories,
                                activeDiet: currentUser?.activeDietPlan?.name ?? String(localized: "Balanced")
                            )) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 50, height: 50)
                                        .opacity(isAnalyzing || isGeneratingRecipe ? 0.5 : 1.0)
                                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnalyzing || isGeneratingRecipe)
                                    
                                    Image(systemName: "message.fill")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // 3. ДИНАМИЧЕСКАЯ КАРТОЧКА (BENTO С МАТОВЫМ СТЕКЛОМ)
                        DailyVerdictGlassCard(
                            title: verdictTitle,
                            message: verdictMessage,
                            moodColor: moodColors[0],
                            isLoading: isAnalyzing,
                            hasAnalyzed: hasAnalyzedToday, // ✅ ПЕРЕДАЕМ НОВЫЙ ПАРАМЕТР
                            onAnalyze: { runDailyAnalysis() } // ✅ ДЕЙСТВИЕ ДЛЯ КНОПКИ
                        )
                        
                        HStack(spacing: 16) {
                            AIFixCard(
                                title: "Fix Macros",
                                icon: "chart.pie.fill",
                                color: .themeYellow,
                                isLoading: isFixingMacros,
                                action: { analyzeMacros() }
                            )
                            
                            AIFixCard(
                                title: "Hydration",
                                icon: "drop.fill",
                                color: .cyan,
                                isLoading: isFixingHydration,
                                action: { analyzeHydration() }
                            )
                        }
                        .padding(.horizontal)

                        
                        fridgeToRecipeSection
                        
                    }
                    .padding(.bottom, 120)
                }
            }
            .sheet(item: $macroAdvice) { advice in
                MacroFixResultSheet(advice: advice, color: .themeYellow)
                    .presentationDetents([.medium, .large])
                    .presentationCornerRadius(32)
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $hydrationAdvice) { advice in
                HydrationFixResultSheet(advice: advice, color: .cyan)
                    .presentationDetents([.height(300)])
                    .presentationCornerRadius(32)
                    .presentationDragIndicator(.visible)
            }

        }
    }
    
    private var fridgeToRecipeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle().fill(Color.themePink.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: "refrigerator.fill").foregroundColor(.themePink)
                }
                Text("Fridge to Recipe")
                    .font(.title3).bold()
            }
            
            Text("Tell me what you have, and I'll generate a recipe that perfectly fits your remaining calories.")
                .font(.subheadline).foregroundColor(.gray)
            
            HStack {
                TextField("E.g. Eggs, chicken, rice...", text: $fridgeInput)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                
                Button(action: generateSmartRecipe) {
                    if isGeneratingRecipe {
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
                    }
                }
                .disabled(fridgeInput.isEmpty || isGeneratingRecipe)
            }
            
            if let recipe = generatedRecipe {
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
                        Text("Save to My Recipes").font(.subheadline.bold()).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12).background(Color.themePink).cornerRadius(12)
                    }
                }.transition(.move(edge: .top).combined(with: .opacity))
            }
        }.premiumCardStyle().padding(.horizontal)
    }
    
    private func runDailyAnalysis(forceRefresh: Bool = false) {
            guard let user = currentUser else { return }
            let cals = currentSummary.totalCalories; let goal = user.dailyCaloriesGoal
            let protein = currentSummary.totalProtein; let targetP = user.targetProtein
            
            HapticManager.shared.impact(style: .medium)
            withAnimation { isAnalyzing = true }
            
            Task {
                if let verdict = await AINutritionService.shared.generateDailyVerdict(consumed: cals, goal: goal, protein: protein, targetProtein: targetP) {
                    await MainActor.run { withAnimation(.spring()) {
                        self.verdictTitle = verdict.title
                        self.verdictMessage = verdict.message
                        self.verdictMood = verdict.mood
                        self.hasAnalyzedToday = true // ✅ Помечаем, что анализ прошел
                        self.isAnalyzing = false
                        HapticManager.shared.impact(style: .heavy)
                    }}
                } else {
                    await MainActor.run { withAnimation(.spring()) {
                        if cals > goal { self.verdictMood = "danger" } else if cals < goal / 2 { self.verdictMood = "warning" } else { self.verdictMood = "perfect" }
                        self.verdictTitle = "Data Collected"
                        self.verdictMessage = "You've eaten \(cals) kcal out of \(goal)."
                        self.hasAnalyzedToday = true // ✅ Помечаем, что анализ прошел (даже при ошибке)
                        self.isAnalyzing = false
                    }}
                }
            }
        }
    
    private func generateSmartRecipe() {
        guard let user = currentUser else { return }
        let missingCals = max(0, user.dailyCaloriesGoal - currentSummary.totalCalories); let missingProtein = max(0, Int(user.targetProtein - currentSummary.totalProtein))
        HapticManager.shared.impact(style: .medium); withAnimation { isGeneratingRecipe = true }
        Task {
            if let recipe = await AINutritionService.shared.generateFridgeRecipe(ingredients: fridgeInput, missingCalories: missingCals, missingProtein: missingProtein) {
                await MainActor.run { withAnimation(.spring()) {
                    self.generatedRecipe = recipe; self.fridgeInput = ""; self.isGeneratingRecipe = false; HapticManager.shared.impact(style: .heavy)
                }}
            } else { await MainActor.run { self.isGeneratingRecipe = false } }
        }
    }
    private func analyzeMacros() {
            guard let user = currentUser else { return }
            HapticManager.shared.impact(style: .medium)
            isFixingMacros = true
            
            let missingCals = user.dailyCaloriesGoal - currentSummary.totalCalories
            let missingP = Int(user.targetProtein - currentSummary.totalProtein)
            let missingF = Int(user.targetFats - currentSummary.totalFats)
            let missingC = Int(user.targetCarbs - currentSummary.totalCarbs)
            
            Task {
                if let advice = await AINutritionService.shared.getMacroFixAdvice(missingCals: missingCals, missingProtein: missingP, missingFats: missingF, missingCarbs: missingC) {
                    await MainActor.run {
                        self.macroAdvice = advice
                        self.isFixingMacros = false // Останавливаем крутилку
                        HapticManager.shared.impact(style: .heavy)
                    }
                } else {
                    await MainActor.run {
                        print("❌ Не удалось получить совет по макросам от ИИ")
                        self.isFixingMacros = false // Останавливаем крутилку даже при ошибке
                    }
                }
            }
        }
    private func analyzeHydration() {
        HapticManager.shared.impact(style: .medium)
        isFixingHydration = true
        
        let drank = currentSummary.totalHydrationLiters
        
        Task {
            if let advice = await AINutritionService.shared.getHydrationAdvice(drankLiters: drank, goalLiters: 2.5) {
                await MainActor.run {
                    self.isFixingHydration = false
                    self.hydrationAdvice = advice
                    HapticManager.shared.impact(style: .heavy)
                }
            } else {
                await MainActor.run { self.isFixingHydration = false }
            }
        }
    }
    private func saveGeneratedRecipe(_ recipeDTO: AIRecipeDTO) {
        let newRecipe = CustomRecipe(
            name: recipeDTO.name, info: recipeDTO.info,
            foodItems: [FoodItem(name: recipeDTO.name, weight: 100, calories: recipeDTO.calories, protein: recipeDTO.protein, fats: recipeDTO.fats, carbs: recipeDTO.carbs)],
            cookingTime: recipeDTO.cookingTime, difficulty: "Medium")
        context.insert(newRecipe); try? context.save()
        withAnimation { generatedRecipe = nil }; HapticManager.shared.impact(style: .light)
    }
}

// MARK: - 2. ВСПОМОГАТЕЛЬНЫЕ UI-КОМПОНЕНТЫ
struct DailyVerdictGlassCard: View {
    let title: String
    let message: String
    let moodColor: Color
    let isLoading: Bool
    let hasAnalyzed: Bool // ✅
    let onAnalyze: () -> Void // ✅
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Verdict")
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
            
            // ✅ КНОПКА ПОЯВЛЯЕТСЯ, ТОЛЬКО ЕСЛИ АНАЛИЗ ЕЩЕ НЕ ДЕЛАЛИ
            if !hasAnalyzed && !isLoading {
                Button(action: onAnalyze) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Analyze My Day")
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

struct AIFixCard: View {
    let title: String
    let icon: String
    let color: Color
    let isLoading: Bool // НОВОЕ: Состояние загрузки
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if !isLoading { action() }
        }) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .foregroundColor(color)
                        .font(.system(size: 20, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(isLoading ? "Analyzing..." : "Auto-analyze")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        
                        // АНИМАЦИЯ ЗАГРУЗКИ ИЛИ СТРЕЛОЧКА
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: color))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(color)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
            // Плавное свечение при загрузке
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isLoading ? color.opacity(0.3) : Color.clear, lineWidth: 2)
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
                
                // В будущем сюда можно привязать добавление стакана воды
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
