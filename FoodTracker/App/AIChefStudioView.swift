//
//  AIChefStudioView.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 1.05.26.
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - 🎨 Вспомогательные визуальные элементы (Shimmer & Image)
struct ShimmerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            
            ZStack {
                Color.primary.opacity(0.04)
                
                Color.white
                    .opacity(0.15)
                    .mask(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.4), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: width * 1.5)
                            .offset(x: -width + (width * 2) * phase)
                    )
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1.0
                }
            }
        }
    }
}

struct RecipeImageView: View {
    let imageString: String
    let fallbackSystemName: String
    
    var body: some View {
        if let localAsset = FoodCoverAssets.assetName(for: imageString) {
            Image(localAsset)
                .resizable()
                .scaledToFill()
        } else if let url = URL(string: imageString), imageString.hasPrefix("http") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ShimmerView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    FallbackView
                @unknown default:
                    FallbackView
                }
            }
        } else {
            FallbackView
        }
    }
    
    private var FallbackView: some View {
        ZStack {
            LinearGradient(
                colors: [.themePink.opacity(0.12), .themeOrange.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: fallbackSystemName)
                .font(.system(size: 26))
                .foregroundColor(.themePink)
        }
    }
}

// MARK: - 👨‍🍳 Главный Экран
struct AIChefStudioView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppStateManager.self) private var appState
    @Query private var users: [User]
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]
    @State private var currentDayStart = Calendar.current.startOfDay(for: Date())
    @Query(sort: \CustomRecipe.name) private var customRecipes: [CustomRecipe]
    @Query(sort: \WeeklyMealPlan.createdDate, order: .reverse) private var savedPlans: [WeeklyMealPlan]

    @State private var recipeLoader = RecipeDataLoader.shared
    @State private var searchText = ""
    @State private var showAIAssistantFlow = false
    @State private var showSmartBuilder = false
    @State private var selectedSavedPlan: WeeklyMealPlan? = nil
    @State private var isGeneratingAIRecipe = false
    @State private var recipeGenerationTask: Task<Void, Never>? = nil
    @State private var generatedAIRecipe: AIChefRecipe? = nil
    @State private var generationError: String? = nil
    @State private var pendingChefQuery: String? = nil
    @State private var showAIConsentSheet = false

    @State private var bgPhase = 0.0

    private var currentUser: User? { users.first }

    private var todaySummary: DailySummary? {
        summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: currentDayStart) })
    }

    private var remaining: NutritionMath.RemainingMacros {
        NutritionMath.remainingMacros(user: currentUser, summary: todaySummary)
    }

    private var allRecipes: [AIChefRecipe] {
        let custom = customRecipes.map { $0.toAIChefRecipe() }
        let library = recipeLoader.recipes.map { $0.toAIChefRecipe() }
        return custom + library
    }

    var filteredRecipes: [AIChefRecipe] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return allRecipes
        }
        return allRecipes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var suggestedRecipes: [AIChefRecipe] {
        let ceiling = max(remaining.calories + 150, 250)
        let matching = allRecipes.filter { $0.calories > 0 && $0.calories <= ceiling }
        let pool = matching.isEmpty ? allRecipes : matching
        return Array(
            pool.sorted { lhs, rhs in
                abs(lhs.calories - remaining.calories) < abs(rhs.calories - remaining.calories)
            }.prefix(12)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic Ambient Aurora Background
                DynamicAuroraBackgroundView(paletteTrigger: appState.selectedTab, tabTag: 2)
                    .allowsHitTesting(false)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // MARK: - AI Chef Studio Editorial Photo Deck
                        HStack(spacing: 12) {
                            // 1. AI Vision Cooking (Camera / Step-by-Step)
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                showAIAssistantFlow = true
                            }) {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        HStack(spacing: 5) {
                                            Image(systemName: "camera.viewfinder")
                                                .font(.system(size: 11, weight: .bold))
                                            Text("AI Assistant")
                                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                                .tracking(0.6)
                                                .textCase(.uppercase)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(red: 0.10, green: 0.72, blue: 0.50).opacity(0.88))
                                        .clipShape(Capsule())

                                        Spacer()

                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.45))
                                                .frame(width: 26, height: 26)
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Try AI Cooking")
                                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Text("Scan Food or Menu with AI")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.84))
                                            .lineLimit(1)
                                    }
                                }
                                .padding(13)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 160)
                                .background {
                                    ZStack {
                                        GeometryReader { geo in
                                            Image("chef_card_cooking")
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: geo.size.width, height: geo.size.height)
                                                .clipped()
                                        }
                                        LinearGradient(
                                            stops: [
                                                .init(color: Color.black.opacity(0.18), location: 0.0),
                                                .init(color: Color.black.opacity(0.42), location: 0.48),
                                                .init(color: Color.black.opacity(0.86), location: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    }
                                }
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.16), radius: 10, y: 5)
                            }
                            .buttonStyle(BounceButtonStyle())
                            .accessibilityIdentifier("chef_studio_camera_action")

                            // 2. 7-Day Meal Plan Builder
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                showSmartBuilder = true
                            }) {
                                VStack(alignment: .leading, spacing: 0) {
                                    HStack {
                                        HStack(spacing: 5) {
                                            Image(systemName: "calendar")
                                                .font(.system(size: 11, weight: .bold))
                                            Text("AI Menu Builder")
                                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                                .tracking(0.6)
                                                .textCase(.uppercase)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(red: 0.42, green: 0.38, blue: 0.85).opacity(0.88))
                                        .clipShape(Capsule())

                                        Spacer()

                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.45))
                                                .frame(width: 26, height: 26)
                                            Image(systemName: "arrow.up.right")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }

                                    Spacer()

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Create 7-Day Menu")
                                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Text("Fits your daily targets")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.84))
                                            .lineLimit(1)
                                    }
                                }
                                .padding(13)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(height: 160)
                                .background {
                                    ZStack {
                                        GeometryReader { geo in
                                            Image("chef_card_builder")
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: geo.size.width, height: geo.size.height)
                                                .clipped()
                                        }
                                        LinearGradient(
                                            stops: [
                                                .init(color: Color.black.opacity(0.18), location: 0.0),
                                                .init(color: Color.black.opacity(0.42), location: 0.48),
                                                .init(color: Color.black.opacity(0.86), location: 1.0)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    }
                                }
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.16), radius: 10, y: 5)
                            }
                            .buttonStyle(BounceButtonStyle())
                            .accessibilityIdentifier("chef_studio_builder_action")
                        }
                        .padding(.horizontal)

                        if !savedPlans.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Saved 7-Day Plans")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(savedPlans) { plan in
                                            Button {
                                                HapticManager.shared.impact(style: .light)
                                                selectedSavedPlan = plan
                                            } label: {
                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "calendar")
                                                            .foregroundColor(themeManager.current.primaryAccent)
                                                        Text(LocalizedStringKey(plan.dietType))
                                                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                            .foregroundColor(.primary)
                                                            .lineLimit(1)
                                                    }
                                                    Text("\(plan.targetCalories) kcal/day")
                                                        .font(.caption.bold())
                                                        .foregroundColor(themeManager.current.primaryAccent)
                                                    Text(plan.createdDate, format: .dateTime.day().month(.abbreviated))
                                                        .font(.caption2)
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding(14)
                                                .frame(width: 170, alignment: .leading)
                                                .background(.ultraThinMaterial)
                                                .cornerRadius(18)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .stroke(themeManager.current.primaryAccent.opacity(0.2), lineWidth: 1)
                                                )
                                            }
                                            .buttonStyle(BounceButtonStyle())
                                            .contextMenu {
                                                Button(role: .destructive) {
                                                    context.delete(plan)
                                                    try? context.save()
                                                } label: {
                                                    Label("Delete Plan", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // 2. ВИДЖЕТ МАКРОСОВ
                        DailyMacroWidget(
                            calories: remaining.calories,
                            protein: remaining.protein,
                            fat: remaining.fat,
                            carbs: remaining.carbs,
                            maxProtein: max(Int(currentUser?.targetProtein ?? 120), 1),
                            maxFat: max(Int(currentUser?.targetFats ?? 70), 1),
                            maxCarbs: max(Int(currentUser?.targetCarbs ?? 250), 1)
                        )
                        
                        // 3. ПОИСК (Glassmorphic)
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(themeManager.current.primaryAccent)
                            
                            TextField("Search dishes...", text: $searchText)
                                .font(.system(.body, design: .rounded))
                            
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .padding(14)
                        .background(
                            ZStack {
                                Color.primary.opacity(0.01)
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(.ultraThinMaterial)
                            }
                        )
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            themeManager.current.primaryAccent.opacity(0.2),
                                            themeManager.current.secondaryAccent.opacity(0.05)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: themeManager.current.primaryAccent.opacity(0.04), radius: 6, x: 0, y: 3)
                        .padding(.horizontal)
                        
                        // 4. КОНТЕНТ ПОД ПОИСКОМ
                        if !searchText.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(filteredRecipes) { recipe in
                                    NavigationLink(destination: RecipeDetailAIView(recipe: recipe)) {
                                        SearchResultRow(recipe: recipe)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                Button {
                                    generateCustomRecipe(named: searchText)
                                } label: {
                                    HStack(spacing: 12) {
                                        if isGeneratingAIRecipe {
                                            ProgressView().tint(.white)
                                        } else {
                                            Image(systemName: "wand.and.stars")
                                                .foregroundColor(.white)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(isGeneratingAIRecipe ? "AI Chef is crafting a recipe..." : "Ask AI Chef to cook \"\(searchText)\"")
                                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("Tailored to \(remaining.calories) kcal remaining")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.85))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(14)
                                    .background(themeManager.current.primaryGradient)
                                    .cornerRadius(18)
                                }
                                .disabled(isGeneratingAIRecipe)
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("AI picked for your macros:")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(suggestedRecipes) { recipe in
                                            NavigationLink(destination: RecipeDetailAIView(recipe: recipe)) {
                                                RecipeCardView(recipe: recipe)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        
                        // 5. МЕДИЦИНСКИЙ ДИСКЛЕЙМЕР
                        Text("FoodTracker AI provides general nutritional information. It is not a substitute for professional medical advice, diagnosis, or treatment.")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.top, 16)
                            
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("AI Chef")
            .onAppear {
                TrackingManager.shared.track(.featureDiscovered(feature: "ai_chef_studio"))
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    bgPhase = 1.0
                }
            }
            .fullScreenCover(isPresented: $showAIAssistantFlow) {
                AIAssistantFlowView(
                    isPresented: $showAIAssistantFlow,
                    recipes: allRecipes,
                    remainingCalories: remaining.calories,
                    activeDiet: currentUser?.activeDietPlan?.name ?? "Balanced"
                )
            }
            .sheet(isPresented: $showSmartBuilder) {
                SmartPlanBuilderFlow()
            }
            .sheet(item: $selectedSavedPlan) { plan in
                NavigationStack {
                    WeeklyPlanOverview(plan: plan) {
                        selectedSavedPlan = nil
                    }
                }
            }
            .navigationDestination(item: $generatedAIRecipe) { recipe in
                RecipeDetailAIView(recipe: recipe)
            }
            .alert(
                "AI Chef",
                isPresented: Binding(
                    get: { generationError != nil },
                    set: { if !$0 { generationError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { generationError = nil }
            } message: {
                Text(generationError ?? "")
            }
            .sheet(isPresented: $showAIConsentSheet) {
                AIPhotoConsentSheet(
                    onAllow: {
                        if let q = pendingChefQuery {
                            pendingChefQuery = nil
                            generateCustomRecipe(named: q)
                        }
                    },
                    onDecline: {
                        pendingChefQuery = nil
                    }
                )
            }
            .onDisappear {
                recipeGenerationTask?.cancel()
                recipeGenerationTask = nil
                isGeneratingAIRecipe = false
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    currentDayStart = Calendar.current.startOfDay(for: Date())
                }
            }
        }
    }

    private func generateCustomRecipe(named query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isGeneratingAIRecipe else { return }
        guard AIPhotoConsentManager.shared.hasConsented else {
            pendingChefQuery = trimmed
            showAIConsentSheet = true
            return
        }
        isGeneratingAIRecipe = true
        let budget = remaining.calories > 0 ? remaining.calories : 500
        let diet = currentUser?.activeDietKey ?? "Balanced"
        recipeGenerationTask?.cancel()
        recipeGenerationTask = Task {
            let recipe = await AINutritionService.shared.generateChefRecipe(
                dishQuery: trimmed,
                remainingCalories: budget,
                activeDiet: diet
            )
            await MainActor.run {
                isGeneratingAIRecipe = false
                guard !Task.isCancelled else { return }
                if let recipe {
                    generatedAIRecipe = recipe
                } else {
                    generationError = GeminiProxyClient.consumeRateLimitAlertMessage()
                        ?? AINutritionService.shared.lastUserFacingError
                        ?? String(localized: "Could not generate that recipe right now. Please try again.")
                }
            }
        }
    }
}

// MARK: - 📊 ВИДЖЕТ МАКРОСОВ
struct DailyMacroWidget: View {
    let calories: Int
    let protein: Int
    let fat: Int
    let carbs: Int
    var maxProtein: Int = 120
    var maxFat: Int = 70
    var maxCarbs: Int = 250
    
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remaining today")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(calories)")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Text("kcal")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 38))
                    .foregroundColor(themeManager.current.primaryAccent)
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.35), radius: 5)
            }
            
            HStack(spacing: 10) {
                MacroPillView(title: String(localized: "Protein"), value: String(localized: "\(protein) g"), amount: protein, maxAmount: max(maxProtein, 1), color: .themePeach)
                MacroPillView(title: String(localized: "Fat"), value: String(localized: "\(fat) g"), amount: fat, maxAmount: max(maxFat, 1), color: .themeYellow)
                MacroPillView(title: String(localized: "Carbs"), value: String(localized: "\(carbs) g"), amount: carbs, maxAmount: max(maxCarbs, 1), color: .drinkWater)
            }
        }
        .padding(20)
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
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 5, y: 3)
        .padding(.horizontal)
    }
}

