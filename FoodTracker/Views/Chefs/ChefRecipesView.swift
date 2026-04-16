//
//  ChefRecipesView.swift
//  FoodTracker
//

import SwiftUI
import SwiftData

// MARK: - 1. MOCK DATA MODELS
struct PremiumRecipe: Identifiable, Hashable, Codable {
    var id: UUID = UUID() // Генерируется автоматически
    let title: String
    let description: String
    let time: String
    let caloriesPerServing: Int
    let imageUrl: String
    var isFavorite: Bool
    
    let tags: [String]
    let baseServings: Int
    
    let protein: Double
    let fat: Double
    let carbs: Double
    
    let ingredients: [RecipeIngredient]
    let directions: [String]
    
    // Исключаем id из JSON, чтобы не писать его вручную каждый раз
    enum CodingKeys: String, CodingKey {
        case title, description, time, caloriesPerServing, imageUrl, isFavorite, tags, baseServings, protein, fat, carbs, ingredients, directions
    }
}

struct RecipeIngredient: Hashable, Codable {
    let name: String
    let amount: String
    let weightGrams: Int
    let calories: Int
}

struct NutritionFact: Hashable {
    let name: String
    let amount: String
    let isSubItem: Bool
}

var mockRecipesData: [PremiumRecipe] = [
    PremiumRecipe(
        title: "Baked Apples with Honey & Walnuts",
        description: "Simple to make, comforting to enjoy, and perfect for cozy evenings. 🍂",
        time: "20 min", caloriesPerServing: 249,
        imageUrl: "https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?q=80&w=800&auto=format&fit=crop",
        isFavorite: true, tags: ["Breakfast", "Snack", "Vegetarian"], baseServings: 4,
        protein: 3.0, fat: 11.0, carbs: 40.5,
        ingredients: [RecipeIngredient(name: "Walnuts", amount: "65 g", weightGrams: 65, calories: 425)],
        directions: ["Core apples.", "Bake at 180°C."]
    ),
    PremiumRecipe(
        title: "Creamy Pumpkin Risotto with Gorgonzola",
        description: "A rich and creamy autumn classic.",
        time: "40 min", caloriesPerServing: 441,
        imageUrl: "https://images.unsplash.com/photo-1608897013039-887f21d8c804?q=80&w=800&auto=format&fit=crop",
        isFavorite: false, tags: ["Dinner", "Vegetarian"], baseServings: 2,
        protein: 14.0, fat: 18.0, carbs: 55.0,
        ingredients: [], directions: []
    ),
    PremiumRecipe(
        title: "Chicken and Wild Rice Bowl",
        description: "High protein, low calorie perfect lunch.",
        time: "25 min", caloriesPerServing: 504,
        imageUrl: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?q=80&w=800&auto=format&fit=crop",
        isFavorite: true, tags: ["Lunch", "High Protein"], baseServings: 2,
        protein: 38.8, fat: 8.6, carbs: 66.5,
        ingredients: [], directions: []
    )
]

// MARK: - 2. MAIN RECIPES CONTAINER (РАЗДЕЛЕН НА ВКЛАДКИ)
struct RecipesContainerView: View {
    @Binding var path: NavigationPath
    @Query(sort: \CustomRecipe.name) private var customRecipes: [CustomRecipe]
    @State private var dataLoader = RecipeDataLoader()
    @State private var selectedTab: Int = 0 // 0 - Discover, 1 - My Recipes
    @State private var searchText = ""
    @State private var showFilters = false
    
    @Namespace private var animation
    
