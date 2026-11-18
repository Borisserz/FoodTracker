import SwiftUI
import SwiftData
import Combine

struct SmartPlanBuilderFlow: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Query private var users: [User]
    
    @State private var currentStep = 0
    @State private var selectedDiet = "Any"
    @State private var targetCalories: Double = 2000
    @State private var complexity = "Medium"
    @State private var isGenerating = false
    @State private var generatedPlan: WeeklyMealPlan? = nil
    @State private var generationError: String? = nil
    @State private var generationTask: Task<Void, Never>? = nil
    
    let dietTypes = ["Any", "Keto", "Vegan", "Paleo", "Mediterranean"]
    let complexities = ["Fast (15m)", "Medium (30m)", "Chef (60m)"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                if let plan = generatedPlan {
                    WeeklyPlanOverview(plan: plan) {
                        dismiss()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if isGenerating {
                    AIGenerationLoadingView()
                        .transition(.opacity)
                } else {
                    VStack {
                        // Progress bar
                        HStack {
                            ForEach(0..<3) { step in
                                Rectangle()
                                    .fill(step <= currentStep ? themeManager.current.primaryAccent : Color.gray.opacity(0.3))
                                    .frame(height: 4)
                                    .cornerRadius(2)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        TabView(selection: $currentStep) {
                            dietStepView.tag(0)
                            calorieStepView.tag(1)
                            complexityStepView.tag(2)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut, value: currentStep)
                        
                        HStack {
                            if currentStep > 0 {
                                Button(String(localized: "Back")) {
                                    withAnimation { currentStep -= 1 }
                                }
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundColor(.gray)
                                .padding()
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
                                Text(currentStep < 2 ? String(localized: "Next") : String(localized: "Create Plan"))
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(themeManager.current.primaryGradient)
                                    .clipShape(Capsule())
                                    .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 10, y: 5)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(isGenerating ? "" : (generatedPlan != nil ? String(localized: "Weekly Menu") : String(localized: "Smart Builder")))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isGenerating)
            .onDisappear {
                generationTask?.cancel()
                generationTask = nil
            }
            .toolbar {
                if !isGenerating && generatedPlan == nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(String(localized: "Cancel")) { dismiss() }
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
        }
    }
    
    // MARK: - Steps
    
    private var dietStepView: some View {
        VStack(spacing: 24) {
            Text("Which diet do you prefer?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 30)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(dietTypes, id: \.self) { diet in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        selectedDiet = diet
                    }) {
                        ZStack(alignment: .bottomLeading) {
                            // Cover Image
                            RecipeImageView(imageString: imageUrlForDiet(diet), fallbackSystemName: iconForDiet(diet))
                                .frame(height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .overlay(
                                    LinearGradient(
                                        colors: [.clear, .black.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .cornerRadius(18)
                                )
                            
                            // Checkmark overlay
                            if selectedDiet == diet {
                                VStack {
                                    HStack {
                                        Spacer()
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(6)
                                            .background(themeManager.current.primaryAccent)
                                            .clipShape(Circle())
                                            .shadow(color: Color.black.opacity(0.15), radius: 3)
                                    }
                                    Spacer()
                                }
                                .padding(8)
                            }
                            
                            // Diet label text
                            VStack(alignment: .leading, spacing: 2) {
                                Text(localizedNameForDiet(diet))
                                    .font(.system(.subheadline, design: .rounded, weight: .black))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                            .padding(12)
                        }
                        .frame(height: 110)
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(selectedDiet == diet ? themeManager.current.primaryAccent : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: selectedDiet == diet ? themeManager.current.primaryAccent.opacity(0.2) : .black.opacity(0.05), radius: 6, y: 3)
                    }
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
    
    private var calorieStepView: some View {
        VStack(spacing: 24) {
            Text("Set your daily calorie goal")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 30)
            
            Text("\(Int(targetCalories)) kcal")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(themeManager.current.primaryAccent)
            
            Slider(value: $targetCalories, in: 1200...4000, step: 50)
                .accentColor(themeManager.current.primaryAccent)
                .padding(.horizontal, 28)
            
            // Advice table block under the slider
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.themeYellow)
                        .font(.system(size: 14))
                    Text("CHEF TIP 👨‍🍳")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.themeOrange)
                        .cornerRadius(6)
                }
                .padding(.horizontal, 4)
                
                VStack(spacing: 0) {
                    TableCell(icon: "flame.fill", title: String(localized: "Energy Balance"), desc: String(localized: "Deficit drives fat loss, surplus supports muscle growth."), color: .themePink)
                    Divider()
                    TableCell(icon: "heart.text.square.fill", title: String(localized: "Metabolic Protection"), desc: String(localized: "Prevents extreme hunger and fatigue."), color: .mintGreen)
                    Divider()
                    TableCell(icon: "target", title: String(localized: "Plan Precision"), desc: String(localized: "Helps AI balance protein, fats, and carbs in your menu."), color: .cyberBlue)
                }
                .background(Color.primary.opacity(0.01))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private var complexityStepView: some View {
        VStack(spacing: 24) {
            Text("How much time for cooking?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 30)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                ForEach(complexities, id: \.self) { comp in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        complexity = comp
                    }) {
                        HStack {
                            Text(localizedNameForComplexity(comp))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(complexity == comp ? .white : .primary)
                            Spacer()
                            if complexity == comp {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(complexity == comp ? themeManager.current.primaryAccent : Color.white)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(complexity == comp ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: complexity == comp ? themeManager.current.primaryAccent.opacity(0.3) : .black.opacity(0.02), radius: 5, y: 2)
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private func iconForDiet(_ diet: String) -> String {
        switch diet {
        case "Keto": return "meat.fill"
        case "Vegan": return "leaf.fill"
        case "Paleo": return "hare.fill"
        case "Mediterranean": return "fish.fill"
        default: return "star.fill"
        }
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
            return "https://images.unsplash.com/photo-1552566626-52f8b828add9?auto=format&fit=crop&w=300&q=80"
        case "Vegan":
            return "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=300&q=80"
        case "Paleo":
            return "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=300&q=80"
        case "Mediterranean":
            return "https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=300&q=80"
        default: // Any
            return "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&w=300&q=80"
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
            guard !Task.isCancelled else { return }
            if let newPlan {
                await MainActor.run {
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
                    generationError = String(localized: "Couldn't generate a 7-day plan right now. Please try again.")
                    HapticManager.shared.notification(type: .error)
                }
            }
        }
    }
    

}

// MARK: - Loading View
struct AIGenerationLoadingView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var isPulsing = false
    @State private var statusText = "Analyzing macros..."
    
    let statuses = ["Analyzing macros...", "Browsing recipes...", "Optimizing for \(Int.random(in: 1500...2500)) kcal...", "Finalizing menu..."]
    
    var body: some View {
        VStack(spacing: 40) {
            ZStack {
                Circle()
                    .fill(themeManager.current.primaryAccent.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 1)
                
                Circle()
                    .fill(themeManager.current.primaryGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.5), radius: 20)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            
            Text(statusText)
                .font(.headline)
                .foregroundColor(.gray)
                .animation(.easeInOut, value: statusText)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
            
            for (index, status) in statuses.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.8) {
                    statusText = status
                }
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

