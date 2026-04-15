import SwiftUI
import SwiftData

// MARK: - 1. MOCK DATA MODELS
struct PremiumRecipe: Identifiable, Hashable {
    let id = UUID()
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
    let nutritionFacts: [NutritionFact]
}

struct RecipeIngredient: Hashable {
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

var mockRecipesData = [
    PremiumRecipe(
        title: "Baked Apples with Honey & Walnuts",
        description: "Simple to make, comforting to enjoy, and perfect for cozy evenings. 🍂",
        time: "20 min", caloriesPerServing: 249,
        imageUrl: "https://images.unsplash.com/photo-1511690656952-34342bb7c2f2?q=80&w=800&auto=format&fit=crop",
        isFavorite: true, tags: ["Breakfast", "Snack", "Vegetarian"], baseServings: 4,
        protein: 3.0, fat: 11.0, carbs: 40.5,
        ingredients: [RecipeIngredient(name: "Walnuts", amount: "65 g", weightGrams: 65, calories: 425)],
        directions: ["Core apples.", "Bake at 180°C."], nutritionFacts: []
    ),
    PremiumRecipe(
        title: "Creamy Pumpkin Risotto with Gorgonzola",
        description: "A rich and creamy autumn classic.",
        time: "40 min", caloriesPerServing: 441,
        imageUrl: "https://images.unsplash.com/photo-1608897013039-887f21d8c804?q=80&w=800&auto=format&fit=crop",
        isFavorite: false, tags: ["Dinner", "Vegetarian"], baseServings: 2,
        protein: 14.0, fat: 18.0, carbs: 55.0,
        ingredients: [], directions: [], nutritionFacts: []
    ),
    PremiumRecipe(
        title: "Chicken and Wild Rice Bowl",
        description: "High protein, low calorie perfect lunch.",
        time: "25 min", caloriesPerServing: 504,
        imageUrl: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?q=80&w=800&auto=format&fit=crop",
        isFavorite: true, tags: ["Lunch", "High Protein"], baseServings: 2,
        protein: 38.8, fat: 8.6, carbs: 66.5,
        ingredients: [], directions: [], nutritionFacts: []
    )
]

// MARK: - 2. MAIN RECIPES CONTAINER (РАЗДЕЛЕН НА ВКЛАДКИ)
struct RecipesContainerView: View {
    @Binding var path: NavigationPath
    @Query(sort: \CustomRecipe.name) private var customRecipes: [CustomRecipe]
    
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
            
            // --- CONTENT VIEWS ---
            TabView(selection: $selectedTab) {
                DiscoverTabView(path: $path)
                    .tag(0)
                
                MyRecipesTabView(path: $path, customRecipes: customRecipes)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: selectedTab)
        }
        .background(Color.themeBg.ignoresSafeArea())
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilters) {
            AdvancedRecipeFilterSheet()
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
    
    let calorieRanges = [
        ("50-100 Cal", "🍉", Color.red),
        ("100-200 Cal", "🥪", Color.orange),
        ("200-300 Cal", "🥯", Color.themeYellow),
        ("300-400 Cal", "🥞", Color.themePink),
        ("400-500 Cal", "🍛", Color.blue),
        ("500-600 Cal", "🍱", Color.purple)
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                
                // --- 1. PICK YOUR MEAL (Large Horizontal Cards) ---
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pick Your Meal")
                        .font(.title2).bold()
                        .padding(.horizontal, 20)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            MealTypeCard(title: "Breakfast", subtitle: "Start your day right", emoji: "🥣", color: .themeYellow)
                            MealTypeCard(title: "Lunch", subtitle: "Healthy & filling", emoji: "🥗", color: .green)
                            MealTypeCard(title: "Dinner", subtitle: "Cozy evenings", emoji: "🍲", color: .themePink)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                }
                .padding(.top, 10)
                
                // --- 2. RECIPES BY CALORIE RANGE (Grid) ---
                VStack(alignment: .leading, spacing: 16) {
                    Text("Recipes by Calorie Range")
                        .font(.title2).bold()
                        .padding(.horizontal, 20)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(calorieRanges, id: \.0) { range in
                            Button(action: { HapticManager.shared.impact(style: .medium) }) {
                                CalorieRangeCard(title: range.0, emoji: range.1, color: range.2)
                            }
                            .buttonStyle(BounceButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // --- 3. TRENDING NOW ---
                RecipeHorizontalSection(title: "Trending Now", recipes: mockRecipesData, path: $path)
                
            }
            .padding(.bottom, 120)
        }
    }
}

// Карточка для Calorie Range (с эффектом цветного пятна)
struct CalorieRangeCard: View {
    let title: String
    let emoji: String
    let color: Color
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Мягкое цветное пятно на фоне (Soft Glassmorphism effect)
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 80, height: 80)
                .offset(x: 20, y: -20)
                .blur(radius: 10)
            
            VStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 40))
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 5)
                
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
        .clipped()
    }
}

// Карточка для Pick Your Meal
struct MealTypeCard: View {
    let title: String
    let subtitle: String
    let emoji: String
    let color: Color
    
