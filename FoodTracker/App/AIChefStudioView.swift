//
//  AIChefStudioView.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 1.05.26.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - 🗄 База Данных с реальными фото
let mockDatabase: [AIChefRecipe] = [
    AIChefRecipe(
        title: "Лосось с киноа", calories: 420, protein: 35, heroImage: "https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=600&q=80", cookTime: 25, difficulty: 2,
        history: "Киноа — это не просто крупа, а подлинное «золото инков». Более трех тысяч лет назад высоко в горах Анд древние племена называли её «чизия мама» (матерь всех семян). Лосось же даст тебе премиальный белок и полезные жиры Омега-3.",
        ingredients: ["Филе лосося (200г)", "Киноа (50г сухой)", "Спаржа (100г)", "Лимон (30г / половинка)", "Оливковое масло (10мл)", "Морская соль (2г)", "Белый перец", "Сушеный чеснок"],
        steps: [
            RecipeStep(instruction: "Подготовка рыбы. Тщательно промокни филе лосося бумажным полотенцем. Лишняя влага — враг корочки! Вотри каплю масла в рыбу массажными движениями.", imageName: "hand.draw.fill", aiTip: "Масло поможет специям раскрыться и проникнуть в волокна."),
            RecipeStep(instruction: "Магия специй. Возьми крупную морскую соль, щепотку белого перца и немного сушеного чеснока. Равномерно посыпь филе со всех сторон.", imageName: "sparkles", aiTip: "Не используй черный перец, он перебьет нежный вкус лосося!"),
            RecipeStep(instruction: "Запекание. Разогрей духовку до 200°C. Выложи лосось на пергамент кожей вниз. Рядом брось спаржу, слегка сбрызнув её лимоном. Запекай ровно 12-15 минут.", imageName: "flame.fill", aiTip: "Сделай фото для ИИ через 10 минут, чтобы мы проверили цвет корочки!"),
            RecipeStep(instruction: "Варка киноа. Пока рыба в духовке, промой киноа кипятком. Вари 15 минут в пропорции 1:2 на слабом огне.", imageName: "drop.fill", aiTip: "Промывка кипятком убивает сапонины — вещества, дающие горечь.")
        ],
        platingTip: "Выложи киноа через кулинарное кольцо в центр тарелки. Сверху аккуратно помести лосось. Спаржу уложи рядом, скрестив стебли. Сбрызни всё каплей оливкового масла экстра-класса и укрась долькой лимона."
    ),
    AIChefRecipe(
        title: "Стейк Рибай", calories: 550, protein: 50, heroImage: "https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=600&q=80", cookTime: 15, difficulty: 4,
        history: "Рибай — неоспоримый король среди стейков. Его мраморность тает при жарке, пропитывая мясо изнутри. Сегодня ты научишься готовить его как шеф-повар мишленовского ресторана.",
        ingredients: ["Стейк Рибай (250г)", "Сливочное масло (20г)", "Чеснок (2 зубчика)", "Розмарин (1 свежая веточка)", "Крупная морская соль (4г)", "Черный перец горошком"],
        steps: [
            RecipeStep(instruction: "Адаптация мяса. Достань стейк из холодильника минимум за 30 минут до жарки. Он должен стать комнатной температуры. Насухо вытри его полотенцем.", imageName: "thermometer.sun", aiTip: "Холодное мясо на сковороде просто сварится в собственном соку."),
            RecipeStep(instruction: "Соль и Перец. Забудь про мелкую соль! Возьми крупную морскую соль и свежемолотый черный перец. Щедро обсыпь стейк с обеих сторон и впечатай специи руками.", imageName: "hand.tap.fill", aiTip: "Крупная соль создаст ту самую хрустящую карамельную корочку."),
            RecipeStep(instruction: "Шоковая жарка. Раскали чугунную сковороду до легкого дымка. Капни масло. Бросай стейк! Жарь ровно 2 минуты, не трогая и не двигая его.", imageName: "flame", aiTip: "Сделай фото! ИИ проверит, достаточно ли дымится сковорода."),
            RecipeStep(instruction: "Ароматная ванна (Бастинг). Переверни стейк. Сразу кинь сливочное масло, чеснок и розмарин. Наклони сковороду и ложкой поливай стейк кипящим маслом!", imageName: "drop.fill", aiTip: "Розмарин отдаст эфирные масла, это изменит вкус блюда на 100%."),
            RecipeStep(instruction: "Отдых. Сними стейк и положи на доску. Не режь! Дай ему отдохнуть 5 минут.", imageName: "clock.fill", aiTip: "За это время соки распределятся от центра к краям.")
        ],
        platingTip: "Обязательно подавай стейк на предварительно подогретой теплой тарелке или деревянной доске. Нарежь его поперек волокон на слайсы толщиной 1.5 см. Посыпь срез крупными хлопьями морской соли — это даст невероятный визуальный и вкусовой хруст."
    )
]

