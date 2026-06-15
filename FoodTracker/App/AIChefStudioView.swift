//
//  AIChefStudioView.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 1.05.26.
//

import SwiftUI
import SwiftData

// MARK: - 📦 Модели Данных
struct RecipeStep: Identifiable, Hashable {
    let id = UUID()
    let instruction: String
    let imageName: String
    let aiTip: String?
}

struct AIChefRecipe: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let calories: Int
    let protein: Int
    let heroImage: String
    let cookTime: Int
    let difficulty: Int
    let history: String
    let ingredients: [String]
    let steps: [RecipeStep]
    let platingTip: String
}

struct UnifiedRecipePreview: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let calories: Int
    let protein: Int
    let heroImage: String
    let cookTime: Int
    let ingredients: [String]
    let premiumRecipe: PremiumRecipe?
    let customRecipe: CustomRecipe?
}

// MARK: - 👨‍🍳 Главный Экран
struct AIChefStudioView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(RecipeDataLoader.self) private var dataLoader
    @Query private var customRecipes: [CustomRecipe]
    @Query private var weeklyPlans: [WeeklyMealPlan]
    
    @State private var remainingCalories: Int = 450
    @State private var remainingProtein: Int = 32
    @State private var remainingFat: Int = 18
    @State private var remainingCarbs: Int = 45
    
    @State private var searchText = ""
    @State private var showAIAssistantFlow = false
    @State private var showSmartBuilder = false
    @State private var showActivePlan = false
    
    var allPreviews: [UnifiedRecipePreview] {
        var list = [UnifiedRecipePreview]()
        for pr in dataLoader.recipes {
            list.append(UnifiedRecipePreview(
                title: pr.title,
                calories: pr.caloriesPerServing,
                protein: Int(pr.protein),
                heroImage: pr.imageUrl,
                cookTime: Int(pr.time.replacingOccurrences(of: "m", with: "")) ?? 20,
                ingredients: pr.ingredients.map { "\($0.name) (\($0.amount))" },
                premiumRecipe: pr,
                customRecipe: nil
            ))
        }
        for cr in customRecipes {
            list.append(UnifiedRecipePreview(
                title: cr.name,
                calories: cr.totalCalories,
                protein: Int(cr.foodItems.reduce(0) { $0 + $1.protein }),
                heroImage: "fork.knife",
                cookTime: cr.cookingTime,
                ingredients: cr.foodItems.map { "\($0.name) (\($0.weight)g)" },
                premiumRecipe: nil,
                customRecipe: cr
            ))
        }
        return list
    }
    
    var filteredRecipes: [UnifiedRecipePreview] { allPreviews.filter { $0.title.localizedCaseInsensitiveContains(searchText) } }
    var suggestedRecipes: [UnifiedRecipePreview] { allPreviews.filter { $0.calories <= remainingCalories + 150 }.shuffled().prefix(5).map { $0 } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 1. АГЕНТ (СУПЕР-ФЛОУ С КАМЕРОЙ)
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            showAIAssistantFlow = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "sparkles.tv")
                                        Text("ИИ-Ассистент")
                                    }.font(.caption.bold()).foregroundColor(.white.opacity(0.8))
                                    Text("Опробуй готовку с ИИ").font(.title3.bold()).foregroundColor(.white)
                                }
                                Spacer()
                                Image(systemName: "camera.macro.circle.fill").font(.system(size: 40)).foregroundColor(.white).symbolEffect(.pulse)
                            }
                            .padding(20)
                            .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(24)
                            .shadow(color: .themePink.opacity(0.3), radius: 10, y: 5)
                        }
                        .buttonStyle(BounceButtonStyle())
                        .padding(.horizontal)
                        
                        // 1.5 SMART MEAL PLAN BUILDER
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            showSmartBuilder = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "calendar.badge.clock")
                                        Text("AI Menu Builder")
                                    }.font(.caption.bold()).foregroundColor(.white.opacity(0.8))
                                    Text("Build a 7-Day Plan").font(.title3.bold()).foregroundColor(.white)
                                }
                                Spacer()
                                Image(systemName: "wand.and.stars").font(.system(size: 32)).foregroundColor(.white)
                            }
                            .padding(20)
                            .background(themeManager.current.primaryGradient)
                            .cornerRadius(24)
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 10, y: 5)
                        }
                        .buttonStyle(BounceButtonStyle())
                        .padding(.horizontal)
                        
                        // Active 7-Day Plan Preview
                        if let activePlan = weeklyPlans.first(where: { $0.isCurrentPlan }) {
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                showActivePlan = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Current 7-Day Protocol").font(.caption.bold()).foregroundColor(themeManager.current.primaryAccent)
                                        Text("View Active Plan").font(.title3.bold()).foregroundColor(.primary)
                                        Text("\(activePlan.targetCalories) kcal • \(activePlan.dietType)").font(.subheadline).foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right.circle.fill").font(.title).foregroundColor(themeManager.current.primaryAccent)
                                }
                                .padding(20)
                                .background(Color.white)
                                .cornerRadius(24)
                                .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                        
                        // 2. ВИДЖЕТ МАКРОСОВ
                        DailyMacroWidget(calories: remainingCalories, protein: remainingProtein, fat: remainingFat, carbs: remainingCarbs)
                        
                        // 3. ПОИСК
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.gray)
                            TextField("Найти блюдо в базе...", text: $searchText)
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) { Image(systemName: "xmark.circle.fill").foregroundColor(.gray) }
                            }
                        }
                        .padding().background(Color.white).cornerRadius(16).padding(.horizontal)
                        
                        // 4. КОНТЕНТ ПОД ПОИСКОМ
                        if !searchText.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(filteredRecipes) { recipe in
                                    NavigationLink(destination: getDetailView(for: recipe)) {
                                        SearchResultRow(recipe: recipe)
                                    }.buttonStyle(PlainButtonStyle())
                                }
                                if filteredRecipes.isEmpty { Text("Блюдо не найдено").foregroundColor(.gray).padding() }
                            }.padding(.horizontal)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("ИИ подобрал под твои макросы:")
                                    .font(.title3.bold())
                                    .padding(.horizontal)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(suggestedRecipes) { recipe in
                                            NavigationLink(destination: getDetailView(for: recipe)) {
                                                RecipeCardView(recipe: recipe)
                                            }.buttonStyle(PlainButtonStyle())
                                        }
                                    }.padding(.horizontal)
                                }
                            }
                        }
                        
                        // 5. МЕДИЦИНСКИЙ ДИСКЛЕЙМЕР (Guideline 1.4.1)
                        Text("FoodTracker AI provides general nutritional information. It is not a substitute for professional medical advice, diagnosis, or treatment.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            
                    }.padding(.vertical)
                }
            }
            .navigationTitle("AI Шеф")
            .onAppear {
                TrackingManager.shared.track(.featureDiscovered(feature: "ai_chef_studio"))
            }
            .fullScreenCover(isPresented: $showAIAssistantFlow) {
                AIAssistantFlowView(isPresented: $showAIAssistantFlow)
            }
            .fullScreenCover(isPresented: $showSmartBuilder) {
                SmartPlanBuilderFlow()
            }
            .fullScreenCover(isPresented: $showActivePlan) {
                if let plan = weeklyPlans.first(where: { $0.isCurrentPlan }) {
                    WeeklyPlanOverview(plan: plan) {
                        showActivePlan = false
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func getDetailView(for preview: UnifiedRecipePreview) -> some View {
        if let pr = preview.premiumRecipe {
            PremiumRecipeDetailView(recipe: pr)
        } else if let cr = preview.customRecipe {
            Text("Custom Recipe Details: \(cr.name)")
        } else {
            Text("Recipe not found")
        }
    }
}

// MARK: - 📊 ВИДЖЕТ МАКРОСОВ
struct DailyMacroWidget: View {
    let calories: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Осталось на сегодня")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(calories)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("ккал")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.themePink)
                    .opacity(0.8)
            }
            
            HStack(spacing: 12) {
                MacroPillView(title: "Белки", value: "\(protein)г", color: .themePeach)
                MacroPillView(title: "Жиры", value: "\(fat)г", color: .themeYellow)
                MacroPillView(title: "Углеводы", value: "\(carbs)г", color: .drinkWater)
            }
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal)
    }
}