struct MacroPillView: View {
    let title: String
    let value: String
    let amount: Int
    let maxAmount: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            // Mini progress indicator
            GeometryReader { geo in
                let width = geo.size.width
                let fillWidth = max(min(width * CGFloat(amount) / CGFloat(maxAmount), width), 0)
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.04))
                    
                    Capsule()
                        .fill(LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: fillWidth)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(Color.primary.opacity(0.01))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct SearchResultRow: View {
    let recipe: AIChefRecipe
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        HStack(spacing: 16) {
            RecipeImageView(imageString: recipe.heroImage, fallbackSystemName: "fork.knife")
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Text("\(recipe.calories) kcal")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.current.primaryAccent)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.cookTime) min")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(themeManager.current.primaryAccent.opacity(0.6))
                .padding(8)
                .background(Color.primary.opacity(0.02))
                .clipShape(Circle())
        }
        .padding(12)
        .background(
            ZStack {
                Color.primary.opacity(0.01)
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
            }
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

struct RecipeCardView: View {
    let recipe: AIChefRecipe
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                // Cover Image
                RecipeImageView(imageString: recipe.heroImage, fallbackSystemName: "fork.knife")
                    .frame(width: 200, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Cook time overlay
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(recipe.cookTime) min")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(10)
            }
            .frame(width: 200, height: 140)
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(recipe.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(recipe.calories) kcal")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(themeManager.current.primaryAccent)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.themeYellow)
                        Text(String(format: "%d", recipe.difficulty))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 200)
    }
}