    var body: some View {
        VStack(spacing: 0) {
            // --- CUSTOM ANIMATED TAB BAR ---
            HStack {
                TabButton(title: "Discover", tabIndex: 0, selectedTab: $selectedTab, animation: animation)
                TabButton(title: "My Recipes", tabIndex: 1, selectedTab: $selectedTab, animation: animation)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .background(Color.themeBg)
            
            // --- СТРОКА ПОИСКА (ОБЩАЯ) ---
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Find recipe...", text: $searchText)
                        .font(.system(size: 16, design: .rounded))
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
                
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    showFilters = true
                }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.bold())
                        .foregroundColor(.themePink)
                        .frame(width: 50, height: 50)
                        .background(Color.themePink.opacity(0.15))
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .background(Color.themeBg)
            
            TabView(selection: $selectedTab) {
                 // ПЕРЕДАЕМ ЗАГРУЖЕННЫЕ РЕЦЕПТЫ
                 DiscoverTabView(path: $path, allRecipes: dataLoader.recipes)
                     .tag(0)
                 
                 MyRecipesTabView(path: $path, customRecipes: customRecipes, allRecipes: dataLoader.recipes)
                     .tag(1)
             }
             .tabViewStyle(.page(indexDisplayMode: .never))
             .animation(.easeInOut, value: selectedTab)
         }
        .background(Color.themeBg.ignoresSafeArea())
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .environment(dataLoader)
        .sheet(isPresented: $showFilters) {
            AdvancedRecipeFilterSheet(allRecipes: dataLoader.recipes) { title, filtered in
                // Когда фильтр закрывается, мы пушим новый экран
                path.append(FoodsRoute.filteredList(title, filtered))
            }
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(for: PremiumRecipe.self) { recipe in
            PremiumRecipeDetailView(recipe: recipe)
        }
    }
}