struct MacroPillView: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption2.bold()).foregroundColor(color)
            Text(value).font(.headline.bold()).foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(color.opacity(0.1)).cornerRadius(12)
    }
}

struct SearchResultRow: View {
    let recipe: UnifiedRecipePreview
    var body: some View {
        HStack {
            if recipe.heroImage.starts(with: "http") {
                AsyncImage(url: URL(string: recipe.heroImage)) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Color.gray.opacity(0.3) }
                }
                .frame(width: 40, height: 40).cornerRadius(10)
            } else {
                Image(systemName: recipe.heroImage).foregroundColor(.themePink).frame(width: 40, height: 40).background(Color.themePink.opacity(0.1)).cornerRadius(10)
            }
            VStack(alignment: .leading) {
                Text(recipe.title).font(.headline)
                Text("\(recipe.calories) ккал").font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.5))
        }.padding().background(Color.white).cornerRadius(16)
    }
}

struct RecipeCardView: View {
    let recipe: UnifiedRecipePreview
    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Color.themePink.opacity(0.15)
                if recipe.heroImage.starts(with: "http") {
                    AsyncImage(url: URL(string: recipe.heroImage)) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color.gray.opacity(0.3) }
                    }
                } else {
                    Image(systemName: recipe.heroImage).resizable().scaledToFit().frame(width: 50, height: 50).foregroundColor(.themePink)
                }
            }.frame(width: 180, height: 120).cornerRadius(16)
            Text(recipe.title).font(.headline).lineLimit(1).padding(.top, 8)
            Text("\(recipe.calories) ккал • \(recipe.cookTime) мин").font(.caption).foregroundColor(.gray)
        }.frame(width: 180)
    }
}

