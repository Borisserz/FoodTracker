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
    
    // Background animation
    @State private var bgRotation: Double = 0
    @State private var bgScale: CGFloat = 1.0
    
    let dietTypes = ["Any", "Keto", "Vegan", "Vegetarian", "Paleo", "Pescatarian", "Mediterranean", "High Protein", "Low Carb"]
    let complexities = ["Fast (15m)", "Medium (30m)", "Chef (60m)"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                // God-like Ethereal Background
                Color.themeBg.ignoresSafeArea()
                
                GeometryReader { proxy in
                    ZStack {
                        AngularGradient(
                            gradient: Gradient(colors: [
                                themeManager.current.primaryAccent.opacity(0.3),
                                Color.themePink.opacity(0.2),
                                Color.themeOrange.opacity(0.3),
                                Color.themeYellow.opacity(0.2),
                                themeManager.current.primaryAccent.opacity(0.3)
                            ]),
                            center: .center,
                            angle: .degrees(bgRotation)
                        )
                        .frame(width: proxy.size.width * 1.5, height: proxy.size.height * 1.5)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                        .blur(radius: 80)
                        .scaleEffect(bgScale)
                    }
                }
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
                        bgRotation = 360
                    }
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        bgScale = 1.2
                    }
                }
                
                if let plan = generatedPlan {
                    WeeklyPlanOverview(plan: plan) {
                        dismiss()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if isGenerating {
                    GodTierLoadingView()
                        .transition(.opacity)
                } else {
                    VStack(spacing: 0) {
                        // Liquid Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .frame(height: 8)
                                
                                Capsule()
                                    .fill(themeManager.current.primaryGradient)
                                    .frame(width: geo.size.width * CGFloat(currentStep + 1) / 3, height: 8)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: currentStep)
                                    .shadow(color: themeManager.current.primaryAccent.opacity(0.6), radius: 8, y: 0)
                            }
                        }
                        .frame(height: 8)
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        
                        // Cinematic 3D Transitions
                        GeometryReader { proxy in
                            HStack(spacing: 0) {
                                dietStepView
                                    .frame(width: proxy.size.width)
                                    .scaleEffect(currentStep == 0 ? 1.0 : 0.8)
                                    .opacity(currentStep == 0 ? 1.0 : 0.0)
                                    .rotation3DEffect(.degrees(currentStep > 0 ? -15 : 0), axis: (x: 0, y: 1, z: 0))
                                
                                calorieStepView
                                    .frame(width: proxy.size.width)
                                    .scaleEffect(currentStep == 1 ? 1.0 : 0.8)
                                    .opacity(currentStep == 1 ? 1.0 : 0.0)
                                    .rotation3DEffect(.degrees(currentStep < 1 ? 15 : (currentStep > 1 ? -15 : 0)), axis: (x: 0, y: 1, z: 0))
                                
                                complexityStepView
                                    .frame(width: proxy.size.width)
                                    .scaleEffect(currentStep == 2 ? 1.0 : 0.8)
                                    .opacity(currentStep == 2 ? 1.0 : 0.0)
                                    .rotation3DEffect(.degrees(currentStep < 2 ? 15 : 0), axis: (x: 0, y: 1, z: 0))
                            }
                            .offset(x: -CGFloat(currentStep) * proxy.size.width)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)
                        }
                        
                        // Bottom Navigation
                        HStack {
                            if currentStep > 0 {
                                Button(action: {
                                    HapticManager.shared.impact(style: .light)
                                    currentStep -= 1
                                }) {
                                    Image(systemName: "arrow.left")
                                        .font(.title2.bold())
                                        .foregroundColor(.primary)
                                        .frame(width: 64, height: 64)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                                        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
                                }
                                .padding(.leading, 24)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                HapticManager.shared.impact(style: .heavy)
                                if currentStep < 2 {
                                    currentStep += 1
                                } else {
                                    startGeneration()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Text(currentStep < 2 ? "Next" : "Ignite AI")
                                    Image(systemName: currentStep < 2 ? "arrow.right" : "sparkles")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 36)
                                .frame(height: 64)
                                .background(themeManager.current.primaryGradient)
                                .clipShape(Capsule())
                                .shadow(color: themeManager.current.primaryAccent.opacity(0.5), radius: 20, y: 10)
                            }
                            .buttonStyle(BounceButtonStyle())
                            .padding(.trailing, 24)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(isGenerating ? "" : (generatedPlan != nil ? "" : "AI Builder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isGenerating && generatedPlan == nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
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
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Select Core Diet")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text("AI tailors ingredients perfectly.")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 40)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(dietTypes, id: \.self) { diet in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        selectedDiet = diet
                    }) {
                        Tilt3DCard(isSelected: selectedDiet == diet, icon: iconForDiet(diet), title: diet)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }
    
    private var calorieStepView: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Daily Energy")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Your optimized macro target.")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 8)
            
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 230, height: 230)
                    .shadow(color: .black.opacity(0.05), radius: 20, y: 10)
                
                Circle()
                    .stroke(themeManager.current.primaryGradient, lineWidth: 2)
                    .frame(width: 220, height: 220)
                    .opacity(0.5)
                
                VStack(spacing: 4) {
                    Text("\(Int(targetCalories))")
                        .font(.system(size: 58, weight: .black, design: .rounded))
                        .foregroundStyle(themeManager.current.primaryGradient)
                        .contentTransition(.numericText())
                    Text("KCAL")
                        .font(.title3.bold())
                        .foregroundColor(.gray)
                }
            }
            
            CustomThickSlider(value: $targetCalories, range: 1200...4000, step: 50)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var complexityStepView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Cooking Time")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                Text("How long per meal?")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 8)
            
            VStack(spacing: 12) {
                ForEach(complexities, id: \.self) { comp in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            complexity = comp
                        }
                    }) {
                        HStack {
                            Text(comp)
                                .font(.title3.bold())
                                .foregroundColor(complexity == comp ? .white : .primary)
                            Spacer()
                            if complexity == comp {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                                    .font(.title2)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            ZStack {
                                if complexity == comp {
                                    themeManager.current.primaryGradient
                                } else {
                                    Rectangle().fill(.ultraThinMaterial)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(complexity == comp ? themeManager.current.primaryAccent.opacity(0.5) : Color.white.opacity(0.5), lineWidth: complexity == comp ? 2 : 1)
                        )
                        .shadow(color: complexity == comp ? themeManager.current.primaryAccent.opacity(0.4) : .black.opacity(0.05), radius: 15, y: 8)
                        .scaleEffect(complexity == comp ? 1.02 : 1.0)
                        // Adding a subtle 3d tilt to the selected row
                        .rotation3DEffect(.degrees(complexity == comp ? 5 : 0), axis: (x: 1, y: 0, z: 0))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    private func iconForDiet(_ diet: String) -> String {
        switch diet {
        case "Keto": return "flame.fill"
        case "Vegan": return "leaf.fill"
        case "Vegetarian": return "leaf.arrow.circlepath"
        case "Paleo": return "hare.fill"
        case "Pescatarian": return "fish.fill"
        case "Mediterranean": return "drop.fill"
        case "High Protein": return "dumbbell.fill"
        case "Low Carb": return "minus.circle.fill"
        default: return "star.fill"
        }
    }
    
    // MARK: - Generation
    
    private func startGeneration() {
        withAnimation(.easeInOut(duration: 0.5)) {
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
                    
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                        self.generatedPlan = newPlan
                        self.isGenerating = false
                    }
                }
            } else {
                await MainActor.run {
                    withAnimation { isGenerating = false }
                }
            }
        }
    }
}