// Анимированная кнопка таба
struct TabButton: View {
    let title: String
    let tabIndex: Int
    @Binding var selectedTab: Int
    let animation: Namespace.ID
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedTab = tabIndex
            }
        }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: selectedTab == tabIndex ? .bold : .medium, design: .rounded))
                    .foregroundColor(selectedTab == tabIndex ? .themePink : .gray)
                
                if selectedTab == tabIndex {
                    Capsule()
                        .fill(Color.themePink)
                        .frame(height: 3)
                        .matchedGeometryEffect(id: "TAB_UNDERLINE", in: animation)
                } else {
                    Capsule()
                        .fill(Color.clear)
                        .frame(height: 3)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 3. DISCOVER TAB (КРУТЫЕ КАТЕГОРИИ И ПЛИТКИ)
struct DiscoverTabView: View {
    @Binding var path: NavigationPath
    let allRecipes: [PremiumRecipe]
    
    let calorieRanges = [
        ("Under 300", Color.green, 0, 300),
        ("300 - 450", Color.themeYellow, 300, 450),
        ("450 - 600", Color.themeOrange, 450, 600),
        ("600+ kcal", Color.themePink, 600, 5000)
    ]
    
    var body: some View {
        // 👇 УМНАЯ СОРТИРОВКА (Один рецепт = одна группа)
        var pool = allRecipes
        
        let highProtein = pool.filter { $0.tags.contains("High Protein") }
        pool.removeAll { r in highProtein.contains(where: { $0.id == r.id }) }
        
        let ketoLowCarb = pool.filter { $0.tags.contains("Low Carb") || $0.tags.contains("Ketogenic") }
        pool.removeAll { r in ketoLowCarb.contains(where: { $0.id == r.id }) }
        
        let quickEasy = pool.filter { $0.tags.contains("Quickly Prepared") || $0.tags.contains("Easy") }
        pool.removeAll { r in quickEasy.contains(where: { $0.id == r.id }) }
        
        let plantBased = pool.filter { $0.tags.contains("Vegan") || $0.tags.contains("Vegetarian") }
        pool.removeAll { r in plantBased.contains(where: { $0.id == r.id }) }
        
        // Все, что не попало в категории выше, идет в "Спецпредложения от шефа"
        let chefsSpecials = Array(pool.prefix(6))
        
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                
                // --- 1. PICK YOUR MEAL (Рабочие кнопки) ---
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pick Your Meal")
                        .font(.title2).bold()
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            MealTypeCard(title: "Breakfast", subtitle: "Start your day right", emoji: "🥣", color: .themeYellow) {
                                openFiltered(title: "Breakfast", tags: ["Breakfast"])
                            }
                            MealTypeCard(title: "Lunch", subtitle: "Healthy & filling", emoji: "🥗", color: .green) {
                                openFiltered(title: "Lunch", tags: ["Lunch"])
                            }
                            MealTypeCard(title: "Dinner", subtitle: "Cozy evenings", emoji: "🍲", color: .themePink) {
                                openFiltered(title: "Dinner", tags: ["Dinner"])
                            }
                            MealTypeCard(title: "Snack", subtitle: "Quick bites", emoji: "🍎", color: .themeOrange) {
                                openFiltered(title: "Snack", tags: ["Snack"])
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                }
                .padding(.top, 10)
                
                // --- 2. BROWSE BY CALORIES (Рабочие фильтры) ---
                VStack(alignment: .leading, spacing: 16) {
                    Text("Browse by Calories")
                        .font(.title2).bold()
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(calorieRanges, id: \.0) { range in
                                Button(action: {
                                    HapticManager.shared.impact(style: .light)
                                    let filtered = allRecipes.filter { $0.caloriesPerServing >= range.2 && $0.caloriesPerServing <= range.3 }
                                    path.append(FoodsRoute.filteredList(range.0, filtered))
                                }) {
                                    CalorieRangeCard(title: range.0, color: range.1)
                                }
                                .buttonStyle(BounceButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                }
                
                // --- 3. РАЗБИВКА НА ТЕМАТИЧЕСКИЕ КАТЕГОРИИ (Без дубликатов) ---
                if !highProtein.isEmpty {
                    RecipeHorizontalSection(title: "High Protein Power", recipes: highProtein, path: $path)
                }
                if !ketoLowCarb.isEmpty {
                    RecipeHorizontalSection(title: "Low Carb & Keto", recipes: ketoLowCarb, path: $path)
                }
                if !quickEasy.isEmpty {
                    RecipeHorizontalSection(title: "Quick & Easy", recipes: quickEasy, path: $path)
                }
                if !plantBased.isEmpty {
                    RecipeHorizontalSection(title: "Plant-Based", recipes: plantBased, path: $path)
                }
                if !chefsSpecials.isEmpty {
                    RecipeHorizontalSection(title: "Chef's Specials", recipes: chefsSpecials, path: $path)
                }
                
            }
            .padding(.bottom, 120) // Отступ под TabBar
        }
    }
    
    private func openFiltered(title: String, tags: [String]) {
        HapticManager.shared.impact(style: .medium)
        let filtered = allRecipes.filter { recipe in
            !Set(recipe.tags).isDisjoint(with: Set(tags))
        }
        path.append(FoodsRoute.filteredList(title, filtered))
    }
}

// Карточка для Pick Your Meal
struct MealTypeCard: View {
    let title: String
    let subtitle: String
    let emoji: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.title3.bold()).foregroundColor(.white)
                    Text(subtitle).font(.caption).foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Text(emoji).font(.system(size: 50)).shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            }
            .padding(20).frame(width: 260, height: 110)
            .background(LinearGradient(colors: [color.opacity(0.8), color], startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(24).shadow(color: color.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// Новая компактная и премиальная карточка калорий
struct CalorieRangeCard: View {
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 5, y: 2)
    }
}

struct MyRecipesTabView: View {
    @Binding var path: NavigationPath
    let customRecipes: [CustomRecipe]
    let allRecipes: [PremiumRecipe]
    
    var favoriteRecipes: [PremiumRecipe] { allRecipes.filter { $0.isFavorite } }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                
                // --- 1. CUSTOM RECIPES (ТЕПЕРЬ ПЕРВЫЕ) ---
                VStack(alignment: .leading, spacing: 16) {
                    Text("Custom Recipes")
                        .font(.title2).bold()
                        .padding(.horizontal, 20)
                    
                    if customRecipes.isEmpty {
                        Button(action: { path.append(FoodsRoute.createRecipe) }) {
                            Text("Create custom recipe")
                                .font(.headline).foregroundColor(.themePink).frame(maxWidth: .infinity)
                                .padding(.vertical, 16).background(Color.themePink.opacity(0.15)).cornerRadius(24)
                        }
                        .padding(.horizontal, 20)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(customRecipes) { recipe in
                                    Button(action: { path.append(FoodsRoute.recipeDetail(recipe)) }) {
                                        CustomRecipeCard(
                                            title: recipe.name,
                                            calories: "\(recipe.totalCalories) kcal",
                                            items: recipe.info,
                                            cookingTime: recipe.cookingTime,
                                            difficulty: recipe.difficulty
                                        )
                                        .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Button(action: { path.append(FoodsRoute.createRecipe) }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create custom recipe")
                            }
                            .font(.headline).foregroundColor(.themePink).frame(maxWidth: .infinity)
                            .padding(.vertical, 16).background(Color.themePink.opacity(0.1)).cornerRadius(20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                }
                .padding(.top, 10)
                
                // --- 2. FAVORITES (ТЕПЕРЬ ВТОРЫЕ) ---
                VStack(alignment: .leading, spacing: 16) {
                    Text("My Favorites")
                        .font(.title2).bold()
                        .padding(.horizontal, 20)
                    
                    if favoriteRecipes.isEmpty {
                        Text("No favorites yet. Tap the star icon on any recipe to save it here.")
                            .font(.subheadline).foregroundColor(.gray)
                            .padding(.horizontal, 20)
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(favoriteRecipes) { recipe in
                                Button(action: { path.append(FoodsRoute.premiumRecipeDetail(recipe)) }) {
                                    PremiumRecipeCard(recipe: recipe)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 120)
        }
    }
}


// MARK: - 5. УЛЬТИМАТИВНЫЙ ФИЛЬТР (ADVANCED RECIPE FILTER SHEET)
struct AdvancedRecipeFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    
    let allRecipes: [PremiumRecipe]
    var onApply: (String, [PremiumRecipe]) -> Void
    
    @State private var selectedTags: Set<String> = []
    
    let meals = [("Breakfast", "cup.and.saucer.fill"), ("Lunch", "takeoutbag.and.cup.and.straw.fill"), ("Dinner", "fork.knife"), ("Snack", "apple.logo"), ("Smoothie", "drop.fill")]
    let prep = [("Quickly Prepared", "timer"), ("On the Go", "figure.walk"), ("Few Ingredients", "cart.fill"), ("Baking", "oven.fill"), ("Easy", "hand.thumbsup.fill")]
    let diets = [("Vegetarian", "leaf.fill", Color.green), ("Vegan", "leaf.arrow.circlepath", Color.mint), ("Low Carb", "meatcases.fill", Color.orange), ("High Protein", "dumbbell.fill", Color.blue), ("Ketogenic", "flame.fill", Color.red)]
    
    var filteredRecipes: [PremiumRecipe] {
          if selectedTags.isEmpty { return allRecipes }
          return allRecipes.filter { recipe in
              // Рецепт должен содержать ВСЕ выбранные теги
              selectedTags.isSubset(of: Set(recipe.tags))
          }
      }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Reset") {
                        HapticManager.shared.impact(style: .light)
                        selectedTags.removeAll()
                    }
                    .font(.subheadline.bold()).foregroundColor(.gray)
                    Spacer()
                    Text("Filters").font(.title2.bold())
                    Spacer()
                    Button("Close") { dismiss() }.font(.subheadline.bold()).foregroundColor(.themePink)
                }
                .padding(20)
                .background(Color.white)
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        FilterIconSection(title: "Meals", items: meals, selection: $selectedTags)
                        FilterIconSection(title: "Preparation Method", items: prep, selection: $selectedTags)
                        FilterColoredSection(title: "Diets", items: diets, selection: $selectedTags)
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }
            
            // Плавающая липкая кнопка
            VStack {
                Spacer()
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 100)
                        .mask(LinearGradient(colors: [.white, .white, .clear], startPoint: .bottom, endPoint: .top))
                    
                    Button(action: {
                        HapticManager.shared.impact(style: .heavy)
                        onApply("Filtered Recipes", filteredRecipes)
                        dismiss()
                    }) {
                        Text(filteredRecipes.isEmpty ? "No Recipes Found" : "See \(filteredRecipes.count) Recipes")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(filteredRecipes.isEmpty ? Color.gray : Color.themePink)
                            .cornerRadius(24)
                            .shadow(color: filteredRecipes.isEmpty ? .clear : Color.themePink.opacity(0.4), radius: 8, y: 4)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                    }
                    .disabled(filteredRecipes.isEmpty)
                    .buttonStyle(BounceButtonStyle())
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// Компонент фильтра с иконками
struct FilterIconSection: View {
    let title: String
    let items: [(String, String)]
    @Binding var selection: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline).foregroundColor(.primary)
            
            RecipeTagLayout(spacing: 12) {
                ForEach(items, id: \.0) { item in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        if selection.contains(item.0) { selection.remove(item.0) } else { selection.insert(item.0) }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: item.1)
                                .font(.system(size: 14))
                            Text(item.0)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(selection.contains(item.0) ? .white : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selection.contains(item.0) ? Color.themePink : Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 2)
                    }
                }
            }
        }
    }
}