// MARK: - 📖 Экран Деталей Рецепта
struct RecipeDetailAIView: View {
    let recipe: AIChefRecipe
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @State private var isCookingModeActive = false
    @State private var didLogToDiary = false
    @State private var didSaveToMyRecipes = false
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Image Card
                ZStack(alignment: .bottomLeading) {
                    RecipeImageView(imageString: recipe.heroImage, fallbackSystemName: "fork.knife")
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .cornerRadius(28)
                        )
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recipe.title)
                            .font(.system(.title2, design: .rounded, weight: .black))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .padding(20)
                }
                .padding(.horizontal)
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 5)
                
                // Cooking Stats Panel
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.headline)
                            .foregroundColor(themeManager.current.primaryAccent)
                        Text("\(recipe.cookTime) min")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(16)
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= recipe.difficulty ? "star.fill" : "star")
                                    .font(.system(size: 8))
                                    .foregroundColor(.themeYellow)
                            }
                        }
                        Text("Difficulty")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        isCookingModeActive = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                            Text("Start Cooking")
                                .font(.system(.headline, design: .rounded, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(themeManager.current.primaryGradient)
                        .cornerRadius(20)
                        .shadow(color: themeManager.current.primaryAccent.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(BounceButtonStyle())

                    Button(action: logRecipeToToday) {
                        HStack(spacing: 8) {
                            Image(systemName: didLogToDiary ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.subheadline.bold())
                            Text(didLogToDiary ? "Added to Today's Diary" : "Log to Today's Diary (\(recipe.calories) kcal)")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                        }
                        .foregroundColor(didLogToDiary ? .green : themeManager.current.primaryAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(didLogToDiary ? Color.green.opacity(0.1) : themeManager.current.primaryAccent.opacity(0.1))
                        .cornerRadius(16)
                    }
                    .disabled(didLogToDiary)

                    Button(action: saveToMyRecipes) {
                        HStack(spacing: 8) {
                            Image(systemName: didSaveToMyRecipes ? "bookmark.fill" : "bookmark")
                                .font(.subheadline.bold())
                            Text(didSaveToMyRecipes ? "Saved to My Recipes" : "Save to My Recipes")
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                        }
                        .foregroundColor(didSaveToMyRecipes ? .green : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .disabled(didSaveToMyRecipes)
                }
                .padding(.horizontal)
                
                // Ingredients Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .foregroundColor(themeManager.current.primaryAccent)
                        Text("Ingredients")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            HStack(spacing: 10) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(themeManager.current.primaryAccent)
                                Text(ingredient)
                                    .font(.system(.body, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal)
                
                // History Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "book.pages.fill")
                            .foregroundColor(themeManager.current.primaryAccent)
                        Text("Dish History")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }
                    
                    Text(recipe.history)
                        .font(.system(.body, design: .rounded))
                        .lineSpacing(5)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal)
                
                // Plating tip "Michelin Special"
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundColor(.themeOrange)
                        Text("Chef's Plating Tip")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.themeOrange)
                    }
                    
                    Text(recipe.platingTip)
                        .font(.system(.body, design: .rounded).italic())
                        .lineSpacing(5)
                        .foregroundColor(.primary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.themeOrange.opacity(0.08))
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.themeOrange.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal)
                
            }
            .padding(.bottom, 40)
        }
        .background(
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                Circle()
                    .fill(themeManager.current.primaryAccent.opacity(0.12))
                    .frame(width: 200, height: 200)
                    .blur(radius: 50)
                    .offset(x: -120, y: -200)
                
                Circle()
                    .fill(themeManager.current.secondaryAccent.opacity(0.10))
                    .frame(width: 250, height: 250)
                    .blur(radius: 60)
                    .offset(x: 120, y: 150)
            }
        )
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isCookingModeActive) {
            InteractiveCookingView(recipe: recipe, isPresented: $isCookingModeActive)
        }
    }

    private func logRecipeToToday() {
        AIChefRecipePersistence.logRecipeToToday(recipe, in: context, users: users)
        withAnimation { didLogToDiary = true }
    }

    private func saveToMyRecipes() {
        guard !didSaveToMyRecipes else { return }
        AIChefRecipePersistence.saveToMyRecipes(recipe, in: context)
        withAnimation { didSaveToMyRecipes = true }
    }
}