// MARK: - 📖 Экран Деталей Рецепта
struct RecipeDetailAIView: View {
    let recipe: AIChefRecipe
    @State private var isCookingModeActive = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Circle().fill(Color.themePink.opacity(0.2)).frame(width: 120, height: 120)
                    .overlay(Image(systemName: recipe.heroImage).font(.system(size: 50)).foregroundColor(.themePink)).padding(.top, 20)
                
                Text(recipe.title).font(.title.bold()).multilineTextAlignment(.center)
                
                HStack(spacing: 40) {
                    VStack { Image(systemName: "clock.fill").foregroundColor(.gray); Text("\(recipe.cookTime) мин").font(.subheadline.bold()) }
                    VStack {
                        HStack(spacing: 2) { ForEach(1...5, id: \.self) { star in Image(systemName: star <= recipe.difficulty ? "star.fill" : "star").foregroundColor(.themeYellow).font(.caption) } }
                        Text("Сложность").font(.caption).foregroundColor(.gray)
                    }
                }.padding().background(Color.white).cornerRadius(16)
                
                Button(action: { HapticManager.shared.impact(style: .medium); isCookingModeActive = true }) {
                    HStack { Image(systemName: "play.circle.fill"); Text("Начать пошаговую готовку") }
                        .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.themePink).cornerRadius(16)
                }.padding(.horizontal, 24)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Image(systemName: "list.bullet.clipboard.fill").foregroundColor(.themePink); Text("Ингредиенты").font(.title3.bold()) }
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            HStack(alignment: .top) { Circle().fill(Color.themePink).frame(width: 6, height: 6).padding(.top, 6); Text(ingredient).font(.body) }
                        }
                    }.padding(.top, 4)
                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.white).cornerRadius(16).padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Image(systemName: "book.pages.fill").foregroundColor(.themePink); Text("История и Факты").font(.title3.bold()) }
                    Text(recipe.history).font(.body).lineSpacing(6).foregroundColor(.secondary)
                }.padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.white).cornerRadius(16).padding(.horizontal)
                
                // 🌟 СЕРВИРОВКА
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Image(systemName: "sparkles").foregroundColor(.themeOrange); Text("Искусство подачи").font(.title3.bold()) }
                    Text(recipe.platingTip)
                        .font(.body.italic())
                        .lineSpacing(6)
                        .foregroundColor(.primary)
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.themeOrange.opacity(0.1)).cornerRadius(16).padding(.horizontal)
                
            }.padding(.bottom, 40)
        }
        .background(Color.themeBg.ignoresSafeArea())
        .navigationTitle("Рецепт")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isCookingModeActive) {
            InteractiveCookingView(recipe: recipe, isPresented: $isCookingModeActive)
        }
    }
}

