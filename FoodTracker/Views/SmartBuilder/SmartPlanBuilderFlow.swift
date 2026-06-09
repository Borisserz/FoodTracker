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
                                Button("Back") {
                                    withAnimation { currentStep -= 1 }
                                }
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
                                Text(currentStep < 2 ? "Next" : "Generate Plan")
                                    .font(.headline)
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
            .navigationTitle(isGenerating ? "" : (generatedPlan != nil ? "Weekly Plan" : "Smart Builder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isGenerating && generatedPlan == nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                if let user = users.first, user.dailyCaloriesGoal > 0 {
                    targetCalories = Double(user.dailyCaloriesGoal)
                }
            }
        }
    }
    
    // MARK: - Steps
    
    private var dietStepView: some View {
        VStack(spacing: 24) {
            Text("What's your preferred diet?")
                .font(.title2.bold())
                .padding(.top, 40)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(dietTypes, id: \.self) { diet in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        selectedDiet = diet
                    }) {
                        VStack(spacing: 12) {
                            Image(systemName: iconForDiet(diet))
                                .font(.system(size: 32))
                                .foregroundColor(selectedDiet == diet ? .white : themeManager.current.primaryAccent)
                            Text(diet)
                                .font(.headline)
                                .foregroundColor(selectedDiet == diet ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(selectedDiet == diet ? themeManager.current.primaryAccent : Color.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(selectedDiet == diet ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: selectedDiet == diet ? themeManager.current.primaryAccent.opacity(0.3) : .black.opacity(0.05), radius: 8, y: 4)
                    }
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
    
    private var calorieStepView: some View {
        VStack(spacing: 32) {
            Text("Set your daily calorie target")
                .font(.title2.bold())
                .padding(.top, 40)
            
            Text("\(Int(targetCalories)) kcal")
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundColor(themeManager.current.primaryAccent)
            
            Slider(value: $targetCalories, in: 1200...4000, step: 50)
                .accentColor(themeManager.current.primaryAccent)
                .padding(.horizontal, 32)
            
            Text("This is optimized based on your profile goals. Feel free to adjust it manually.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var complexityStepView: some View {
        VStack(spacing: 24) {
            Text("How much time do you want to spend cooking?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.top, 40)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                ForEach(complexities, id: \.self) { comp in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        complexity = comp
                    }) {
                        HStack {
                            Text(comp)
                                .font(.headline)
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
        case "Keto": return "meat.fill" // iOS 18 beta might have this, but let's use standard symbols
        case "Vegan": return "leaf.fill"
        case "Paleo": return "hare.fill"
        case "Mediterranean": return "fish.fill"
        default: return "star.fill"
        }
    }
    
    // MARK: - Generation
    
    private func startGeneration() {
        withAnimation {
            isGenerating = true
        }
        
        Task {
            if let newPlan = await AINutritionService.shared.generateWeeklyPlan(
                targetCalories: Int(targetCalories),
                diet: selectedDiet,
                complexity: complexity
            ) {
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
                    // Fallback handled silently or with alert in real app
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