// Компонент фильтра с цветными иконками (для Диет)
struct FilterColoredSection: View {
    let title: String
    let items: [(String, String, Color)]
    @Binding var selection: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(.headline).foregroundColor(.primary)
            
            RecipeTagLayout(spacing: 12) {
                ForEach(items, id: \.0) { item in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        if selection.contains(item.0) { selection.remove(item.0) } else { selection.insert(item.0) }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: item.1)
                                .font(.system(size: 14))
                                .foregroundColor(selection.contains(item.0) ? .white : item.2)
                            Text(item.0)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(selection.contains(item.0) ? .white : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(selection.contains(item.0) ? Color.themePink : Color.white)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.03), radius: 3, y: 2)
                    }
                }
            }
        }
    }
}


// MARK: - 6. ВЕРТИКАЛЬНАЯ СЕКЦИЯ (Для подкатегорий)
struct RecipeHorizontalSection: View {
    let title: String
    let recipes: [PremiumRecipe]
    @Binding var path: NavigationPath
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 👇 ИСПРАВЛЕНИЕ: Обернули заголовок в кнопку
            Button(action: {
                HapticManager.shared.impact(style: .light)
                // Открываем экран со списком всех рецептов этой категории
                path.append(FoodsRoute.filteredList(title, recipes))
            }) {
                HStack {
                    Text(title)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.primary)
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.system(size: 14, weight: .bold))
                    