    var body: some View {
        Button(action: { HapticManager.shared.impact(style: .medium) }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                Text(emoji)
                    .font(.system(size: 50))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            }
            .padding(20)
            .frame(width: 260, height: 110)
            .background(
                LinearGradient(colors: [color.opacity(0.8), color], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(24)
            .shadow(color: color.opacity(0.3), radius: 10, y: 5)
        }
        .buttonStyle(BounceButtonStyle())
    }
}


// MARK: - 4. MY RECIPES TAB (Избранное + Свои рецепты)
struct MyRecipesTabView: View {
    @Binding var path: NavigationPath
    let customRecipes: [CustomRecipe]
    
    var favoriteRecipes: [PremiumRecipe] { mockRecipesData.filter { $0.isFavorite } }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                
                // --- FAVORITES ---
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
                .padding(.top, 10)
                
                // --- CUSTOM RECIPES ---
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
                        
                        // Кнопка на всю ширину внизу
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
            }
            .padding(.bottom, 120)
        }
    }
}


// MARK: - 5. УЛЬТИМАТИВНЫЙ ФИЛЬТР (ADVANCED RECIPE FILTER SHEET)
struct AdvancedRecipeFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTags: Set<String> = []
    
    // Структуры с иконками для красивого отображения
    let meals = [("Breakfast", "cup.and.saucer.fill"), ("Lunch", "takeoutbag.and.cup.and.straw.fill"), ("Dinner", "fork.knife"), ("Snack", "apple.logo"), ("Smoothie", "drop.fill")]
    let prep = [("Quickly Prepared", "timer"), ("On the Go", "figure.walk"), ("Few Ingredients", "cart.fill"), ("Baking", "oven.fill"), ("Easy", "hand.thumbsup.fill")]
    let diets = [("Vegetarian", "leaf.fill", Color.green), ("Vegan", "leaf.arrow.circlepath", Color.mint), ("Low Carb", "meatcases.fill", Color.orange), ("High Protein", "dumbbell.fill", Color.blue), ("Ketogenic", "flame.fill", Color.red)]
    
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
                    .padding(.bottom, 100) // Место под кнопку
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
                        dismiss()
                    }) {
                        Text("See 2137 Recipes") // Мок-цифра
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.themePink)
                            .cornerRadius(24)
                            .shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 20)
                    }
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
            HStack {
                Text(title).font(.title2).bold().foregroundColor(.primary)
                Image(systemName: "chevron.right").foregroundColor(.gray.opacity(0.6)).font(.system(size: 14, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            
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


// MARK: - ЭКРАНЫ ДЕТАЛИЗАЦИИ
struct PremiumRecipeDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @State var recipe: PremiumRecipe
    @State private var servings: Int
    @State private var showMealSheet = false
    
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
                        AsyncImage(url: URL(string: recipe.imageUrl)) { phase in
                            if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) } else { Rectangle().fill(Color.gray.opacity(0.2)) }
                        }.frame(height: 320).clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .center, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 12) {
                            Text(recipe.title).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white).lineLimit(3)
                            HStack(spacing: 16) { Label(recipe.time, systemImage: "clock"); Label("\(recipe.caloriesPerServing) Cal", systemImage: "flame") }.font(.subheadline.bold()).foregroundColor(.white.opacity(0.9))
                        }.padding(20)
                    }.recipeCustomCornerRadius(32, corners: [.bottomLeft, .bottomRight]).ignoresSafeArea(edges: .top)
                    
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
                        
                        Spacer().frame(height: 120)
                    }.offset(y: -20)
                }
            }.ignoresSafeArea(edges: .top)
            
            VStack {
                HStack {
                    Button(action: { dismiss() }) { Image(systemName: "chevron.left").font(.title3.bold()).foregroundColor(.primary).frame(width: 40, height: 40).background(.ultraThinMaterial).clipShape(Circle()) }
                    Spacer(); Text("Recipe Info").font(.headline).foregroundColor(.white).shadow(radius: 2); Spacer()
                    HStack(spacing: 12) {
                        Button(action: { /* Share */ }) { Image(systemName: "square.and.arrow.up").font(.title3).foregroundColor(.white).shadow(radius: 2) }
                        Button(action: { HapticManager.shared.impact(style: .medium); withAnimation(.spring()) { recipe.isFavorite.toggle() }; if let idx = mockRecipesData.firstIndex(where: { $0.id == recipe.id }) { mockRecipesData[idx].isFavorite = recipe.isFavorite } }) { Image(systemName: recipe.isFavorite ? "star.fill" : "star").font(.title3).foregroundColor(recipe.isFavorite ? .themeYellow : .white).shadow(radius: 2) }
                    }.frame(width: 70, alignment: .trailing)
                }.padding(.horizontal, 20).padding(.top, 50)
                Spacer()
            }
            
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
        .sheet(isPresented: $showMealSheet) {
            ChooseMealSheet(recipe: recipe, calories: dynamicCalories, p: Double(dynamicProtein), f: Double(dynamicFat), c: Double(dynamicCarbs))
                .presentationDetents([.fraction(0.4)]).presentationCornerRadius(32).presentationDragIndicator(.visible)
        }
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