// MARK: - 👩‍🍳 Пошаговый режим готовки
struct InteractiveCookingView: View {
    let recipe: AIChefRecipe
    @Binding var isPresented: Bool
    @State private var visibleStepsCount = 1
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: { isPresented = false }) { Image(systemName: "xmark.circle.fill").font(.title).foregroundColor(.gray.opacity(0.5)) }
                    Spacer(); Text("Готовка: \(recipe.title)").font(.headline); Spacer()
                    Image(systemName: "eye.fill").foregroundColor(.themePink.opacity(0.6))
                }.padding()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(0..<visibleStepsCount, id: \.self) { index in
                                CookingStepRow(step: recipe.steps[index], stepNumber: index + 1).id(index).transition(.move(edge: .top).combined(with: .opacity))
                            }
                            
                            if visibleStepsCount == recipe.steps.count {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack { Image(systemName: "sparkles").foregroundColor(.themeOrange); Text("Финальный штрих: Подача").font(.headline) }
                                    Text(recipe.platingTip).font(.body.italic()).foregroundColor(.primary).lineSpacing(4)
                                }
                                .padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.themeOrange.opacity(0.1)).cornerRadius(16).padding(.horizontal)
                                .transition(.scale.combined(with: .opacity))
                                .id("platingTip")
                            }
                        }.padding(.top, 10).padding(.bottom, 120)
                    }.onChange(of: visibleStepsCount) { _, newValue in
                        withAnimation {
                            if newValue == recipe.steps.count {
                                proxy.scrollTo("platingTip", anchor: .bottom)
                            } else {
                                proxy.scrollTo(newValue - 1, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            VStack {
                Spacer()
                Button(action: nextStep) {
                    HStack {
                        Text(visibleStepsCount == recipe.steps.count ? "Завершить и съесть!" : "Следующий шаг")
                        if visibleStepsCount < recipe.steps.count { Image(systemName: "arrow.down") }
                    }.font(.title3.bold()).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 20).background(Color.themePink).cornerRadius(24)
                }.padding(.horizontal).padding(.bottom, 20)
            }
        }
    }
    private func nextStep() {
        HapticManager.shared.impact(style: .rigid)
        if visibleStepsCount < recipe.steps.count { withAnimation(.spring()) { visibleStepsCount += 1 } } else { isPresented = false }
    }
}

struct CookingStepRow: View {
    let step: RecipeStep
    let stepNumber: Int
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Circle().fill(Color.themePink).frame(width: 32, height: 32).overlay(Text("\(stepNumber)").foregroundColor(.white).font(.headline))
            VStack(alignment: .leading, spacing: 8) {
                Text(step.instruction).font(.body.weight(.medium)).lineSpacing(4)
                if let tip = step.aiTip {
                    HStack(alignment: .top) {
                        Image(systemName: "sparkles").foregroundColor(.themePink)
                        Text(tip).font(.subheadline).foregroundColor(.secondary)
                    }.padding(12).background(Color.themePink.opacity(0.05)).cornerRadius(12).padding(.top, 4)
                }
            }
            Spacer()
        }.padding().background(Color.white).cornerRadius(16).padding(.horizontal)
    }
}

// ==========================================
// MARK: - 🤖 СУПЕР-ФЛОУ АГЕНТА С КАМЕРОЙ
// ==========================================
struct AIAssistantFlowView: View {
    @Binding var isPresented: Bool
    @Environment(RecipeDataLoader.self) private var dataLoader
    @Query private var customRecipes: [CustomRecipe]
    
    @State private var searchAgentText = ""
    @State private var selectedRecipe: AIChefRecipe? = nil
    @State private var isPrepPhase = false
    @State private var isGenerating = false
    
