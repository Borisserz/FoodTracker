//
//  AIChefStudioView.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 1.05.26.
//

import SwiftUI
import SwiftData

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
    @State private var remainingCalories: Int = 450
    @State private var remainingProtein: Int = 32
    @State private var remainingFat: Int = 18
    @State private var remainingCarbs: Int = 45
    
    @State private var searchText = ""
    @State private var showAIAssistantFlow = false
    @State private var showSmartBuilder = false
    
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
                                    NavigationLink(destination: RecipeDetailAIView(recipe: recipe)) {
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
            .navigationTitle("AI Шеф")
            .onAppear {
                TrackingManager.shared.track(.featureDiscovered(feature: "ai_chef_studio"))
                withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                    bgPhase = 1.0
                }
            }
            .fullScreenCover(isPresented: $showAIAssistantFlow) {
                AIAssistantFlowView(isPresented: $showAIAssistantFlow)
            }
            .sheet(isPresented: $showSmartBuilder) {
                SmartPlanBuilderFlow()
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
    @State private var searchAgentText = ""
    @State private var selectedRecipe: AIChefRecipe? = nil
    @State private var isPrepPhase = false
    
    var agentResults: [AIChefRecipe] { searchAgentText.isEmpty ? mockDatabase : mockDatabase.filter { $0.title.localizedCaseInsensitiveContains(searchAgentText) } }
    
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
                                    HapticManager.shared.impact(style: .medium)
                                    selectedRecipe = recipe; isPrepPhase = true
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
            }
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Отмена") { isPresented = false }.foregroundColor(.themePink) } }
            .navigationDestination(isPresented: $isPrepPhase) { if let r = selectedRecipe { PrepChecklistView(recipe: r, isFlowPresented: $isPresented) } }
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
        VStack {
            Text("Подготовка продуктов").font(.title2.bold()).padding()
            List {
                Section(header: Text("Отметь, что у тебя есть на столе")) {
                    ForEach(recipe.ingredients, id: \.self) { item in
                        HStack {
                            Text(item).font(.body); Spacer()
                            Image(systemName: checkedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(checkedItems.contains(item) ? .green : .gray).font(.title2)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            HapticManager.shared.impact(style: .light)
                            if checkedItems.contains(item) { checkedItems.remove(item) } else { checkedItems.insert(item) }
                        }
                    }
                }
            }.listStyle(InsetGroupedListStyle())
            
            Button(action: { HapticManager.shared.impact(style: .medium); isCookingPhase = true }) {
                Text(allChecked ? "Все готово, начинаем!" : "Продолжить")
                    .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity)
                    .padding().background(allChecked ? Color.green : Color.themePink).cornerRadius(16)
            }.padding()
        }
        .background(Color.themeBg.ignoresSafeArea())
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Circle().fill(Color.themePink.opacity(0.2)).frame(width: 36, height: 36)
                                .overlay(Text("\(index + 1)").font(.headline).foregroundColor(.themePink))
                            Text("Инструкция от ИИ").font(.headline).foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        Text(step.instruction).font(.body.weight(.medium)).lineSpacing(6)
                        
                        if let tip = step.aiTip {
                            HStack(alignment: .top) {
                                Image(systemName: "sparkles").foregroundColor(.themeOrange).padding(.top, 2)
                                Text(tip).font(.subheadline).foregroundColor(.secondary)
                            }.padding(12).background(Color.themeOrange.opacity(0.1)).cornerRadius(12)
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        Button(action: {
                            HapticManager.shared.impact(style: .medium); currentStepForCamera = step; showCameraScanner = true
                        }) {
                            HStack {
                                Image(systemName: "camera.viewfinder")
                                Text("Проверить этот шаг через камеру")
                            }
                            .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(14).background(Color.themePink).cornerRadius(16)
                        }
                    }.padding().background(Color.white).cornerRadius(20).padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Image(systemName: "sparkles").foregroundColor(.themeOrange); Text("Финальный штрих: Подача").font(.title3.bold()) }
                    Text(recipe.platingTip)
                        .font(.body.italic())
                        .lineSpacing(6)
                        .foregroundColor(.primary)
                }
                .padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.themeOrange.opacity(0.1)).cornerRadius(20).padding(.horizontal)
                
                Button("Завершить готовку") {
                    HapticManager.shared.impact(style: .rigid)
                    isFlowPresented = false
                }
                .foregroundColor(.gray).padding(.top, 20).padding(.bottom, 40)
            }.padding(.top, 16)
        }
        .background(Color.themeBg.ignoresSafeArea())
        .navigationTitle("ИИ Шеф следит")
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
    
    let successPhrases = ["Идеально! Температура и цвет то что нужно.", "Специи легли отлично. Продолжай!", "Корочка схватилась правильно. Переходи к следующему шагу."]
    let errorPhrases = ["Маловато соли. Добавь еще щепотку!", "Сковорода недостаточно раскалена. Подожди 30 секунд.", "Цвет бледноват, дай блюду еще немного времени."]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                HStack { Button("Закрыть") { isPresented = false }.foregroundColor(.white).padding(); Spacer() }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.3), lineWidth: 2).frame(width: 300, height: 400)
                    if isAnalyzing {
                        VStack { ProgressView().tint(.white).scaleEffect(2); Text("ИИ анализирует...").foregroundColor(.white).padding(.top) }
                    } else if showResult {
                        VStack(spacing: 16) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isSuccess ? .green : .yellow).font(.system(size: 60))
                            Text(aiVerdict).font(.title3.bold()).foregroundColor(.white).multilineTextAlignment(.center).padding()
                            Button("Понял") { isPresented = false }.padding().background(Color.white.opacity(0.2)).cornerRadius(12).foregroundColor(.white)
                        }
                    } else { Text("Наведи камеру на блюдо").foregroundColor(.white.opacity(0.6)) }
                }
                Spacer()
                if !isAnalyzing && !showResult {
                    Button(action: takePhoto) {
                        Circle().stroke(Color.white, lineWidth: 4).frame(width: 70, height: 70)
                            .overlay(Circle().fill(Color.white).frame(width: 60, height: 60))
                    }.padding(.bottom, 40)
                }
            }
        }
    }
    
    func takePhoto() {
        HapticManager.shared.impact(style: .rigid); isAnalyzing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isAnalyzing = false; showResult = true; isSuccess = Bool.random()
            aiVerdict = isSuccess ? successPhrases.randomElement()! : errorPhrases.randomElement()!
            HapticManager.shared.impact(style: .medium)
        }
    }
}