@MainActor
enum AIChefRecipePersistence {
    static func logRecipeToToday(_ recipe: AIChefRecipe, in context: ModelContext, users: [User]) {
        HapticManager.shared.notification(type: .success)
        let summary = DailySummary.fetchOrCreate(for: Date(), in: context)
        let hour = Calendar.current.component(.hour, from: Date())
        let mealTitle = hour < 11 ? "Breakfast" : (hour < 16 ? "Lunch" : (hour < 21 ? "Dinner" : "Snack"))
        let now = Date()
        let micros = MicronutrientEstimator.estimate(
            name: recipe.title,
            calories: recipe.calories,
            protein: Double(recipe.protein),
            fat: Double(recipe.fat),
            carbs: Double(recipe.carbs),
            weight: 300.0
        )
        let food = FoodItem(
            name: recipe.title,
            weight: 300,
            calories: recipe.calories,
            protein: Double(recipe.protein),
            fats: Double(recipe.fat),
            carbs: Double(recipe.carbs),
            omega3: micros.omega3,
            calcium: micros.calcium,
            potassium: micros.potassium,
            magnesium: micros.magnesium,
            iron: micros.iron,
            vitaminC: micros.vitaminC,
            vitaminD: micros.vitaminD
        )
        context.insert(food)
        if let existing = (summary.meals ?? []).first(where: { DailySummary.canonicalMealSlot($0.title) == mealTitle }) {
            existing.addFoodItem(food)
            existing.date = now
        } else {
            let meal = Meal(title: mealTitle, date: now, foodItems: [food])
            context.insert(meal)
            summary.addMeal(meal)
        }
        try? context.save()
        WidgetReloader.reloadAll()
        AppReviewManager.shared.userDidLogMeal()
        if users.first?.isHealthKitEnabled == true && recipe.calories > 0 {
            let cals = recipe.calories
            let container = context.container
            Task { @MainActor in
                if let uuid = await HealthKitManager.shared.saveDietaryEnergy(calories: cals, date: now) {
                    food.healthKitSampleID = uuid.uuidString
                    try? container.mainContext.save()
                }
            }
        }
    }