                    Spacer()
                }
                .contentShape(Rectangle()) // Делает кликабельной всю строку, а не только текст
            }
            .buttonStyle(PlainButtonStyle()) // Чтобы текст не стал стандартным синим цветом кнопки
            .padding(.horizontal, 20)
            
            if recipes.isEmpty {
                Text("More recipes coming soon.")
                    .font(.subheadline).foregroundColor(.gray)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(recipes) { recipe in
                            Button(action: { path.append(FoodsRoute.premiumRecipeDetail(recipe)) }) {
                                PremiumRecipeCard(recipe: recipe, width: 280)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
            }
        }
    }
}

// MARK: - 7. ПЕРЕИСПОЛЬЗУЕМЫЕ КОМПОНЕНТЫ ИЗ ПРОШЛОГО ШАГА (Карточки, Детали, Диаграмма)

struct PremiumRecipeCard: View {
    let recipe: PremiumRecipe
    var width: CGFloat? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: recipe.imageUrl)) { phase in
                    if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) } else { Rectangle().fill(Color.gray.opacity(0.2)).overlay(ProgressView()) }
                }.frame(height: 160).clipped()
                
                if recipe.isFavorite {
                    Image(systemName: "star.fill").foregroundColor(.themeYellow).padding(12).background(Color.black.opacity(0.3)).clipShape(Circle()).padding(8)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.primary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Text(recipe.time)
                    Text("\(recipe.caloriesPerServing) Cal")
                }.font(.subheadline).foregroundColor(.gray)
            }.padding(16)
        }.frame(width: width).background(Color.white).cornerRadius(24).shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }
}

// Карточка кастомного рецепта
struct CustomRecipeCard: View {
    let title: String
    let calories: String
    let items: String
    let cookingTime: Int?
    let difficulty: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).lineLimit(1)
            Text(items).font(.caption).foregroundColor(.gray).lineLimit(2)
            HStack(spacing: 12) {
                if let cookingTime = cookingTime {
                    HStack(spacing: 4) { Image(systemName: "clock.fill").font(.caption); Text("\(cookingTime)m").font(.caption) }.foregroundColor(.gray)
                }
                if let difficulty = difficulty { Text(difficulty).font(.caption2.bold()).foregroundColor(.themeOrange) }
                Spacer()
            }
            Spacer()
            Text(calories).font(.headline).foregroundColor(.themePink)
        }
        .padding().frame(width: 160, height: 140).background(Color.white).cornerRadius(16).shadow(color: Color.black.opacity(0.04), radius: 5, y: 2)
    }
}