// MARK: - 🎨 Вспомогательные визуальные элементы (Shimmer & Image)
struct ShimmerView: View {
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
        if let url = URL(string: imageString), imageString.hasPrefix("http") {
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
    @Environment(ThemeManager.self) private var themeManager
    @Environment(RecipeDataLoader.self) private var dataLoader
    @Query private var customRecipes: [CustomRecipe]
    @Query(sort: \WeeklyMealPlan.createdDate, order: .reverse) private var weeklyPlans: [WeeklyMealPlan]
    
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]
    
    var currentUser: User? { users.first }
    var currentSummary: DailySummary? {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return summaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) })
    }
    
    var remainingCalories: Int {
        guard let user = currentUser else { return 450 } // fallback
        let consumed = currentSummary?.totalCalories ?? 0
        return max(0, Int(user.dailyCaloriesGoal) - consumed)
    }
    
    var remainingProtein: Int {
        guard let user = currentUser else { return 32 }
        let consumed = currentSummary?.totalProtein ?? 0.0
        return max(0, Int(user.targetProtein) - Int(consumed))
    }
    
    var remainingFat: Int {
        guard let user = currentUser else { return 18 }
        let consumed = currentSummary?.totalFats ?? 0.0
        return max(0, Int(user.targetFats) - Int(consumed))
    }
    
    var remainingCarbs: Int {
        guard let user = currentUser else { return 45 }
        let consumed = currentSummary?.totalCarbs ?? 0.0
        return max(0, Int(user.targetCarbs) - Int(consumed))
    }
    
    @State private var searchText = ""
    @State private var showAIAssistantFlow = false
    @State private var showSmartBuilder = false
    @State private var selectedPlanToView: WeeklyMealPlan?
    
    @State private var bgPhase = 0.0
    
    var filteredRecipes: [AIChefRecipe] { mockDatabase.filter { $0.title.localizedCaseInsensitiveContains(searchText) } }
    var suggestedRecipes: [AIChefRecipe] { mockDatabase.filter { $0.calories <= remainingCalories + 150 } }

    var body: some View {
        NavigationStack {
            ZStack {
                // Premium background blobs
                Color.themeBg.ignoresSafeArea()
                
                ZStack {
                    Circle()
                        .fill(themeManager.current.primaryAccent.opacity(0.12))
                        .frame(width: 260, height: 260)
                        .blur(radius: 60)
                        .offset(x: -120 + bgPhase * 30, y: -220 + bgPhase * 50)
                    
                    Circle()
                        .fill(themeManager.current.secondaryAccent.opacity(0.08))
                        .frame(width: 300, height: 300)
                        .blur(radius: 70)
                        .offset(x: 120 - bgPhase * 40, y: 150 - bgPhase * 60)
                }
                .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // 1. АГЕНТ (СУПЕР-ФЛОУ С КАМЕРОЙ)
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            showAIAssistantFlow = true
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles.tv")
                                        Text("ИИ-Ассистент")
                                    }
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    
                                    Text("Опробуй готовку с ИИ")
                                        .font(.system(.title3, design: .rounded, weight: .black))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(.white)
                                        .symbolEffect(.pulse)
                                }
                            }
                            .padding(20)
                            .background(
                                LinearGradient(
                                    colors: [.themePink, .themeOrange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(24)
                            .shadow(color: .themePink.opacity(0.35), radius: 10, y: 4)
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
                                    HStack(spacing: 6) {
                                        Image(systemName: "calendar.badge.clock")
                                        Text("AI Menu Builder")
                                    }
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.85))
                                    
                                    Text("Составить меню на 7 дней")
                                        .font(.system(.title3, design: .rounded, weight: .black))
                                        .foregroundColor(.white)
                                }
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "wand.and.stars")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(20)
                            .background(themeManager.current.primaryGradient)
                            .cornerRadius(24)
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.35), radius: 10, y: 4)
                        }
                        .buttonStyle(BounceButtonStyle())
                        .padding(.horizontal)
                        
                        // Active 7-Day Plan Previews
                        if !weeklyPlans.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(weeklyPlans.prefix(3)) { plan in
                                    Button(action: {
                                        HapticManager.shared.impact(style: .light)
                                        selectedPlanToView = plan
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 6) {
                                                Text(String(localized: "7-Day Protocol")).font(.caption.bold()).foregroundColor(themeManager.current.primaryAccent)
                                                Text(plan.createdDate.formatted(date: .abbreviated, time: .shortened)).font(.title3.bold()).foregroundColor(.primary)
                                                Text("\(plan.targetCalories) kcal • \(String(localized: String.LocalizationValue(plan.dietType)))").font(.subheadline).foregroundColor(.gray)
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
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 2. ВИДЖЕТ МАКРОСОВ
                        DailyMacroWidget(calories: remainingCalories, protein: remainingProtein, fat: remainingFat, carbs: remainingCarbs)
                        
                        // 3. ПОИСК (Glassmorphic)
                        HStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(themeManager.current.primaryAccent)
                            
                            TextField("Найти блюдо в базе...", text: $searchText)
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
                                    NavigationLink(destination: getDetailView(for: recipe)) {
                                        SearchResultRow(recipe: recipe)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                if filteredRecipes.isEmpty {
                                    Text("Блюдо не найдено")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding()
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("ИИ подобрал под твои макросы:")
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(suggestedRecipes) { recipe in
                                            NavigationLink(destination: getDetailView(for: recipe)) {
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
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    bgPhase = 1.0
                }
            }
            .fullScreenCover(isPresented: $showAIAssistantFlow) {
                AIAssistantFlowView(isPresented: $showAIAssistantFlow)
            }
            .fullScreenCover(isPresented: $showSmartBuilder) {
                SmartPlanBuilderFlow()
            }
            .fullScreenCover(item: $selectedPlanToView) { plan in
                WeeklyPlanOverview(plan: plan) {
                    selectedPlanToView = nil
                }
            }
        }
    }

    @ViewBuilder
    private func getDetailView(for preview: UnifiedRecipePreview) -> some View {
        if let pr = preview.premiumRecipe {
            PremiumRecipeDetailView(recipe: pr)
        } else if let cr = preview.customRecipe {
            RecipeDetailView(recipe: cr, path: .constant(NavigationPath()))
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
    
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Осталось на сегодня")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(calories)")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Text("ккал")
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
                MacroPillView(title: "Белки", value: "\(protein)г", amount: protein, maxAmount: 100, color: .themePeach)
                MacroPillView(title: "Жиры", value: "\(fat)г", amount: fat, maxAmount: 80, color: .themeYellow)
                MacroPillView(title: "Углеводы", value: "\(carbs)г", amount: carbs, maxAmount: 250, color: .drinkWater)
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
                    Text("\(recipe.calories) ккал")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(themeManager.current.primaryAccent)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(recipe.cookTime) мин")
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
                    Text("\(recipe.cookTime) мин")
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
                    Text("\(recipe.calories) ккал")
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
    @State private var isCookingModeActive = false
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
                        Text("\(recipe.cookTime) мин")
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
                        Text("Сложность")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.primary.opacity(0.02))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
                
                // Action Button
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    isCookingModeActive = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                        Text("Начать готовку")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(themeManager.current.primaryGradient)
                    .cornerRadius(20)
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal)
                .buttonStyle(BounceButtonStyle())
                
                // Ingredients Section
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .foregroundColor(themeManager.current.primaryAccent)
                        Text("Ингредиенты")
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
                        Text("История блюда")
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
                        Text("Совет шеф-повара по подаче")
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
    @State private var visibleStepsCount: Int
    
    init(recipe: AIChefRecipe, isPresented: Binding<Bool>, startWithAllSteps: Bool = false) {
        self.recipe = recipe
        self._isPresented = isPresented
        self._visibleStepsCount = State(initialValue: startWithAllSteps ? recipe.steps.count : 1)
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
                            ForEach(0..<visibleStepsCount, id: \.self) { index in
                                CookingStepRow(step: recipe.steps[index], stepNumber: index + 1).id(index).transition(.move(edge: .top).combined(with: .opacity))
                            }
                            
                            if visibleStepsCount == recipe.steps.count {
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
                        Text(visibleStepsCount == recipe.steps.count ? "Finish & Eat!" : "Next step")
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
    @Environment(\.dismiss) var dismiss
    @Environment(RecipeDataLoader.self) private var dataLoader
    @Query private var customRecipes: [CustomRecipe]
    
    @State private var searchAgentText = ""
    @State private var selectedRecipe: AIChefRecipe? = nil
    @State private var isPrepPhase = false
    @State private var isGenerating = false
    
    @State private var generateTask: Task<Void, Never>?
    
    var agentResults: [UnifiedRecipePreview] {
        var list = [UnifiedRecipePreview]()
        for pr in dataLoader.recipes { list.append(UnifiedRecipePreview(title: pr.title, calories: pr.caloriesPerServing, protein: Int(pr.protein), heroImage: pr.imageUrl, cookTime: Int(pr.time.replacingOccurrences(of: "m", with: "")) ?? 20, ingredients: pr.ingredients.map { "\($0.name) (\($0.amount))" }, premiumRecipe: pr, customRecipe: nil)) }
        for cr in customRecipes { list.append(UnifiedRecipePreview(title: cr.name, calories: cr.totalCalories, protein: Int((cr.foodItems ?? []).reduce(0) { $0 + $1.protein }), heroImage: "fork.knife", cookTime: cr.cookingTime, ingredients: (cr.foodItems ?? []).map { "\($0.name) (\($0.weight)g)" }, premiumRecipe: nil, customRecipe: cr)) }
        if searchAgentText.isEmpty { return list }
        return list.filter { $0.title.localizedCaseInsensitiveContains(searchAgentText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                VStack(spacing: 20) {
                    Text(LocalizedStringKey("What shall we cook with AI?")).font(.largeTitle.bold()).padding(.top)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField(String(localized: "e.g. Ribeye..."), text: $searchAgentText)
                    }.padding().background(Color.white).cornerRadius(16).padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(agentResults) { recipe in
                                Button(action: {
                                    generateAI(from: recipe)
                                }) { SearchResultRow(recipe: recipe) }.buttonStyle(PlainButtonStyle())
                            }
                        }.padding(.horizontal)
                        
                        // МЕДИЦИНСКИЙ ДИСКЛЕЙМЕР
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
                    ZStack {
                        Color.themeBg.ignoresSafeArea()
                        
                        VStack(spacing: 40) {
                            AIChefLoadingSpinner()
                            
                            VStack(spacing: 12) {
                                Text(LocalizedStringKey("AI Chef is preparing..."))
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(LocalizedStringKey("Generating personalized recipe, optimal timing, and smart tips for your perfect dish."))
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 40)
                                    .lineSpacing(6)
                            }
                        }
                    }
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        generateTask?.cancel()
                        isGenerating = false
                        dismiss()
                        isPresented = false
                    }) {
                        Text(LocalizedStringKey("Cancel"))
                    }
                    .foregroundColor(.themePink)
                }
            }
            .navigationDestination(isPresented: $isPrepPhase) { if let r = selectedRecipe { PrepChecklistView(recipe: r, isFlowPresented: $isPresented) } }
        }
    }

    private func generateAI(from preview: UnifiedRecipePreview) {
        guard !isGenerating else { return }
        isGenerating = true
        HapticManager.shared.impact(style: .medium)
        
        generateTask = Task {
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
        .fullScreenCover(item: $currentStepForCamera) { step in
            AICameraScannerView(
                step: step,
                isPresented: Binding(
                    get: { currentStepForCamera != nil },
                    set: { if !$0 { currentStepForCamera = nil } }
                )
            )
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

// MARK: - 📸 AICameraScannerView (Real Camera + Real AI Evaluation)
struct AICameraScannerView: View {
    let step: RecipeStep
    @Binding var isPresented: Bool

    @State private var cameraManager = LiveFoodCameraManager()
    @State private var isAnalyzing = false
    @State private var showResult = false
    @State private var verdict: VertexAIManager.ChefVerdictResponse? = nil
    @State private var showShutterFlash = false
    @State private var laserOffset: CGFloat = -160

    var body: some View {
        ZStack {
            // ── Real live camera preview ─────────────────────────────────
            LiveCameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()
                .onAppear { cameraManager.checkPermissionAndStart() }
                .onDisappear { cameraManager.stop() }

            // Subtle dark overlay so UI elements are readable
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Top bar ──────────────────────────────────────────────
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Label("AI Chef Check", systemImage: "sparkles")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    Spacer()
                    Color.clear.frame(width: 40, height: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                // ── Step instruction card ────────────────────────────────
                Text(step.instruction)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                Spacer()

                // ── Viewfinder frame ─────────────────────────────────────
                ZStack {
                    // Dashed border frame
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.5),
                                style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                        .frame(width: 300, height: 340)

                    // Scanning laser (only while analyzing)
                    if isAnalyzing {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .themePink.opacity(0.9), .clear],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: 300, height: 36)
                            .offset(y: laserOffset)
                            .shadow(color: .themePink, radius: 16)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                                    laserOffset = 160
                                }
                            }
                    }

                    // Idle hint
                    if !isAnalyzing && !showResult {
                        VStack(spacing: 10) {
                            Image(systemName: "viewfinder")
                                .font(.system(size: 48, weight: .ultraLight))
                                .foregroundColor(.white.opacity(0.5))
                            Text("Frame the dish and snap")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // ── Shutter button ───────────────────────────────────────
                if !isAnalyzing && !showResult {
                    Button(action: takePhoto) {
                        ZStack {
                            Circle()
                                .fill(Color.themePink)
                                .frame(width: 80, height: 80)
                                .shadow(color: .themePink.opacity(0.5), radius: 14, y: 6)
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 70, height: 70)
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 54)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            // ── Shutter flash ────────────────────────────────────────────
            if showShutterFlash {
                Color.white.ignoresSafeArea()
            }

            // ── AI Analyzing overlay ─────────────────────────────────────
            if isAnalyzing {
                ZStack {
                    Color.black.opacity(0.82).ignoresSafeArea()
                    VStack(spacing: 28) {
                        ZStack {
                            Circle()
                                .stroke(
                                    LinearGradient(colors: [.themePink, .purple, .blue],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                                    lineWidth: 4
                                )
                                .frame(width: 90, height: 90)
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundStyle(
                                    LinearGradient(colors: [.themePink, .purple],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .symbolEffect(.pulse)
                        }
                        VStack(spacing: 6) {
                            Text("AI Chef is evaluating…")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Text("Analyzing your technique")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }

            // ── Result bottom sheet ──────────────────────────────────────
            if showResult, let v = verdict {
                VStack {
                    Spacer()
                    ChefVerdictResultView(verdict: v) {
                        isPresented = false
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(200)
                }
            }
        }
        .onChange(of: cameraManager.capturedImage) { _, image in
            if let image {
                sendToAI(image: image)
            }
        }
        .animation(.spring(response: 0.4), value: isAnalyzing)
        .animation(.spring(response: 0.4), value: showResult)
    }

    // MARK: - Actions

    private func takePhoto() {
        HapticManager.shared.impact(style: .heavy)
        withAnimation(.linear(duration: 0.08)) { showShutterFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation { showShutterFlash = false }
        }
        cameraManager.capturedImage = nil
        cameraManager.takePhoto()
    }

    private func sendToAI(image: UIImage) {
        withAnimation { isAnalyzing = true }
        Task {
            // Real AI call — sends the photo + step instruction to Gemini
            let response = await VertexAIManager.shared.analyzeChefCookingStep(
                image: image,
                stepInstruction: step.instruction
            )
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isAnalyzing = false
                    // Fallback if AI fails (network issue, etc.)
                    verdict = response ?? VertexAIManager.ChefVerdictResponse(
                        score: 70,
                        verdict: "good",
                        feedback: "Looking good! Keep going with confidence.",
                        tip: step.aiTip ?? "Focus on consistency in technique."
                    )
                    showResult = true
                    HapticManager.shared.notification(type: .success)
                }
            }
        }
    }
}

// MARK: - ChefVerdictResultView
// Displays the Michelin-star AI score and tips in a rich bottom sheet.
struct ChefVerdictResultView: View {
    let verdict: VertexAIManager.ChefVerdictResponse
    let onDismiss: () -> Void

    private var accentColor: Color {
        switch verdict.verdict {
        case "perfect":    return .green
        case "good":       return .themeOrange
        default:           return .red
        }
    }

    private var emoji: String {
        switch verdict.verdict {
        case "perfect":    return "🏆"
        case "good":       return "👨‍🍳"
        default:           return "🔄"
        }
    }

    private var label: String {
        switch verdict.verdict {
        case "perfect":    return "Perfect!"
        case "good":       return "Good Job"
        default:           return "Needs Work"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Score ring + emoji
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.12), lineWidth: 10)
                    .frame(width: 110, height: 110)

                Circle()
                    .trim(from: 0, to: CGFloat(verdict.score) / 100.0)
                    .stroke(
                        LinearGradient(colors: [accentColor.opacity(0.6), accentColor],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: verdict.score)

                VStack(spacing: 2) {
                    Text(emoji)
                        .font(.title2)
                    Text("\(verdict.score)")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(accentColor)
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 12)

            // Verdict label
            Text(label)
                .font(.title2.bold())
                .foregroundColor(accentColor)
                .padding(.bottom, 4)

            // Main feedback
            Text(verdict.feedback)
                .font(.body)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            // Pro tip card
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.themeYellow)
                    .font(.title3)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Chef's Tip")
                        .font(.caption.bold())
                        .foregroundColor(.themeYellow)
                    Text(verdict.tip)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineSpacing(3)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.themeYellow.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // CTA button
            Button(action: onDismiss) {
                Text(verdict.verdict == "perfect" ? "Awesome! Next Step →" : "Got It! Keep Cooking")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .clipShape(Capsule())
                    .shadow(color: accentColor.opacity(0.35), radius: 8, y: 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.themeBg)
        .cornerRadius(32)
        .shadow(color: .black.opacity(0.2), radius: 30, y: -10)
        .padding(.horizontal, 8)
    }
}

// MARK: - AIChefLoadingSpinner
struct AIChefLoadingSpinner: View {
    @State private var isSpinning = false
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.1), lineWidth: 10)
                .frame(width: 140, height: 140)
            
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isSpinning)
                
            Image(systemName: "sparkles")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom)
                )
                .symbolEffect(.pulse)
        }
        .onAppear {
            isSpinning = true
        }
    }
}