    static func saveToMyRecipes(_ recipe: AIChefRecipe, in context: ModelContext) {
        HapticManager.shared.notification(type: .success)
        let micros = MicronutrientEstimator.estimate(
            name: recipe.title,
            calories: recipe.calories,
            protein: Double(recipe.protein),
            fat: Double(recipe.fat),
            carbs: Double(recipe.carbs),
            weight: 300.0
        )
        let food = FoodItem(
            name: recipe.title,
            weight: 300,
            calories: recipe.calories,
            protein: Double(recipe.protein),
            fats: Double(recipe.fat),
            carbs: Double(recipe.carbs),
            omega3: micros.omega3,
            calcium: micros.calcium,
            potassium: micros.potassium,
            magnesium: micros.magnesium,
            iron: micros.iron,
            vitaminC: micros.vitaminC,
            vitaminD: micros.vitaminD
        )
        context.insert(food)
        let difficultyText = recipe.difficulty <= 2 ? "Easy" : (recipe.difficulty == 3 ? "Medium" : "Hard")
        let custom = CustomRecipe(
            name: recipe.title,
            info: recipe.history,
            foodItems: [food],
            cookingTime: recipe.cookTime,
            difficulty: difficultyText,
            servings: 1,
            directions: recipe.steps.map(\.instruction)
        )
        context.insert(custom)
        try? context.save()
    }
}

// MARK: - 👩‍🍳 Пошаговый режим готовки
struct InteractiveCookingView: View {
    let recipe: AIChefRecipe
    @Binding var isPresented: Bool
    @State private var visibleStepsCount: Int
    
    init(recipe: AIChefRecipe, isPresented: Binding<Bool>, startWithAllSteps: Bool = false) {
        self.recipe = recipe
        self._isPresented = isPresented
        let initialCount = recipe.steps.isEmpty ? 0 : (startWithAllSteps ? recipe.steps.count : 1)
        self._visibleStepsCount = State(initialValue: initialCount)
    }