struct PremiumRecipeDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @State var recipe: PremiumRecipe
    @State private var servings: Int
    @State private var showMealSheet = false
    @Environment(RecipeDataLoader.self) private var dataLoader
    init(recipe: PremiumRecipe) { self._recipe = State(initialValue: recipe); self._servings = State(initialValue: recipe.baseServings) }
    
    private var multiplier: Double { Double(servings) / Double(max(recipe.baseServings, 1)) }
    private var dynamicCalories: Int { Int(Double(recipe.caloriesPerServing * recipe.baseServings) * multiplier) }
    private var dynamicProtein: Int { Int(recipe.protein * Double(recipe.baseServings) * multiplier) }
    private var dynamicFat: Int { Int(recipe.fat * Double(recipe.baseServings) * multiplier) }
    private var dynamicCarbs: Int { Int(recipe.carbs * Double(recipe.baseServings) * multiplier) }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    ZStack(alignment: .bottomLeading) {
                        
                        // 👇 ИСПРАВЛЕНИЕ ЗДЕСЬ: Добавлено .frame(maxWidth: .infinity)
                        AsyncImage(url: URL(string: recipe.imageUrl)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.2))
                            }
                        }
                        .frame(maxWidth: .infinity) // <--- ВОТ ЭТА СТРОКА РЕШАЕТ ПРОБЛЕМУ С ЗУМОМ
                        .frame(height: 320)
                        .clipped()
                        
                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(recipe.title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(3)
                            
                            HStack(spacing: 16) {
                                Label(recipe.time, systemImage: "clock")
                                Label("\(recipe.caloriesPerServing) Cal", systemImage: "flame")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(20)
                    }
                    .recipeCustomCornerRadius(32, corners: [.bottomLeft, .bottomRight])
                    .ignoresSafeArea(edges: .top)
                    
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(recipe.description).font(.body).foregroundColor(.gray).lineSpacing(4)
                            RecipeTagLayout(spacing: 8) { ForEach(recipe.tags, id: \.self) { tag in Text(tag).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.gray).padding(.horizontal, 12).padding(.vertical, 8).background(Color.gray.opacity(0.15)).cornerRadius(16) } }
                        }.padding(.horizontal, 20)
                        
                        VStack(alignment: .leading, spacing: 24) {
                            RecipeMacroDonutView(calories: dynamicCalories, protein: Double(dynamicProtein), fat: Double(dynamicFat), carbs: Double(dynamicCarbs))
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Serving size").font(.headline)
                                HStack(spacing: 12) {
                                    HStack {
                                        Button(action: { if servings > 1 { servings -= 1; HapticManager.shared.impact(style: .light) }}) { Image(systemName: "minus").foregroundColor(.gray) }
                                        Spacer(); Text("\(servings)").font(.title3.bold()); Spacer()
                                        Button(action: { servings += 1; HapticManager.shared.impact(style: .light) }) { Image(systemName: "plus").foregroundColor(.gray) }
                                    }.padding().frame(width: 120).background(Color.white).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                    HStack {
                                        Text("Serving (\(Int(160 * multiplier)) g)").font(.subheadline.bold()).foregroundColor(.gray)
                                        Spacer(); Image(systemName: "chevron.down").foregroundColor(.gray.opacity(0.5))
                                    }.padding().frame(maxWidth: .infinity).background(Color.white).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.2), lineWidth: 1))
                                }
                            }
                        }.padding(.horizontal, 20)
                        
                        if !recipe.ingredients.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Ingredients").font(.title2).bold()
                                VStack(spacing: 16) {
                                    ForEach(recipe.ingredients, id: \.name) { ingredient in
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 4) { Text(ingredient.name).font(.headline); Text("\(Int(Double(ingredient.calories) * multiplier)) Cal — \(ingredient.amount)").font(.caption).foregroundColor(.gray) }
                                            Spacer()
                                        }
                                        Divider()
                                    }
                                }
                            }.padding(.horizontal, 20)
                        }
                        
                        // БЛОК ШАГОВ
                        if !recipe.directions.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Directions").font(.title2).bold()
                                VStack(alignment: .leading, spacing: 24) {
                                    ForEach(Array(recipe.directions.enumerated()), id: \.offset) { index, step in
                                        HStack(alignment: .top, spacing: 16) {
                                            Text("\(index + 1)")
                                                .font(.headline)
                                                .foregroundColor(.themePink)
                                                .frame(width: 32, height: 32)
                                                .background(Color.white)
                                                .overlay(Circle().stroke(Color.themePink, lineWidth: 2))
                                                .clipShape(Circle())
                                            Text(step)
                                                .font(.body)
                                                .foregroundColor(.primary.opacity(0.9))
                                                .lineSpacing(4)
                                                .padding(.top, 4)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Directions").font(.title2).bold()
                                Text("Cooking instructions are not available for this recipe yet.")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .italic()
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer().frame(height: 120)
                    }.offset(y: -20)
                }
            }.ignoresSafeArea(edges: .top)
            
            // Навигационный бар с кнопками (Назад, Поделиться, Избранное)
            VStack {
                HStack {
                    Button(action: { dismiss() }) { Image(systemName: "chevron.left").font(.title3.bold()).foregroundColor(.primary).frame(width: 40, height: 40).background(.ultraThinMaterial).clipShape(Circle()) }
                    Spacer(); Text("Recipe Info").font(.headline).foregroundColor(.white).shadow(radius: 2); Spacer()
                    HStack(spacing: 12) {
                        // Кнопка Share
                        Button(action: { /* Share */ }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        
                        // ✅ ИСПРАВЛЕННАЯ КНОПКА ИЗБРАННОГО
                        Button(action: {
                            HapticManager.shared.impact(style: .medium)
                            
                            // 1. Локально меняем состояние для мгновенной анимации
                            withAnimation(.spring()) {
                                recipe.isFavorite.toggle()
                            }
                            
                            // 2. Отправляем сигнал в наш глобальный загрузчик данных
                            dataLoader.toggleFavorite(for: recipe.id)
                            
                        }) {
                            Image(systemName: recipe.isFavorite ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundColor(recipe.isFavorite ? .themeYellow : .white)
                                .shadow(radius: 2)
                        }
                    }.frame(width: 70, alignment: .trailing)
                }.padding(.horizontal, 20).padding(.top, 50)
                Spacer()
            }
            
            // Нижняя кнопка Add to Meal
            VStack {
                Spacer()
                ZStack {
                    Rectangle().fill(.ultraThinMaterial).frame(height: 110).mask(LinearGradient(colors: [.white, .white, .clear], startPoint: .bottom, endPoint: .top))
                    Button(action: { HapticManager.shared.impact(style: .heavy); showMealSheet = true }) {
                        Text("Add to meal").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18).background(Color.themePink).cornerRadius(24).shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4).padding(.horizontal, 24).padding(.bottom, 30)
                    }.buttonStyle(BounceButtonStyle())
                }
            }.ignoresSafeArea(edges: .bottom)
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showMealSheet) {
            ChooseMealSheet(recipe: recipe, calories: dynamicCalories, p: Double(dynamicProtein), f: Double(dynamicFat), c: Double(dynamicCarbs))
                .presentationDetents([.fraction(0.4)]).presentationCornerRadius(32).presentationDragIndicator(.visible)
        }
    }
}

