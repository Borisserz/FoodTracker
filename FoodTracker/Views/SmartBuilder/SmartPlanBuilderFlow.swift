import SwiftUI
import SwiftData
import Combine

enum SmartPlanBuilderConfig {
    static let dietTypes = ["Any", "Keto", "Vegan", "Paleo", "Mediterranean"]
    static let complexities = ["Fast (15m)", "Medium (30m)", "Chef (60m)"]
    static let defaultComplexity = "Medium (30m)"
}

struct SmartPlanBuilderFlow: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Query private var users: [User]
    
    @State private var currentStep = 0
    @State private var selectedDiet = "Any"
    @State private var targetCalories: Double = 2000
    @State private var complexity = SmartPlanBuilderConfig.defaultComplexity
    @State private var isGenerating = false
    @State private var generatedPlan: WeeklyMealPlan? = nil
    @State private var generationError: String? = nil
    @State private var generationTask: Task<Void, Never>? = nil
    @State private var showAIConsentSheet = false
    
    let dietTypes = SmartPlanBuilderConfig.dietTypes
    let complexities = SmartPlanBuilderConfig.complexities
    
    var body: some View {
        NavigationStack {
            ZStack {
                DynamicAuroraBackgroundView(paletteTrigger: currentStep, tabTag: 3)
                    .allowsHitTesting(false)
                
                if let plan = generatedPlan {
                    WeeklyPlanOverview(plan: plan) {
                        dismiss()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if isGenerating {
                    AIGenerationLoadingView(targetCalories: Int(targetCalories))
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        // Progress bar
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { step in
                                    Capsule()
                                        .fill(step <= currentStep ? themeManager.current.primaryAccent : Color.primary.opacity(0.12))
                                        .frame(height: 5)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentStep)
                                }
                            }
                            HStack {
                                Text("Step \(currentStep + 1) of 3")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        TabView(selection: $currentStep) {
                            dietStepView.tag(0)
                            calorieStepView.tag(1)
                            complexityStepView.tag(2)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.28), value: currentStep)
                        
                        HStack(spacing: 12) {
                            if currentStep > 0 {
                                Button(action: {
                                    HapticManager.shared.impact(style: .light)
                                    withAnimation { currentStep -= 1 }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 13, weight: .bold))
                                        Text(String(localized: "Back"))
                                    }
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 15)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                if currentStep < 2 {
                                    withAnimation { currentStep += 1 }
                                } else {
                                    startGeneration()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Text(currentStep < 2 ? String(localized: "Next") : String(localized: "Create Plan"))
                                    Image(systemName: currentStep < 2 ? "arrow.right" : "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 15)
                                .background(themeManager.current.primaryGradient)
                                .clipShape(Capsule())
                                .shadow(color: themeManager.current.primaryAccent.opacity(0.28), radius: 8, y: 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                    }
                }
            }
            .navigationTitle(isGenerating ? "" : String(localized: "Smart Builder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(generatedPlan != nil ? .hidden : .visible, for: .navigationBar)
            .interactiveDismissDisabled(isGenerating)
            .onDisappear {
                generationTask?.cancel()
                generationTask = nil
                isGenerating = false
            }
            .toolbar {
                if generatedPlan == nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(String(localized: "Cancel")) {
                            generationTask?.cancel()
                            generationTask = nil
                            isGenerating = false
                            dismiss()
                        }
                        .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                if let user = users.first, user.dailyCaloriesGoal > 0 {
                    targetCalories = Double(user.dailyCaloriesGoal)
                }
            }
            .alert(
                "Plan Generation Failed",
                isPresented: Binding(
                    get: { generationError != nil },
                    set: { if !$0 { generationError = nil } }
                )
            ) {
                Button("Try Again") {
                    generationError = nil
                    startGeneration()
                }
                Button("Cancel", role: .cancel) {
                    generationError = nil
                }
            } message: {
                Text(generationError ?? "")
            }
            .sheet(isPresented: $showAIConsentSheet) {
                AIPhotoConsentSheet(
                    onAllow: { startGeneration() },
                    onDecline: {}
                )
            }
        }
    }
    
    // MARK: - Steps
    
    private var dietStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Text("Which diet do you prefer?")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                // Balanced / Any featured full-width top card
                if let anyDiet = dietTypes.first(where: { $0 == "Any" }) {
                    dietChoiceCard(diet: anyDiet, height: 104)
                        .padding(.horizontal, 20)
                }

                // Symmetrical 2x2 Bento Grid for specific diets
                let specificDiets = dietTypes.filter { $0 != "Any" }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(specificDiets, id: \.self) { diet in
                        dietChoiceCard(diet: diet, height: 124)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                NutritionMethodologyDisclaimerView(citations: [.dietaryGuidelines], compact: true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
    }

    private func dietChoiceCard(diet: String, height: CGFloat) -> some View {
        let isSelected = selectedDiet == diet
        return Button(action: {
            HapticManager.shared.impact(style: .light)
            selectedDiet = diet
        }) {
            ZStack(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Image(systemName: iconForDiet(diet))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(7)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(themeManager.current.primaryAccent)
                                .clipShape(Circle())
                        }
                    }

                    Spacer()

                    Text(localizedNameForDiet(diet))
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background {
                ZStack {
                    GeometryReader { geo in
                        RecipeImageView(imageString: imageUrlForDiet(diet), fallbackSystemName: iconForDiet(diet))
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.18), location: 0.0),
                            .init(color: Color.black.opacity(0.42), location: 0.50),
                            .init(color: Color.black.opacity(0.84), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? themeManager.current.primaryAccent : Color.white.opacity(0.16), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: isSelected ? themeManager.current.primaryAccent.opacity(0.22) : Color.black.opacity(0.10), radius: 8, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
    }
    
    private var calorieStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Text("Set your daily calorie goal")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(targetCalories))")
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundColor(.primary)
                        Text("kcal")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $targetCalories, in: 1200...4000, step: 50)
                        .tint(themeManager.current.primaryAccent)

                    HStack {
                        Text("1,200 kcal")
                        Spacer()
                        Text("4,000 kcal")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                }
                .padding(20)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                // Advice table block under the slider
                VStack(alignment: .leading, spacing: 12) {
                    Text("CALORIE GUIDE")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 0) {
                        TableCell(icon: "flame.fill", title: String(localized: "Energy Balance"), desc: String(localized: "Deficit drives fat loss, surplus supports muscle growth."), color: .themePink)
                        Divider()
                        TableCell(icon: "heart.text.square.fill", title: String(localized: "Metabolic Protection"), desc: String(localized: "Prevents extreme hunger and fatigue."), color: .mintGreen)
                        Divider()
                        TableCell(icon: "target", title: String(localized: "Plan Precision"), desc: String(localized: "Helps AI balance protein, fats, and carbs in your menu."), color: .cyberBlue)
                    }
                    .background(Color.primary.opacity(0.02))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
                .padding(.horizontal, 20)

                NutritionMethodologyDisclaimerView(citations: [.dietaryGuidelines], compact: true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
    }
    
    private var complexityStepView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                Text("How much time for cooking?")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                
                VStack(spacing: 12) {
                    ForEach(complexities, id: \.self) { comp in
                        let isSelected = complexity == comp
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            complexity = comp
                        }) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSelected ? themeManager.current.primaryAccent.opacity(0.16) : Color(UIColor.tertiarySystemGroupedBackground))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: iconForComplexity(comp))
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(isSelected ? themeManager.current.primaryAccent : .secondary)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(localizedNameForComplexity(comp))
                                        .font(.system(.headline, design: .rounded, weight: .bold))
                                        .foregroundColor(.primary)
                                    Text(subtitleForComplexity(comp))
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(isSelected ? themeManager.current.primaryAccent : .secondary.opacity(0.4))
                            }
                            .padding(16)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(isSelected ? themeManager.current.primaryAccent : Color.primary.opacity(0.06), lineWidth: isSelected ? 2 : 1)
                            )
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                NutritionMethodologyDisclaimerView(citations: [.dietaryGuidelines], compact: true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
    }

    private func iconForComplexity(_ comp: String) -> String {
        if comp.contains("Fast") { return "bolt.fill" }
        if comp.contains("Medium") { return "clock.fill" }
        return "flame.fill"
    }

    private func subtitleForComplexity(_ comp: String) -> String {
        if comp.contains("Fast") { return String(localized: "Quick prep, minimal cleanup") }
        if comp.contains("Medium") { return String(localized: "Balanced everyday cooking") }
        return String(localized: "Full culinary recipes")
    }
    
    static func iconForDiet(_ diet: String) -> String {
        switch diet {
        case "Keto": return "flame.fill"
        case "Vegan": return "leaf.fill"
        case "Paleo": return "hare.fill"
        case "Mediterranean": return "fish.fill"
        default: return "star.fill"
        }
    }

    private func iconForDiet(_ diet: String) -> String {
        Self.iconForDiet(diet)
    }
    
    private func localizedNameForDiet(_ diet: String) -> String {
        switch diet {
        case "Keto": return String(localized: "Keto")
        case "Vegan": return String(localized: "Vegan")
        case "Paleo": return String(localized: "Paleo")
        case "Mediterranean": return String(localized: "Mediterranean")
        default: return String(localized: "Any")
        }
    }
    
    private func imageUrlForDiet(_ diet: String) -> String {
        switch diet {
        case "Keto":
            return "food_cover_1552566626_52f8b828add9"
        case "Vegan":
            return "food_cover_1512621776951_a57141f2eefd"
        case "Paleo":
            return "food_cover_1544025162_d76694265947"
        case "Mediterranean":
            return "food_cover_1498837167922_ddd27525d352"
        default: // Any
            return "food_cover_1546069901_ba9599a7e63c"
        }
    }
    
    private func localizedNameForComplexity(_ comp: String) -> String {
        if comp.contains("Fast") { return String(localized: "Fast (15 min)") }
        if comp.contains("Medium") { return String(localized: "Medium (30 min)") }
        if comp.contains("Chef") { return String(localized: "Chef (60 min)") }
        return comp
    }
    
    // MARK: - Generation
    
    private func startGeneration() {
        guard !isGenerating else { return }
        guard AIPhotoConsentManager.shared.hasConsented else {
            showAIConsentSheet = true
            return
        }
        withAnimation {
            isGenerating = true
        }
        generationTask?.cancel()

        generationTask = Task {
            let newPlan = await AINutritionService.shared.generateWeeklyPlan(
                targetCalories: Int(targetCalories),
                diet: selectedDiet,
                complexity: complexity
            )
            guard !Task.isCancelled else {
                await MainActor.run { isGenerating = false }
                return
            }
            if let newPlan {
                await MainActor.run {
                    let existingPlans = (try? context.fetch(FetchDescriptor<WeeklyMealPlan>())) ?? []
                    for oldPlan in existingPlans {
                        oldPlan.isCurrentPlan = false
                    }
                    context.insert(newPlan)
                    try? context.save()

                    withAnimation(.spring()) {
                        self.generatedPlan = newPlan
                        self.isGenerating = false
                    }
                }
            } else {
                await MainActor.run {
                    withAnimation { isGenerating = false }
                    generationError = GeminiProxyClient.consumeRateLimitAlertMessage()
                        ?? AINutritionService.shared.lastUserFacingError
                        ?? String(localized: "Couldn't generate a 7-day plan right now. Please try again.")
                    HapticManager.shared.notification(type: .error)
                }
            }
        }
    }
    

}

// MARK: - Loading View
struct AIGenerationLoadingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var themeManager
    let targetCalories: Int
    @State private var rotationDegrees: Double = 0
    @State private var statusText = String(localized: "Analyzing macros...")

    var statuses: [String] {
        [
            String(localized: "Analyzing macros..."),
            String(localized: "Browsing recipes..."),
            String(localized: "Optimizing for \(targetCalories) kcal..."),
            String(localized: "Finalizing menu...")
        ]
    }
    
    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 6)
                    .frame(width: 96, height: 96)

                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(
                        themeManager.current.primaryGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 96, height: 96)
                    .rotationEffect(.degrees(rotationDegrees))

                Image(systemName: "fork.knife")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 6) {
                Text(statusText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .animation(.easeInOut, value: statusText)
                Text("\(targetCalories) kcal/day")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if !reduceMotion {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    rotationDegrees = 360
                }
            }
        }
        .task {
            for (index, status) in statuses.enumerated() {
                if index > 0 {
                    try? await Task.sleep(for: .milliseconds(800))
                }
                guard !Task.isCancelled else { return }
                statusText = status
            }
        }
    }
}

struct TableCell: View {
    let icon: String
    let title: String
    let desc: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(desc)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

