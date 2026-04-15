// FILE: FoodTracker/Views/AICoach/AICoachDashboardView.swift

import SwiftUI
import SwiftData

// MARK: - 1. ГЛАВНЫЙ ЭКРАН (Bento Box + Кнопка чата)
struct AICoachDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]
    
    let selectedDate: Date
    
    @State private var isAnalyzing = false
    @State private var verdictTitle: String = "Analyzing your day..."
    @State private var verdictMessage: String = "The AI Coach is reviewing your macros and calculating recommendations."
    @State private var verdictMood: String = "perfect"
    
    @State private var fridgeInput: String = ""
    @State private var isGeneratingRecipe = false
    @State private var generatedRecipe: AIRecipeDTO? = nil
    
    private var currentUser: User? { users.first }
    private var currentSummary: DailySummary {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        if let existing = summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            return existing
        } else {
            // Если для текущего дня нет записи, создаем ее
            let newSummary = DailySummary(date: startOfDay)
            // Важно: в SwiftUI view нельзя напрямую изменять базу, но @Query это делает за нас.
            DispatchQueue.main.async { context.insert(newSummary) }
            return newSummary
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
                                consumed: currentSummary.totalCalories
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
                            isLoading: isAnalyzing
                        )
                        
                        HStack(spacing: 16) {
                            AIFixCard(title: "Fix Macros", icon: "chart.pie.fill", color: moodColors[1], action: { runDailyAnalysis(forceRefresh: true) })
                            AIFixCard(title: "Hydration", icon: "drop.fill", color: .cyan, action: { })
                        }
                        .padding(.horizontal)
                        
                        fridgeToRecipeSection
                        
                    }
                    .padding(.bottom, 120)
                }
            }
            .onAppear {
                if verdictTitle == "Analyzing your day..." { runDailyAnalysis() }
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
        
        withAnimation { isAnalyzing = true }
        
        Task {
            if let verdict = await AINutritionService.shared.generateDailyVerdict(consumed: cals, goal: goal, protein: protein, targetProtein: targetP) {
                await MainActor.run { withAnimation(.spring()) {
                    self.verdictTitle = verdict.title; self.verdictMessage = verdict.message; self.verdictMood = verdict.mood; self.isAnalyzing = false
                }}
            } else {
                await MainActor.run { withAnimation(.spring()) {
                    if cals > goal { self.verdictMood = "danger" } else if cals < goal / 2 { self.verdictMood = "warning" } else { self.verdictMood = "perfect" }
                    self.verdictTitle = "Data Collected"; self.verdictMessage = "You've eaten \(cals) kcal out of \(goal). Keep tracking to stay on top of your goals!"; self.isAnalyzing = false
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Verdict").font(.caption.bold()).textCase(.uppercase).foregroundColor(moodColor)
                Spacer()
                if isLoading { ProgressView().tint(moodColor) }
            }
            Text(title).font(.title2.bold()).foregroundColor(.primary).contentTransition(.interpolate)
            
            // FoodTypewriterTextView берется из AICoachChatView.swift, он доступен глобально
            FoodTypewriterTextView(fullText: message, isAnimating: !isLoading)
                .font(.body)
                .foregroundColor(.textGray)
                .lineSpacing(4)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(moodColor.opacity(0.3), lineWidth: 1.5))
        .shadow(color: moodColor.opacity(0.15), radius: 15, y: 5)
        .padding(.horizontal)
    }
}

struct AIFixCard: View {
    let title: String; let icon: String; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 40, height: 40)
                    Image(systemName: icon).foregroundColor(color).font(.title3)
                }
                Text(title).font(.headline).foregroundColor(.primary)
                HStack {
                    Text("Auto-analyze").font(.caption).foregroundColor(.gray)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(color)
                }
            }
            .frame(maxWidth: .infinity)
            .premiumCardStyle()
        }
        .buttonStyle(BounceButtonStyle())
    }
}