// Экран для вывода отфильтрованного списка
struct FilteredRecipesListView: View {
    @Environment(\.dismiss) private var dismiss
    
    let title: String
    let recipes: [PremiumRecipe]
    @Binding var path: NavigationPath
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Кастомный навигационный бар
            HStack {
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
                }
                
                Spacer()
                
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Пустая вьюшка для симметрии (чтобы заголовок был ровно по центру)
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .background(Color.themeBg)
            .zIndex(1)
            
            // 2. Список рецептов
            ScrollView(showsIndicators: false) {
                if recipes.isEmpty {
                    // Красивая заглушка, если по фильтрам ничего не найдено
                    EmptyStateView(
                        imageName: "magnifyingglass",
                        title: "No Recipes Found",
                        description: "Try adjusting your filters to see more results."
                    )
                    .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(recipes) { recipe in
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                path.append(FoodsRoute.premiumRecipeDetail(recipe))
                            }) {
                                // Карточка рецепта
                                PremiumRecipeCard(recipe: recipe)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 120) // Отступ, чтобы карточки не прятались за нижний TabBar
                }
            }
        }
        .background(Color.themeBg.ignoresSafeArea())
        .navigationBarHidden(true) // Убираем стандартный бар, так как у нас свой кастомный
    }
}
// Остальные вспомогательные структуры из прошлого шага свернуты для экономии места:
struct ChooseMealSheet: View {
    @Environment(\.dismiss) var dismiss; @Environment(\.modelContext) private var context; @Query private var summaries: [DailySummary]
    let recipe: PremiumRecipe; let calories: Int; let p: Double; let f: Double; let c: Double
    @State private var selectedMeal = "Dinner"; let meals = ["Breakfast", "Lunch", "Dinner", "Snack"]
    var body: some View {
        VStack(spacing: 24) {
            Text("Choose a meal").font(.title2.bold()).padding(.top, 24)
            Picker("Meal", selection: $selectedMeal) { ForEach(meals, id: \.self) { meal in Text(meal).tag(meal) } }.pickerStyle(.wheel).frame(height: 120)
            Button(action: { HapticManager.shared.impact(style: .heavy); saveToDiary(); dismiss() }) { Text("Select").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18).background(Color.themePink).cornerRadius(24).shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4) }.buttonStyle(BounceButtonStyle()).padding(.horizontal, 24).padding(.bottom, 20)
        }.background(Color.themeBg.ignoresSafeArea())
    }
    private func saveToDiary() {
        let calendar = Calendar.current; let today = calendar.startOfDay(for: .now); let summary: DailySummary
        if let existing = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) { summary = existing } else { summary = DailySummary(date: today); context.insert(summary) }
        let newFood = FoodItem(name: recipe.title, weight: 100, calories: calories, protein: p, fats: f, carbs: c)
        if let meal = summary.meals.first(where: { $0.title == selectedMeal }) { meal.foodItems.append(newFood) } else {
            let newMeal = Meal(title: selectedMeal, date: .now, foodItems: [newFood]); context.insert(newMeal); summary.meals.append(newMeal)
        }
        try? context.save()
    }
}