    private var clampedVisibleCount: Int {
        min(visibleStepsCount, recipe.steps.count)
    }
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button(action: { isPresented = false }) { Image(systemName: "xmark.circle.fill").font(.title).foregroundColor(.gray.opacity(0.5)) }
                    Spacer(); Text("Cooking: \(recipe.title)").font(.headline); Spacer()
                    Image(systemName: "eye.fill").foregroundColor(.themePink.opacity(0.6))
                }.padding()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(0..<clampedVisibleCount, id: \.self) { index in
                                CookingStepRow(step: recipe.steps[index], stepNumber: index + 1).id(index).transition(.move(edge: .top).combined(with: .opacity))
                            }
                            
                            if clampedVisibleCount >= recipe.steps.count {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack { Image(systemName: "sparkles").foregroundColor(.themeOrange); Text("Final Touch: Plating").font(.headline) }
                                    Text(recipe.platingTip).font(.body.italic()).foregroundColor(.primary).lineSpacing(4)
                                }
                                .padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.themeOrange.opacity(0.1)).cornerRadius(16).padding(.horizontal)
                                .transition(.scale.combined(with: .opacity))
                                .id("platingTip")
                            }
                        }.padding(.top, 10).padding(.bottom, 120)
                    }.onChange(of: visibleStepsCount) { _, newValue in
                        withAnimation {
                            if newValue >= recipe.steps.count {
                                proxy.scrollTo("platingTip", anchor: .bottom)
                            } else if newValue > 0 {
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
                        Text(clampedVisibleCount >= recipe.steps.count ? "Finish & Enjoy!" : "Next Step")
                        if clampedVisibleCount < recipe.steps.count { Image(systemName: "arrow.down") }
                    }.font(.title3.bold()).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 20).background(Color.themePink).cornerRadius(24)
                }.padding(.horizontal).padding(.bottom, 20)
            }
        }
    }
    private func nextStep() {
        HapticManager.shared.impact(style: .rigid)
        if clampedVisibleCount < recipe.steps.count { withAnimation(.spring()) { visibleStepsCount = clampedVisibleCount + 1 } } else { isPresented = false }
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
    var recipes: [AIChefRecipe] = []
    var remainingCalories: Int = 500
    var activeDiet: String = "Balanced"

    @State private var searchAgentText = ""
    @State private var selectedRecipe: AIChefRecipe? = nil
    @State private var isPrepPhase = false
    @State private var isGeneratingAI = false
    @State private var assistantGenerationTask: Task<Void, Never>? = nil
    @State private var generationError: String? = nil
    @State private var pendingAssistantQuery: String? = nil
    @State private var showAIConsentSheet = false

    var agentResults: [AIChefRecipe] {
        let trimmed = searchAgentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return Array(recipes.prefix(20))
        }
        return recipes.filter { $0.title.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicAuroraBackgroundView(tabTag: 2)
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Editorial Hero Header
                        ZStack(alignment: .bottomLeading) {
                            GeometryReader { geo in
                                Image("chef_card_cooking")
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: geo.size.width, height: geo.size.height)
                                    .clipped()
                            }
                            LinearGradient(
                                stops: [
                                    .init(color: Color.black.opacity(0.20), location: 0.0),
                                    .init(color: Color.black.opacity(0.78), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text("What shall we cook with AI?")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                Text("Fits ~\(max(remainingCalories, 400)) kcal • \(activeDiet)")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.84))
                            }
                            .padding(16)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 128)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        .padding(.top, 8)

                        // Clean Adaptive Search Field
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("For example: Ribeye...", text: $searchAgentText)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                            if !searchAgentText.isEmpty {
                                Button(action: { searchAgentText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal)

                        let trimmed = searchAgentText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            Button {
                                generateRecipeForAssistant(query: trimmed)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(red: 0.10, green: 0.72, blue: 0.50).opacity(0.18))
                                            .frame(width: 38, height: 38)
                                        if isGeneratingAI {
                                            ProgressView()
                                                .tint(Color(red: 0.10, green: 0.72, blue: 0.50))
                                        } else {
                                            Image(systemName: "flame.fill")
                                                .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isGeneratingAI ? "AI Chef is creating your recipe..." : "Generate AI step-by-step for \"\(trimmed)\"")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                            .multilineTextAlignment(.leading)
                                        Text("Fits ~\(max(remainingCalories, 400)) kcal • \(activeDiet)")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(14)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(Color(red: 0.10, green: 0.72, blue: 0.50).opacity(0.35), lineWidth: 1.2)
                                )
                            }
                            .buttonStyle(BounceButtonStyle())
                            .disabled(isGeneratingAI)
                            .padding(.horizontal)
                        }

                        VStack(spacing: 10) {
                            ForEach(agentResults) { recipe in
                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    selectedRecipe = recipe; isPrepPhase = true
                                }) {
                                    SearchResultRow(recipe: recipe)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)

                        // МЕДИЦИНСКИЙ ДИСКЛЕЙМЕР
                        Text("FoodTracker AI provides general nutritional information. It is not a substitute for professional medical advice, diagnosis, or treatment.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            .padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle("AI Cooking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .navigationDestination(isPresented: $isPrepPhase) { if let r = selectedRecipe { PrepChecklistView(recipe: r, isFlowPresented: $isPresented) } }
            .alert(
                "AI Chef",
                isPresented: Binding(
                    get: { generationError != nil },
                    set: { if !$0 { generationError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { generationError = nil }
            } message: {
                Text(generationError ?? "")
            }
            .onDisappear {
                assistantGenerationTask?.cancel()
                assistantGenerationTask = nil
                isGeneratingAI = false
            }
            .sheet(isPresented: $showAIConsentSheet) {
                AIPhotoConsentSheet(
                    onAllow: {
                        if let q = pendingAssistantQuery {
                            pendingAssistantQuery = nil
                            generateRecipeForAssistant(query: q)
                        }
                    },
                    onDecline: {
                        pendingAssistantQuery = nil
                    }
                )
            }
        }
    }

    private func generateRecipeForAssistant(query: String) {
        guard !isGeneratingAI else { return }
        guard AIPhotoConsentManager.shared.hasConsented else {
            pendingAssistantQuery = query
            showAIConsentSheet = true
            return
        }
        isGeneratingAI = true
        assistantGenerationTask?.cancel()
        assistantGenerationTask = Task {
            let budget = max(remainingCalories, 400)
            let recipe = await AINutritionService.shared.generateChefRecipe(
                dishQuery: query,
                remainingCalories: budget,
                activeDiet: activeDiet
            )
            await MainActor.run {
                isGeneratingAI = false
                guard !Task.isCancelled else { return }
                if let recipe {
                    selectedRecipe = recipe
                    isPrepPhase = true
                } else {
                    generationError = GeminiProxyClient.consumeRateLimitAlertMessage()
                        ?? AINutritionService.shared.lastUserFacingError
                        ?? String(localized: "Could not generate that recipe right now. Please try again.")
                }
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
        ZStack {
            DynamicAuroraBackgroundView(tabTag: 0)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(recipe.title)
                            .font(.system(.title3, design: .rounded, weight: .heavy))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Spacer()
                        Text("\(checkedItems.count)/\(recipe.ingredients.count)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(allChecked ? Color(red: 0.10, green: 0.72, blue: 0.50) : .secondary)
                    }

                    Text("Check what you have on the counter")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    GeometryReader { geo in
                        let progress = recipe.ingredients.isEmpty ? 1.0 : Double(checkedItems.count) / Double(recipe.ingredients.count)
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 5)
                            Capsule()
                                .fill(Color(red: 0.10, green: 0.72, blue: 0.50))
                                .frame(width: max(6, geo.size.width * CGFloat(progress)), height: 5)
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: checkedItems.count)
                        }
                    }
                    .frame(height: 5)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(recipe.ingredients, id: \.self) { item in
                            let isChecked = checkedItems.contains(item)
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                    if isChecked { checkedItems.remove(item) } else { checkedItems.insert(item) }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isChecked ? Color(red: 0.10, green: 0.72, blue: 0.50) : .secondary.opacity(0.5))
                                        .font(.system(size: 22))
                                    Text(item)
                                        .font(.system(size: 15, weight: isChecked ? .medium : .semibold, design: .rounded))
                                        .strikethrough(isChecked, color: .secondary)
                                        .foregroundColor(isChecked ? .secondary : .primary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(isChecked ? Color(red: 0.10, green: 0.72, blue: 0.50).opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                Button(action: { HapticManager.shared.impact(style: .medium); isCookingPhase = true }) {
                    HStack(spacing: 8) {
                        Text(allChecked ? "All ready, let's start!" : "Continue")
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(allChecked ? Color(red: 0.10, green: 0.72, blue: 0.50) : Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .navigationTitle("Prep Ingredients")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isCookingPhase) { AgentCookingView(recipe: recipe, isFlowPresented: $isFlowPresented) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    HapticManager.shared.impact(style: .rigid)
                    isFlowPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
        }
    }
}

struct AgentCookingView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    let recipe: AIChefRecipe
    @Binding var isFlowPresented: Bool
    @State private var showCameraScanner = false
    @State private var currentStepForCamera: RecipeStep? = nil
    @State private var didLogToDiary = false
    @State private var didSaveToMyRecipes = false
    
    var body: some View {
        ZStack {
            DynamicAuroraBackgroundView(tabTag: 2)
                .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // Recipe Top Summary Card
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.title)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        HStack(spacing: 10) {
                            Label("\(recipe.calories) kcal", systemImage: "flame.fill")
                                .foregroundColor(.themeOrange)
                            Label("\(Int(recipe.protein))g P", systemImage: "leaf.fill")
                                .foregroundColor(Color(red: 0.10, green: 0.72, blue: 0.50))
                            Label("\(recipe.steps.count) steps", systemImage: "list.number")
                                .foregroundColor(.secondary)
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color(red: 0.10, green: 0.72, blue: 0.50))
                                    .clipShape(Circle())
                                Text("Step \(index + 1)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }

                            Text(step.instruction)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .lineSpacing(5)
                                .foregroundColor(.primary)

                            if let tip = step.aiTip {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.themeOrange)
                                        .padding(.top, 2)
                                    Text(tip)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.themeOrange.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            Button(action: {
                                HapticManager.shared.impact(style: .medium); currentStepForCamera = step; showCameraScanner = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.viewfinder")
                                    Text("Check this step with camera")
                                }
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(UIColor.tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                )
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
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "fork.knife")
                                .foregroundColor(.themeOrange)
                            Text("Final Touch: Plating")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                        }
                        Text(recipe.platingTip)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .lineSpacing(5)
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.themeOrange.opacity(0.24), lineWidth: 1)
                    )
                    .padding(.horizontal)

                    VStack(spacing: 10) {
                        Button {
                            AIChefRecipePersistence.logRecipeToToday(recipe, in: context, users: users)
                            withAnimation { didLogToDiary = true }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: didLogToDiary ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(didLogToDiary ? "Added to Today's Diary" : "Log to Today's Diary (\(recipe.calories) kcal)")
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(didLogToDiary ? Color(red: 0.10, green: 0.72, blue: 0.50) : Color.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .disabled(didLogToDiary)

                        Button {
                            guard !didSaveToMyRecipes else { return }
                            AIChefRecipePersistence.saveToMyRecipes(recipe, in: context)
                            withAnimation { didSaveToMyRecipes = true }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: didSaveToMyRecipes ? "bookmark.fill" : "bookmark")
                                Text(didSaveToMyRecipes ? "Saved to My Recipes" : "Save to My Recipes")
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(didSaveToMyRecipes ? Color(red: 0.10, green: 0.72, blue: 0.50) : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .disabled(didSaveToMyRecipes)
                    }
                    .padding(.horizontal)

                    Button("Finish Cooking") {
                        HapticManager.shared.impact(style: .rigid)
                        isFlowPresented = false
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .padding(.top, 16)
            }
        }
        .navigationTitle("AI Chef Watching")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showCameraScanner) {
            if let step = currentStepForCamera {
                AICameraScannerView(step: step, dishTitle: recipe.title, isPresented: $showCameraScanner)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    HapticManager.shared.impact(style: .rigid)
                    isFlowPresented = false
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
        }
    }
}

struct AICameraScannerView: View {
    let step: RecipeStep
    var dishTitle: String = ""
    @Binding var isPresented: Bool

    @Environment(\.scenePhase) private var scenePhase
    @State private var cameraManager = LiveFoodCameraManager()
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isAnalyzing = false
    @State private var isCapturingPhoto = false
    @State private var showResult = false
    @State private var aiVerdict = ""
    @State private var isSuccess = true
    @State private var evaluationError: String? = nil
    @State private var pendingConsentImage: UIImage? = nil
    @State private var showPhotoConsentSheet = false
    @State private var evaluationTask: Task<Void, Never>? = nil
    @State private var photoLoadTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !cameraManager.isCameraUnavailable && !cameraManager.isPermissionDenied {
                LiveCameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Button("Close") { isPresented = false }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                    Spacer()
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .disabled(showResult || isAnalyzing || isCapturingPhoto)
                }
                .padding()

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.45), lineWidth: 2)
                        .frame(width: 300, height: 380)
                        .background(Color.black.opacity(showResult || isAnalyzing || evaluationError != nil || cameraManager.isCameraUnavailable || cameraManager.isPermissionDenied ? 0.55 : 0.1).cornerRadius(24))

                    if isAnalyzing {
                        VStack(spacing: 12) {
                            ProgressView().tint(.white).scaleEffect(1.8)
                            Text("AI analyzing...").foregroundColor(.white).font(.headline)
                        }
                    } else if let error = evaluationError {
                        VStack(spacing: 14) {
                            Image(systemName: "wifi.exclamationmark")
                                .foregroundColor(.orange)
                                .font(.system(size: 46))
                            Text(error)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Try Again") {
                                resetForRetry()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.25))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                        }
                        .frame(width: 280)
                    } else if showResult {
                        VStack(spacing: 16) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isSuccess ? .green : .yellow)
                                .font(.system(size: 56))
                            Text(aiVerdict)
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            HStack(spacing: 12) {
                                Button("Try Again") { resetForRetry() }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.18))
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                                Button("Got it") { isPresented = false }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.themePink)
                                    .cornerRadius(12)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 280)
                    } else if cameraManager.isPermissionDenied {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.themeOrange)
                            Text("Camera access is needed to inspect cooking steps.")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                Link("Open Settings", destination: settingsURL)
                                    .font(.caption.bold())
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding()
                        .frame(width: 280)
                    } else if cameraManager.isCameraUnavailable {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.8))
                            Text("Camera unavailable on this device. Pick a photo from your library above.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(width: 280)
                    } else {
                        Text("Point the camera at the dish")
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.85))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.35))
                            .cornerRadius(10)
                    }
                }

                Spacer()

                if !isAnalyzing && !isCapturingPhoto && !showResult && evaluationError == nil && !cameraManager.isCameraUnavailable && !cameraManager.isPermissionDenied {
                    Button(action: capturePhoto) {
                        Circle().stroke(Color.white, lineWidth: 4).frame(width: 70, height: 70)
                            .overlay(Circle().fill(Color.white).frame(width: 60, height: 60))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            cameraManager.checkPermissionAndStart()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            isCapturingPhoto = false
            cameraManager.checkPermissionAndStart()
        }
        .onDisappear {
            evaluationTask?.cancel()
            evaluationTask = nil
            photoLoadTask?.cancel()
            photoLoadTask = nil
            isAnalyzing = false
            isCapturingPhoto = false
            cameraManager.stop()
        }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            isCapturingPhoto = false
            guard let img = newImage else { return }
            analyzeCapturedStepImage(img)
        }
        .onChange(of: cameraManager.captureError) { _, err in
            guard let err else { return }
            isCapturingPhoto = false
            cameraManager.captureError = nil
            evaluationError = err
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            selectedPhotoItem = nil
            photoLoadTask?.cancel()
            photoLoadTask = Task {
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      !Task.isCancelled,
                      let rawImg = UIImage(data: data) else {
                    if !Task.isCancelled {
                        await MainActor.run {
                            evaluationError = String(localized: "Could not load the selected photo. Please try another image.")
                        }
                    }
                    return
                }
                let img = await Task.detached(priority: .userInitiated) {
                    VertexAIManager.downsampledImage(rawImg, maxDimension: 1280)
                }.value
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    showResult = false
                    evaluationError = nil
                    analyzeCapturedStepImage(img)
                }
            }
        }
        .sheet(isPresented: $showPhotoConsentSheet) {
            AIPhotoConsentSheet(
                onAllow: {
                    showPhotoConsentSheet = false
                    if let image = pendingConsentImage {
                        pendingConsentImage = nil
                        performStepEvaluation(image)
                    }
                },
                onDecline: {
                    showPhotoConsentSheet = false
                    pendingConsentImage = nil
                    resetForRetry()
                }
            )
        }
    }

    private func capturePhoto() {
        guard !isCapturingPhoto, !isAnalyzing, cameraManager.isConfigured else { return }
        isCapturingPhoto = true
        HapticManager.shared.impact(style: .rigid)
        cameraManager.takePhoto()
    }

    private func resetForRetry() {
        evaluationTask?.cancel()
        evaluationTask = nil
        cameraManager.capturedImage = nil
        selectedPhotoItem = nil
        pendingConsentImage = nil
        isCapturingPhoto = false
        isAnalyzing = false
        showResult = false
        evaluationError = nil
    }

    private func analyzeCapturedStepImage(_ image: UIImage) {
        guard !isAnalyzing else { return }
        guard AIPhotoConsentManager.shared.hasConsented else {
            pendingConsentImage = image
            showPhotoConsentSheet = true
            return
        }
        performStepEvaluation(image)
    }

    private func performStepEvaluation(_ image: UIImage) {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        evaluationError = nil

        evaluationTask?.cancel()
        evaluationTask = Task {
            do {
                let evaluation = try await VertexAIManager.shared.evaluateCookingStep(
                    image: image,
                    dishTitle: dishTitle,
                    stepInstruction: step.instruction
                )
                guard !Task.isCancelled else {
                    await MainActor.run { isAnalyzing = false }
                    return
                }
                await MainActor.run {
                    isAnalyzing = false
                    showResult = true
                    isSuccess = evaluation.isGood
                    aiVerdict = evaluation.feedback
                    HapticManager.shared.notification(type: evaluation.isGood ? .success : .warning)
                }
            } catch is CancellationError {
                await MainActor.run {
                    isAnalyzing = false
                }
            } catch {
                guard !Task.isCancelled else {
                    await MainActor.run { isAnalyzing = false }
                    return
                }
                await MainActor.run {
                    isAnalyzing = false
                    evaluationError = GeminiProxyClient.consumeRateLimitAlertMessage()
                        ?? AINutritionService.userFacingErrorMessage(for: error)
                    HapticManager.shared.notification(type: .error)
                }
            }
        }
    }
}