// MARK: - Custom Thick Slider
struct CustomThickSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        GeometryReader { geometry in
            let percentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(height: 24)
                
                // Fill
                Capsule()
                    .fill(themeManager.current.primaryGradient)
                    .frame(width: max(24, geometry.size.width * percentage), height: 24)
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.5), radius: 10, y: 0)
                
                // Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                    .offset(x: percentage * (geometry.size.width - 40))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let xOffset = min(max(0, gesture.location.x), geometry.size.width)
                                let newPercentage = xOffset / geometry.size.width
                                let rawValue = Double(newPercentage) * (range.upperBound - range.lowerBound) + range.lowerBound
                                
                                let steppedValue = round(rawValue / step) * step
                                let finalValue = min(max(steppedValue, range.lowerBound), range.upperBound)
                                
                                if value != finalValue {
                                    HapticManager.shared.impact(style: .light)
                                    withAnimation(.interactiveSpring()) {
                                        value = finalValue
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: 40)
    }
}

// MARK: - 3D Tilt Card
struct Tilt3DCard: View {
    let isSelected: Bool
    let icon: String
    let title: String
    
    @Environment(ThemeManager.self) private var themeManager
    
    // For manual tilt when tapped
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(isSelected ? .white : themeManager.current.primaryAccent)
            
            Text(title)
                .font(.title3.bold())
                .foregroundColor(isSelected ? .white : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(
            ZStack {
                if isSelected {
                    themeManager.current.primaryGradient
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .overlay(
            RoundedRectangle(cornerRadius: 32)
                .stroke(isSelected ? Color.white.opacity(0.5) : Color.white.opacity(0.3), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? themeManager.current.primaryAccent.opacity(0.5) : .black.opacity(0.05), radius: 20, y: 10)
    }
}

// MARK: - Hypnotic Loading View
struct GodTierLoadingView: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var rotation1: Double = 0
    @State private var rotation2: Double = 360
    @State private var statusIndex = 0
    @State private var innerScale: CGFloat = 0.5
    
    let statuses = [
        "Synthesizing nutritional matrices...",
        "Aligning macros to your profile...",
        "Curating top-tier recipes...",
        "Assembling the perfect week...",
        "Finalizing God-Tier Menu..."
    ]
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            
            VStack(spacing: 80) {
                ZStack {
                    // Outer ring
                    Circle()
                        .strokeBorder(
                            AngularGradient(gradient: Gradient(colors: [.clear, themeManager.current.primaryAccent, .clear]), center: .center),
                            lineWidth: 4
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(rotation1))
                    
                    // Inner ring
                    Circle()
                        .strokeBorder(
                            AngularGradient(gradient: Gradient(colors: [.clear, Color.themePink, .clear]), center: .center),
                            lineWidth: 8
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(rotation2))
                    
                    // Core orb
                    Circle()
                        .fill(themeManager.current.primaryGradient)
                        .frame(width: 80, height: 80)
                        .blur(radius: 20)
                        .scaleEffect(innerScale)
                        .opacity(0.8)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 16) {
                    Text("AI CHEF AWAKENED")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(4)
                    
                    Text(statuses[statusIndex])
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                        .id(statusIndex)
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                            removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 1.1))
                        ))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation1 = 360
            }
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation2 = 0
            }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                innerScale = 1.5
            }
            
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { timer in
                HapticManager.shared.impact(style: .medium)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    if statusIndex < statuses.count - 1 {
                        statusIndex += 1
                    } else {
                        timer.invalidate()
                    }
                }
            }
        }
    }
}
