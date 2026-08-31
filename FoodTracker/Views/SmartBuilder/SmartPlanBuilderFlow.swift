import SwiftUI
import SwiftData
import Combine

struct SmartPlanBuilderFlow: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Query private var users: [User]
    
    @State private var planService = PlanGenerationService.shared
    @State private var currentStep = 0
    @State private var selectedDiet = "Any"
    @State private var targetCalories: Double = 2000
    @State private var complexity = "Medium (30m)"
    
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
                
                if planService.isGenerating {
                    // ── Loading screen (dismissable) ──────────────────────
                    ZStack(alignment: .topTrailing) {
                        GodTierLoadingView(phase: planService.phase)
                            .transition(.opacity)
                        
                        // Minimize button — lets user go back to menu
                        Button {
                            HapticManager.shared.impact(style: .medium)
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                Text("Minimize")
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.15)))
                        }
                        .padding(.top, 60)
                        .padding(.trailing, 24)
                    }
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
                                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                                    .scaleEffect(currentStep == 0 ? 1.0 : 0.8)
                                    .opacity(currentStep == 0 ? 1.0 : 0.0)
                                    .rotation3DEffect(.degrees(currentStep > 0 ? -15 : 0), axis: (x: 0, y: 1, z: 0))
                                
                                calorieStepView
                                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                                    .scaleEffect(currentStep == 1 ? 1.0 : 0.8)
                                    .opacity(currentStep == 1 ? 1.0 : 0.0)
                                    .rotation3DEffect(.degrees(currentStep < 1 ? 15 : (currentStep > 1 ? -15 : 0)), axis: (x: 0, y: 1, z: 0))
                                
                                complexityStepView
                                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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
                                Button("Назад") {
                                    withAnimation { currentStep -= 1 }
                                }
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundColor(.gray)
                                .padding()
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
                                Text(currentStep < 2 ? "Далее" : "Создать план")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(themeManager.current.primaryGradient)
                                    .clipShape(Capsule())
                                    .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 10, y: 5)
                            }
                            .buttonStyle(BounceButtonStyle())
                            .padding(.trailing, 24)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(isGenerating ? "" : (generatedPlan != nil ? "Недельное меню" : "Умный конструктор"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !planService.isGenerating {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Отмена") { dismiss() }
                            .foregroundColor(.gray)
                    }
                }
            }
            .onAppear {
                if let user = users.first, user.dailyCaloriesGoal > 0 {
                    targetCalories = Double(user.dailyCaloriesGoal)
                }
            }
            .onChange(of: planService.readyPlan) { _, plan in
                if plan != nil {
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Steps
    
    private var dietStepView: some View {
        VStack(spacing: 24) {
            Text("Какую диету ты предпочитаешь?")
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
                                Text(russianNameForDiet(diet))
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
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }
    
    private var calorieStepView: some View {
        VStack(spacing: 24) {
            Text("Укажи дневную цель калорий")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
                .padding(.top, 30)
            
            Text("\(Int(targetCalories)) ккал")
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
                    Text("СОВЕТ ШЕФА 👨‍🍳")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.themeOrange)
                        .cornerRadius(6)
                }
                .padding(.horizontal, 4)
                
                VStack(spacing: 0) {
                    TableCell(icon: "flame.fill", title: "Баланс энергии", desc: "Дефицит запускает жиросжигание, профицит строит мышцы.", color: .themePink)
                    Divider()
                    TableCell(icon: "heart.text.square.fill", title: "Защита метаболизма", desc: "Уберегает от экстремального голода и упадка сил.", color: .mintGreen)
                    Divider()
                    TableCell(icon: "target", title: "Точность плана", desc: "Помогает ИИ распределить баланс БЖУ в твоем меню.", color: .cyberBlue)
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
            Text("Сколько времени уделять готовке?")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 30)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                ForEach(complexities, id: \.self) { comp in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            complexity = comp
                        }
                    }) {
                        HStack {
                            Text(russianNameForComplexity(comp))
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .foregroundColor(complexity == comp ? .white : .primary)
                            Spacer()
                            
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                                .opacity(complexity == comp ? 1 : 0)
                                .scaleEffect(complexity == comp ? 1 : 0.5)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(
                            ZStack {
                                Rectangle().fill(.ultraThinMaterial)
                                
                                themeManager.current.primaryGradient
                                    .opacity(complexity == comp ? 1 : 0)
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(complexity == comp ? themeManager.current.primaryAccent.opacity(0.5) : Color.white.opacity(0.5), lineWidth: complexity == comp ? 2 : 1)
                        )
                        .shadow(color: complexity == comp ? themeManager.current.primaryAccent.opacity(0.4) : .black.opacity(0.05), radius: 15, y: 8)
                        .scaleEffect(complexity == comp ? 1.02 : 1.0)
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
        case "Keto": return "meat.fill"
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
    
    private func russianNameForDiet(_ diet: String) -> String {
        switch diet {
        case "Keto": return "Кето"
        case "Vegan": return "Веганская"
        case "Paleo": return "Палео"
        case "Mediterranean": return "Средиземноморская"
        default: return "Любая"
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
    
    private func russianNameForComplexity(_ comp: String) -> String {
        if comp.contains("Fast") { return "Быстро (15 мин)" }
        if comp.contains("Medium") { return "Средне (30 мин)" }
        if comp.contains("Chef") { return "Шеф (60 мин)" }
        return comp
    }
    
    // MARK: - Generation
    
    private func startGeneration() {
        // Hand off to the global service — it runs entirely in background.
        // The loading screen is shown (GodTierLoadingView via planService.isGenerating),
        // and the user can tap "Minimize" at any time to go back to the tab bar.
        // The floating GenerationStatusPill in ContentView tracks progress everywhere.
        PlanGenerationService.shared.start(
            calories: Int(targetCalories),
            diet: selectedDiet,
            complexity: complexity
        )
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
            let rawPercentage = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let percentage = min(max(rawPercentage, 0), 1)
            
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

// MARK: - Diet Card
struct DietCard: View {
    let isSelected: Bool
    let title: String
    
    @Environment(ThemeManager.self) private var themeManager
    
    var dietDetails: (imageName: String, subtitle: String, gradient: [Color]) {
        switch title {
        case "Any":
            return ("diet_bg_any", "No restrictions", [.blue, .purple])
        case "Keto":
            return ("diet_bg_keto", "High fat, low carb", [.orange, .red])
        case "Vegan":
            return ("diet_bg_vegan", "100% plant-based", [.green, .teal])
        case "Vegetarian":
            return ("diet_bg_vegetarian", "Plant-based, no meat", [.yellow, .green])
        case "Paleo":
            return ("diet_bg_paleo", "Natural whole foods", [.orange, .red])
        case "Pescatarian":
            return ("diet_bg_pescatarian", "Fish and seafood", [.teal, .blue])
        case "Mediterranean":
            return ("diet_bg_mediterranean", "Olive oil and veggies", [.green, .blue])
        case "High Protein":
            return ("diet_bg_highprotein", "High protein for muscles", [.red, .purple])
        case "Low Carb":
            return ("diet_bg_lowcarb", "Minimum carbs", [.pink, .orange])
        default:
            return ("diet_bg_any", "Personal choice", [.gray, .black])
        }
    }
    
    var body: some View {
        let details = dietDetails
        ZStack {
            // Background Image
            Image(details.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 120)
                .clipped()
            
            // Darkening overlay + selection color gradient
            if isSelected {
                LinearGradient(
                    colors: [details.gradient[0].opacity(0.8), details.gradient[1].opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.black.opacity(0.55)
            }
            
            // Content
            VStack(spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                
                Text(LocalizedStringKey(details.subtitle))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                    .frame(height: 32, alignment: .top)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
            }
            .padding(.vertical, 16)
        }
        .frame(height: 120)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Color.white : Color.white.opacity(0.15), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? details.gradient.first?.opacity(0.4) ?? .clear : .black.opacity(0.1), radius: 10, y: 6)
        .scaleEffect(isSelected ? 1.03 : 1.0)
    }
}

// MARK: - Hypnotic Loading View
struct GodTierLoadingView: View {
    var phase: PlanGenerationService.Phase = .generatingText

    @Environment(ThemeManager.self) private var themeManager
    @State private var rotation1: Double = 0
    @State private var rotation2: Double = 360
    @State private var statusIndex = 0
    @State private var innerScale: CGFloat = 0.5

    private let aiStatuses = [
        "Synthesizing nutritional matrices...",
        "Aligning macros to your profile...",
        "Curating top-tier recipes...",
        "Assembling the perfect week...",
        "Finalizing your God-Tier Menu..."
    ]

    private var isImagePhase: Bool {
        if case .fetchingImages = phase { return true }
        return false
    }

    private var imageDone: Int {
        if case .fetchingImages(let done, _) = phase { return done }
        return 0
    }

    private var imageTotal: Int {
        if case .fetchingImages(_, let total) = phase { return total }
        return 0
    }

    private var imageProgress: Double {
        guard imageTotal > 0 else { return 0 }
        return Double(imageDone) / Double(imageTotal)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 60) {
                ZStack {
                    // Outer ring
                    Circle()
                        .strokeBorder(
                            AngularGradient(gradient: Gradient(colors: [.clear, themeManager.current.primaryAccent, .clear]), center: .center),
                            lineWidth: 4
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(rotation1))

                    // Inner ring — progress arc when fetching images
                    if isImagePhase {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 10)
                            .frame(width: 150, height: 150)

                        Circle()
                            .trim(from: 0, to: imageProgress)
                            .stroke(
                                themeManager.current.primaryAccent,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.4), value: imageProgress)
                    } else {
                        Circle()
                            .strokeBorder(
                                AngularGradient(gradient: Gradient(colors: [.clear, Color.themePink, .clear]), center: .center),
                                lineWidth: 8
                            )
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(rotation2))
                    }

                    // Core orb
                    Circle()
                        .fill(themeManager.current.primaryGradient)
                        .frame(width: 80, height: 80)
                        .blur(radius: 20)
                        .scaleEffect(innerScale)
                        .opacity(0.8)

                    if isImagePhase {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.white)
                    }
                }

                VStack(spacing: 12) {
                    Text(isImagePhase ? LocalizedStringKey("LOADING PHOTOS") : LocalizedStringKey("AI CHEF AWAKENED"))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(4)
                        .animation(.easeInOut, value: isImagePhase)

                    if isImagePhase {
                        // Real progress text
                        Text("Caching photo \(imageDone) of \(imageTotal)", comment: "Progress info")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                            .transition(.opacity)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(themeManager.current.primaryGradient)
                                    .frame(width: geo.size.width * imageProgress, height: 6)
                                    .animation(.easeInOut(duration: 0.4), value: imageProgress)
                            }
                        }
                        .frame(height: 6)
                        .padding(.horizontal, 40)
                    } else {
                        Text(LocalizedStringKey(aiStatuses[min(statusIndex, aiStatuses.count - 1)]))
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))
                            .id(statusIndex)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                                removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 1.1))
                            ))
                    }

                    Text(LocalizedStringKey("This may take 1–2 minutes.\nWe're building your entire week, including meal photos."))
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                        .padding(.horizontal, 32)
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
                    if statusIndex < aiStatuses.count - 1 {
                        statusIndex += 1
                    } else {
                        timer.invalidate()
                    }
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