extension View { func recipeCustomCornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View { clipShape(RecipeRoundedCorner(radius: radius, corners: corners)) } }
struct RecipeRoundedCorner: Shape { var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners; func path(in rect: CGRect) -> Path { let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)); return Path(path.cgPath) } }
struct RecipeTagLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { let rows = computeRows(proposal: proposal, subviews: subviews); let height = rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * spacing; return CGSize(width: proposal.width ?? 0, height: height) }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) { let rows = computeRows(proposal: proposal, subviews: subviews); var y = bounds.minY; for row in rows { var x = bounds.minX; for element in row.elements { let size = element.view.sizeThatFits(.unspecified); element.view.place(at: CGPoint(x: x, y: y), proposal: .unspecified); x += size.width + spacing }; y += row.maxHeight + spacing } }
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] { var rows: [Row] = []; var currentRow = Row(); var currentX: CGFloat = 0; let maxWidth = proposal.width ?? UIScreen.main.bounds.width; for subview in subviews { let size = subview.sizeThatFits(.unspecified); if currentX + size.width > maxWidth && !currentRow.elements.isEmpty { rows.append(currentRow); currentRow = Row(); currentX = 0 }; currentRow.elements.append(Element(view: subview, size: size)); currentRow.maxHeight = max(currentRow.maxHeight, size.height); currentX += size.width + spacing }; if !currentRow.elements.isEmpty { rows.append(currentRow) }; return rows }
    private struct Row { var elements: [Element] = []; var maxHeight: CGFloat = 0 }
    private struct Element { let view: LayoutSubview; let size: CGSize }
}