    var agentResults: [UnifiedRecipePreview] {
        var list = [UnifiedRecipePreview]()
        for pr in dataLoader.recipes { list.append(UnifiedRecipePreview(title: pr.title, calories: pr.caloriesPerServing, protein: Int(pr.protein), heroImage: pr.imageUrl, cookTime: Int(pr.time.replacingOccurrences(of: "m", with: "")) ?? 20, ingredients: pr.ingredients.map { "\($0.name) (\($0.amount))" }, premiumRecipe: pr, customRecipe: nil)) }
        for cr in customRecipes { list.append(UnifiedRecipePreview(title: cr.name, calories: cr.totalCalories, protein: Int(cr.foodItems.reduce(0) { $0 + $1.protein }), heroImage: "fork.knife", cookTime: cr.cookingTime, ingredients: cr.foodItems.map { "\($0.name) (\($0.weight)g)" }, premiumRecipe: nil, customRecipe: cr)) }
        if searchAgentText.isEmpty { return list }
        return list.filter { $0.title.localizedCaseInsensitiveContains(searchAgentText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text("Что приготовим с ИИ?").font(.largeTitle.bold()).padding(.top)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Например: Рибай...", text: $searchAgentText)
                    }.padding().background(Color.white).cornerRadius(16).padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(agentResults) { recipe in
                                Button(action: {
                                    generateAI(from: recipe)
                                }) { SearchResultRow(recipe: recipe) }.buttonStyle(PlainButtonStyle())
                            }
                        }.padding(.horizontal)
                        
                        // МЕДИЦИНСКИЙ ДИСКЛЕЙМЕР (Guideline 1.4.1)
                        Text("FoodTracker AI provides general nutritional information. It is not a substitute for professional medical advice, diagnosis, or treatment.")
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                    }
                }
                .disabled(isGenerating)
                
                if isGenerating {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(2.0)
                            .tint(.themePink)
                        Text("Шеф-повар ИИ готовит...")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    .padding(40)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Отмена") { isPresented = false }.foregroundColor(.themePink).disabled(isGenerating) } }
            .navigationDestination(isPresented: $isPrepPhase) { if let r = selectedRecipe { PrepChecklistView(recipe: r, isFlowPresented: $isPresented) } }
        }
    }

    private func generateAI(from preview: UnifiedRecipePreview) {
        guard !isGenerating else { return }
        isGenerating = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            if let dto = await AINutritionService.shared.generateCookingSteps(for: preview.title, ingredients: preview.ingredients) {
                let ai = AIChefRecipe(
                    title: dto.title,
                    calories: dto.calories,
                    protein: dto.protein,
                    heroImage: preview.heroImage.isEmpty ? "fork.knife" : preview.heroImage,
                    cookTime: dto.cookTime,
                    difficulty: dto.difficulty,
                    history: dto.history,
                    ingredients: dto.ingredients,
                    steps: dto.steps.map { RecipeStep(instruction: $0.instruction, imageName: "sparkles", aiTip: $0.aiTip) },
                    platingTip: dto.platingTip
                )
                await MainActor.run {
                    self.selectedRecipe = ai
                    self.isGenerating = false
                    self.isPrepPhase = true
                }
            } else {
                await MainActor.run { self.isGenerating = false }
            }
        }
    }
}

struct PrepChecklistView: View {
    let recipe: AIChefRecipe
    @Binding var isFlowPresented: Bool
    @State private var checkedItems: Set<String> = []
    @State private var isCookingPhase = false
    var allChecked: Bool { checkedItems.count == recipe.ingredients.count }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mise en place").font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Gather these ingredients before starting.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Progress Indicator
                    HStack {
                        ProgressView(value: Double(checkedItems.count), total: Double(max(1, recipe.ingredients.count)))
                            .tint(.themePink)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                        Text("\(checkedItems.count)/\(recipe.ingredients.count)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(recipe.ingredients, id: \.self) { item in
                            let isChecked = checkedItems.contains(item)
                            HStack {
                                Text(item)
                                    .font(.system(size: 16, weight: isChecked ? .regular : .semibold, design: .rounded))
                                    .strikethrough(isChecked, color: .gray)
                                    .foregroundColor(isChecked ? .gray : .primary)
                                Spacer()
                                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 24))
                                    .foregroundColor(isChecked ? .green : .gray.opacity(0.3))
                                    .scaleEffect(isChecked ? 1.1 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isChecked)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isChecked ? Color.green.opacity(0.05) : Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(isChecked ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(isChecked ? 0 : 0.03), radius: 5, y: 2)
                            .opacity(isChecked ? 0.7 : 1.0)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                HapticManager.shared.impact(style: .light)
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    if checkedItems.contains(item) { checkedItems.remove(item) } else { checkedItems.insert(item) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 120) // padding for the bottom bar
                }
            }
            
            // Sticky Bottom Bar
            VStack {
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    isCookingPhase = true
                }) {
                    HStack {
                        Text(allChecked ? "Start Cooking!" : "Skip Checklist")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        if allChecked {
                            Image(systemName: "flame.fill")
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        allChecked ?
                        AnyShapeStyle(LinearGradient(colors: [.green, .themePink], startPoint: .topLeading, endPoint: .bottomTrailing)) :
                        AnyShapeStyle(Color.gray.opacity(0.8))
                    )
                    .clipShape(Capsule())
                    .shadow(color: allChecked ? .green.opacity(0.3) : .clear, radius: 10, y: 5)
                    .scaleEffect(allChecked ? 1.02 : 1.0)
                    .animation(allChecked ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default, value: allChecked)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(.ultraThinMaterial)
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isCookingPhase) { AgentCookingView(recipe: recipe, isFlowPresented: $isFlowPresented) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    HapticManager.shared.impact(style: .rigid)
                    isFlowPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
        }
    }
}

struct AgentCookingView: View {
    let recipe: AIChefRecipe
    @Binding var isFlowPresented: Bool
    @State private var showCameraScanner = false
    @State private var currentStepForCamera: RecipeStep? = nil
    @State private var currentStepIndex = 0
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Bar
                ProgressView(value: Double(currentStepIndex), total: Double(max(1, recipe.steps.count)))
                    .tint(.themePink)
                    .background(Color.gray.opacity(0.2))
                    .padding(.horizontal)
                    .padding(.top, 10)
                
                TabView(selection: $currentStepIndex) {
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        VStack(spacing: 0) {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 24) {
                                    HStack(alignment: .top) {
                                        Text(String(format: "%02d", index + 1))
                                            .font(.system(size: 64, weight: .heavy, design: .rounded))
                                            .foregroundColor(.themePink.opacity(0.3))
                                        Spacer()
                                        Image(systemName: "sparkles")
                                            .font(.title)
                                            .foregroundColor(.themeOrange)
                                    }
                                    
                                    Text(step.instruction)
                                        .font(.system(size: 24, weight: .medium, design: .serif))
                                        .lineSpacing(8)
                                        .foregroundColor(.primary)
                                        
                                    if let tip = step.aiTip {
                                        HStack(alignment: .top, spacing: 16) {
                                            Image(systemName: "lightbulb.fill")
                                                .foregroundColor(.yellow)
                                                .font(.title2)
                                            Text(tip)
                                                .font(.subheadline)
                                                .foregroundColor(.primary)
                                        }
                                        .padding(20)
                                        .background(Color.yellow.opacity(0.15))
                                        .cornerRadius(16)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
                                    }
                                    
                                    Spacer(minLength: 40)
                                    
                                    Button(action: {
                                        HapticManager.shared.impact(style: .medium)
                                        currentStepForCamera = step
                                        showCameraScanner = true
                                    }) {
                                        HStack {
                                            Image(systemName: "viewfinder")
                                                .font(.title2)
                                            Text("AI Camera Check")
                                                .font(.headline)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 18)
                                        .background(
                                            LinearGradient(colors: [.themePink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .clipShape(Capsule())
                                        .shadow(color: .themePink.opacity(0.4), radius: 10, y: 5)
                                    }
                                }
                                .padding(24)
                            }
                        }
                        .tag(index)
                    }
                    
                    // Plating step
                    VStack {
                        ScrollView {
                            VStack(alignment: .center, spacing: 24) {
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 80))
                                    .foregroundColor(.themeOrange)
                                    .padding(.top, 40)
                                
                                Text("Final Touch")
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                
                                Text(recipe.platingTip)
                                    .font(.system(size: 20, weight: .regular, design: .serif))
                                    .lineSpacing(8)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    
                                Spacer(minLength: 60)
                                
                                Button(action: {
                                    HapticManager.shared.impact(style: .rigid)
                                    isFlowPresented = false
                                }) {
                                    Text("Bon Appétit!")
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 20)
                                        .background(Color.green)
                                        .clipShape(Capsule())
                                        .shadow(color: .green.opacity(0.4), radius: 10, y: 5)
                                }
                            }
                            .padding(24)
                        }
                    }
                    .tag(recipe.steps.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationTitle("AI Chef")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCameraScanner) {
            if let step = currentStepForCamera { AICameraScannerView(step: step, isPresented: $showCameraScanner) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    HapticManager.shared.impact(style: .rigid)
                    isFlowPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.title2)
                }
            }
        }
    }
}

struct AICameraScannerView: View {
    let step: RecipeStep
    @Binding var isPresented: Bool
    @State private var isAnalyzing = false
    @State private var showResult = false
    @State private var aiVerdict = ""
    @State private var isSuccess = true
    @State private var laserOffset: CGFloat = -180
    
    let successPhrases = ["Идеально! Температура и цвет то что нужно.", "Специи легли отлично. Продолжай!", "Корочка схватилась правильно. Переходи к следующему шагу."]
    let errorPhrases = ["Маловато соли. Добавь еще щепотку!", "Сковорода недостаточно раскалена. Подожди 30 секунд.", "Цвет бледноват, дай блюду еще немного времени."]
    
    var body: some View {
        ZStack {
            // Blurred background mocking a live camera feed
            ZStack {
                Color.black.ignoresSafeArea()
                LinearGradient(colors: [.black, .themePink.opacity(0.3), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .blur(radius: 20)
                
                // Grid overlay
                VStack(spacing: 40) {
                    ForEach(0..<10, id: \.self) { _ in
                        Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                    }
                }
            }
            
            VStack {
                HStack { 
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    Spacer() 
                }
                .padding()
                
                Spacer()
                
                // Scanner Box
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [10, 10]))
                        .frame(width: 320, height: 400)
                    
                    // Laser Animation
                    if isAnalyzing {
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, .themePink, .clear], startPoint: .top, endPoint: .bottom))
                            .frame(width: 320, height: 40)
                            .offset(y: laserOffset)
                            .shadow(color: .themePink, radius: 20)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                    laserOffset = 180
                                }
                            }
                    }
                    
                    if !isAnalyzing && !showResult {
                        Text("Наведи камеру на блюдо")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.black.opacity(0.6)))
                    }
                }
                
                Spacer()
                
                if !isAnalyzing && !showResult {
                    Button(action: takePhoto) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.8), lineWidth: 6).frame(width: 80, height: 80)
                            Circle().fill(Color.white).frame(width: 66, height: 66)
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
            
            // Result Bottom Sheet
            if showResult {
                VStack {
                    Spacer()
                    VStack(spacing: 24) {
                        HStack {
                            Image(systemName: isSuccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(isSuccess ? .green : .themeOrange)
                            Spacer()
                        }
                        
                        Text(aiVerdict)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Button(action: { isPresented = false }) {
                            Text(isSuccess ? "Понял" : "Ясно")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isSuccess ? Color.green : Color.themeOrange)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 10)
                    }
                    .padding(32)
                    .background(Color.themeBg)
                    .cornerRadius(32)
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(2)
            }
        }
    }
    
    func takePhoto() {
        HapticManager.shared.impact(style: .rigid)
        withAnimation(.easeInOut) {
            isAnalyzing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAnalyzing = false
                showResult = true
                isSuccess = Bool.random()
                aiVerdict = isSuccess ? successPhrases.randomElement()! : errorPhrases.randomElement()!
            }
            HapticManager.shared.impact(style: .medium)
        }
    }
}
