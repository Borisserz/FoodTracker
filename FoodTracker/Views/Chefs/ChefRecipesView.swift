import SwiftUI
import SwiftData
import FirebaseFirestore
struct PremiumRecipe: Identifiable, Hashable, Codable {
    @DocumentID var id: String? // Оставляем так
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


struct RecipesContainerView: View {
    @Binding var path: NavigationPath
    @Query(sort: \CustomRecipe.name) private var customRecipes: [CustomRecipe]

    @Environment(RecipeDataLoader.self) private var dataLoader

    @State private var selectedTab: Int = 0
    @State private var searchText = ""
    @State private var showFilters = false

    @Namespace private var animation

    var body: some View {
        VStack(spacing: 0) {

            HStack {
                TabButton(title: String(localized: "Discover"), tabIndex: 0, selectedTab: $selectedTab, animation: animation)
                TabButton(title: String(localized: "My Recipes"), tabIndex: 1, selectedTab: $selectedTab, animation: animation)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 10)
            .background(Color.themeBg)

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
        .sheet(isPresented: $showFilters) {
            AdvancedRecipeFilterSheet(allRecipes: dataLoader.recipes) { title, filtered in

                path.append(FoodsRoute.filteredList(title, filtered))
            }
            .presentationDragIndicator(.visible)
        }
        .navigationDestination(for: PremiumRecipe.self) { recipe in
            PremiumRecipeDetailView(recipe: recipe)
        }
    }
}

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

        var pool = allRecipes

        let highProtein = pool.filter { $0.tags.contains("High Protein") }
        pool.removeAll { r in highProtein.contains(where: { $0.id == r.id }) }

        let ketoLowCarb = pool.filter { $0.tags.contains("Low Carb") || $0.tags.contains("Ketogenic") }
        pool.removeAll { r in ketoLowCarb.contains(where: { $0.id == r.id }) }

        let quickEasy = pool.filter { $0.tags.contains("Quickly Prepared") || $0.tags.contains("Easy") }
        pool.removeAll { r in quickEasy.contains(where: { $0.id == r.id }) }

        let plantBased = pool.filter { $0.tags.contains("Vegan") || $0.tags.contains("Vegetarian") }
        pool.removeAll { r in plantBased.contains(where: { $0.id == r.id }) }

        let chefsSpecials = Array(pool.prefix(6))

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {

                VStack(alignment: .leading, spacing: 16) {
                    Text("Pick Your Meal")
                        .font(.title2).bold()
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            MealTypeCard(title: String(localized: "Breakfast"), subtitle: String(localized: "Start your day right"), imageUrl: "https://images.unsplash.com/photo-1525351484163-7529414344d8?q=80&w=400", color: .themeYellow) {
                                openFiltered(title: String(localized: "Breakfast"), tags: ["Breakfast"])
                            }
                            MealTypeCard(title: String(localized: "Lunch"), subtitle: String(localized: "Healthy & filling"), imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=400", color: .green) {
                                openFiltered(title: String(localized: "Lunch"), tags: ["Lunch"])
                            }
                            MealTypeCard(title: String(localized: "Dinner"), subtitle: String(localized: "Cozy evenings"), imageUrl: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=400", color: .themePink) {
                                openFiltered(title: String(localized: "Dinner"), tags: ["Dinner"])
                            }
                            MealTypeCard(title: String(localized: "Snack"), subtitle: String(localized: "Quick bites"), imageUrl: "https://images.unsplash.com/photo-1505253716362-afaea1d3d1af?q=80&w=400", color: .themeOrange) {
                                openFiltered(title: String(localized: "Snack"), tags: ["Snack"])
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                }
                .padding(.top, 10)

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

                if !highProtein.isEmpty {
                    RecipeHorizontalSection(title: String(localized: "High Protein Power"), recipes: highProtein, path: $path)
                }
                if !ketoLowCarb.isEmpty {
                    RecipeHorizontalSection(title: String(localized: "Low Carb & Keto"), recipes: ketoLowCarb, path: $path)
                }
                if !quickEasy.isEmpty {
                    RecipeHorizontalSection(title: String(localized: "Quick & Easy"), recipes: quickEasy, path: $path)
                }
                if !plantBased.isEmpty {
                    RecipeHorizontalSection(title: String(localized: "Plant-Based"), recipes: plantBased, path: $path)
                }
                if !chefsSpecials.isEmpty {
                    RecipeHorizontalSection(title: String(localized: "Chef's Specials"), recipes: chefsSpecials, path: $path)
                }

            }
            .padding(.bottom, 120)
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

struct MealTypeCard: View {
    let title: String
    let subtitle: String
    let imageUrl: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Background food image with placeholder
                AsyncImage(url: URL(string: imageUrl)) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(AINutritionService.shared.fallbackLocalImage(for: title))
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        LinearGradient(
                            colors: [color.opacity(0.85), color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(width: 260, height: 110)
                .clipped()
                
                // Dark gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55), .black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(subtitle)
                            .font(.system(.caption, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                    Spacer()
                    
                    // Glassmorphic circle with chevron
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(14)
            }
            .frame(width: 260, height: 110)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

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
    @Environment(\.modelContext) private var context

    var favoriteRecipes: [PremiumRecipe] { allRecipes.filter { $0.isFavorite } }

    private func deleteCustomRecipe(_ recipe: CustomRecipe) {
        HapticManager.shared.impact(style: .medium)
        withAnimation {
            context.delete(recipe)
            try? context.save()
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {

                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    path.append(FoodsRoute.createRecipe)
                }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.2)).frame(width: 48, height: 48)
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create Custom Recipe")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Combine ingredients & calculate macros")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(20)
                    .background(
                        LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(24)
                    .shadow(color: Color.themePink.opacity(0.3), radius: 15, y: 8)
                }
                .buttonStyle(BounceButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 16) {
                    Text("My Creations")
                        .font(.title2).bold()
                        .padding(.horizontal, 20)

                    if customRecipes.isEmpty {
                        EmptyStateView(
                            imageName: "frying.pan",
                            title: String(localized: "No custom recipes yet"),
                            description: String(localized: "Your culinary masterpieces will appear here.")
                        )
                        .frame(height: 150)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(customRecipes) { recipe in
                                Button(action: {
                                    HapticManager.shared.impact(style: .light)
                                    path.append(FoodsRoute.recipeDetail(recipe))
                                }) {
                                    CustomRecipePremiumCard(recipe: recipe)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteCustomRecipe(recipe)
                                    } label: {
                                        Label("Delete Recipe", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    Text("Saved Favorites")
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

struct CustomRecipePremiumCard: View {
    let recipe: CustomRecipe

    var body: some View {

        let macros = recipe.toFoodItem()

        VStack(spacing: 0) {

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.info.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.themePink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.themePink.opacity(0.15))
                        .clipShape(Capsule())

                    Text(recipe.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 12) {
                        Label("\(recipe.cookingTime) min", systemImage: "clock.fill")
                        Label("\(recipe.servings) servings", systemImage: "person.2.fill")
                    }
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                }
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.1), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: 0.8)
                        .stroke(Color.themePink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(recipe.totalCalories)")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                        Text("kcal")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 60, height: 60)
            }
            .padding(20)

            Divider().padding(.horizontal, 20)

            HStack(spacing: 20) {
                MacroPill(title: String(localized: "Carbs"), value: macros.carbs, color: .drinkWater)
                MacroPill(title: String(localized: "Fats"), value: macros.fats, color: .themeYellow)
                MacroPill(title: String(localized: "Protein"), value: macros.protein, color: .themePeach)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.03))
        }
        .background(Color.white)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
    }
}

struct MacroPill: View {
    let title: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text("\(Int(value))g")
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

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

              selectedTags.isSubset(of: Set(recipe.tags))
          }
      }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()

            VStack(spacing: 0) {

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
                        FilterIconSection(title: String(localized: "Meals"), items: meals, selection: $selectedTags)
                        FilterIconSection(title: String(localized: "Preparation Method"), items: prep, selection: $selectedTags)
                        FilterColoredSection(title: String(localized: "Diets"), items: diets, selection: $selectedTags)
                    }
                    .padding(20)
                    .padding(.bottom, 100)
                }
            }

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

struct RecipeHorizontalSection: View {
    let title: String
    let recipes: [PremiumRecipe]
    @Binding var path: NavigationPath
    @Environment(RecipeDataLoader.self) private var dataLoader
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Button(action: {
                HapticManager.shared.impact(style: .light)

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
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
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
                                PremiumRecipeCard(recipe: recipe)
                            }
                            .buttonStyle(BounceButtonStyle())
                            .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 16)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

struct PremiumRecipeCard: View {
    let recipe: PremiumRecipe
    var width: CGFloat? = nil

    var body: some View {
        // Always resolve an image — use stored URL or generate one from the title.
        let effectiveUrl = recipe.imageUrl.isEmpty
            ? AINutritionService.shared.imageUrl(forMealTitle: recipe.title)
            : recipe.imageUrl

        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: effectiveUrl)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        // Network failed — use local asset fallback
                        Image(AINutritionService.shared.fallbackLocalImage(for: recipe.title))
                            .resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(Color.gray.opacity(0.2)).overlay(ProgressView())
                    }
                }.frame(height: 160).clipped()

                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)

                if let firstTag = recipe.tags.first {
                    Text(firstTag.uppercased())
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial).environment(\.colorScheme, .dark)
                        .clipShape(Capsule())
                        .padding(12)
                }

                if recipe.isFavorite {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill").foregroundStyle(Color.themeYellow).padding(10).background(.ultraThinMaterial).clipShape(Circle()).padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 160)

            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.title).font(.system(.headline, design: .rounded, weight: .bold)).foregroundStyle(.primary).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    Text(recipe.time)
                    Text("\(recipe.caloriesPerServing) Cal")
                }.font(.subheadline).foregroundStyle(.secondary)
            }.padding(16)
        }
        .frame(width: width)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
    }
}

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
    @State private var isGeneratingRecipe = false
    @State private var generatedRecipe: AIChefRecipe? = nil
    @State private var showAIFlow = false
    @State private var showAddedToast = false
    @Environment(RecipeDataLoader.self) private var dataLoader
    init(recipe: PremiumRecipe) { self._recipe = State(initialValue: recipe); self._servings = State(initialValue: recipe.baseServings) }

    private var multiplier: Double { Double(servings) / Double(max(recipe.baseServings, 1)) }
    private var dynamicCalories: Int { Int(Double(recipe.caloriesPerServing * recipe.baseServings) * multiplier) }
    private var dynamicProtein: Int { Int(recipe.protein * Double(recipe.baseServings) * multiplier) }
    private var dynamicFat: Int { Int(recipe.fat * Double(recipe.baseServings) * multiplier) }
    private var dynamicCarbs: Int { Int(recipe.carbs * Double(recipe.baseServings) * multiplier) }

    private func generateAI() {
        guard !isGeneratingRecipe else { return }
        isGeneratingRecipe = true
        HapticManager.shared.impact(style: .medium)
        
        Task {
            let ingredientsList = recipe.ingredients.map { "\($0.name) (\($0.amount))" }
            if let dto = await AINutritionService.shared.generateCookingSteps(for: recipe.title, ingredients: ingredientsList) {
                let ai = AIChefRecipe(
                    title: dto.title,
                    calories: dto.calories,
                    protein: dto.protein,
                    heroImage: recipe.imageUrl.isEmpty ? "sparkles" : "fork.knife",
                    cookTime: dto.cookTime,
                    difficulty: dto.difficulty,
                    history: dto.history,
                    ingredients: dto.ingredients,
                    steps: dto.steps.map { RecipeStep(instruction: $0.instruction, imageName: "sparkles", aiTip: $0.aiTip) },
                    platingTip: dto.platingTip
                )
                await MainActor.run {
                    self.generatedRecipe = ai
                    self.isGeneratingRecipe = false
                    self.showAIFlow = true
                }
            } else {
                await MainActor.run { self.isGeneratingRecipe = false }
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    ZStack(alignment: .bottomLeading) {
                        // Always show a matching image
                        let effectiveDetailUrl = recipe.imageUrl.isEmpty
                            ? AINutritionService.shared.imageUrl(forMealTitle: recipe.title)
                            : recipe.imageUrl

                        AsyncImage(url: URL(string: effectiveDetailUrl)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else if phase.error != nil {
                                Image(AINutritionService.shared.fallbackLocalImage(for: recipe.title))
                                    .resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(Color.gray.opacity(0.2))
                            }
                        }
                        .frame(maxWidth: .infinity)
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

                                                        HStack {
                                                            Text("Ingredients").font(.title2).bold()
                                                            Spacer()
                                                            Button(action: {
                                                                HapticManager.shared.impact(style: .heavy)

                                                                for ingredient in recipe.ingredients {
                                                                    let item = ShoppingItem(name: ingredient.name, amount: ingredient.amount, addedFromRecipe: recipe.title)
                                                                    context.insert(item)
                                                                }
                                                                try? context.save()
                                                                
                                                                withAnimation(.spring()) {
                                                                    showAddedToast = true
                                                                }
                                                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                                    withAnimation(.spring()) { showAddedToast = false }
                                                                }

                                                            }) {
                                                                HStack(spacing: 4) {
                                                                    Image(systemName: "cart.badge.plus")
                                                                    Text("Add to List")
                                                                }
                                                                .font(.caption.bold())
                                                                .foregroundColor(.themePink)
                                                                .padding(.horizontal, 12)
                                                                .padding(.vertical, 8)
                                                                .background(Color.themePink.opacity(0.1))
                                                                .clipShape(Capsule())
                                                            }
                                                        }

                                                        VStack(spacing: 16) {
                                                            ForEach(recipe.ingredients, id: \.name) { ingredient in
                                                                HStack(alignment: .top) {
                                                                    VStack(alignment: .leading, spacing: 4) {
                                                                        Text(ingredient.name).font(.headline)
                                                                        Text("\(Int(Double(ingredient.calories) * multiplier)) Cal — \(ingredient.amount)").font(.caption).foregroundColor(.gray)
                                                                    }
                                                                    Spacer()
                                                                }
                                                                Divider()
                                                            }
                                                        }
                                                    }.padding(.horizontal, 20)
                                                }

                        if !recipe.directions.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                HStack {
                                    Text("Directions").font(.title2).bold()
                                    Spacer()
                                    Button(action: {
                                        generateAI()
                                    }) {
                                        HStack {
                                            Image(systemName: "sparkles")
                                            Text(isGeneratingRecipe ? "Chef is thinking..." : "Cook with AI")
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(isGeneratingRecipe ? Color.gray : Color.themeOrange)
                                        .clipShape(Capsule())
                                    }
                                    .disabled(isGeneratingRecipe)
                                }
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

            VStack {
                HStack {
                    Button(action: { dismiss() }) { Image(systemName: "chevron.left").font(.title3.bold()).foregroundColor(.primary).frame(width: 40, height: 40).background(.ultraThinMaterial).clipShape(Circle()) }
                    Spacer(); Text("Recipe Info").font(.headline).foregroundColor(.white).shadow(radius: 2); Spacer()
                    HStack(spacing: 12) {

                        ShareLink(
                            item: "Check out this recipe on FoodTracker: \(recipe.title)! It has \(recipe.caloriesPerServing) kcal per serving and takes \(recipe.time).\n\nGet the FoodTracker app: https://apps.apple.com/app/foodtracker",
                            subject: Text(recipe.title)
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title3)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }

                        Button(action: {
                            HapticManager.shared.impact(style: .medium)

                            withAnimation(.spring()) {
                                recipe.isFavorite.toggle()
                            }

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
        .overlay(
            VStack {
                if showAddedToast {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Added to Grocery List!")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.15), radius: 10, y: 5)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 100)
                }
                Spacer()
            }
        )
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showMealSheet) {
            ChooseMealSheet(recipe: recipe, calories: dynamicCalories, p: Double(dynamicProtein), f: Double(dynamicFat), c: Double(dynamicCarbs))
                .presentationDetents([.fraction(0.4)]).presentationCornerRadius(32).presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showAIFlow) {
            if let ai = generatedRecipe {
                NavigationStack {
                    PrepChecklistView(recipe: ai, isFlowPresented: $showAIFlow)
                }
            }
        }
    }
}

struct FilteredRecipesListView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let recipes: [PremiumRecipe]
    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 0) {

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

                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .background(Color.themeBg)
            .zIndex(1)

            ScrollView(showsIndicators: false) {
                if recipes.isEmpty {

                    EmptyStateView(
                        imageName: "magnifyingglass",
                        title: String(localized: "No Recipes Found"),
                        description: String(localized: "Try adjusting your filters to see more results.")
                    )
                    .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(recipes) { recipe in
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                path.append(FoodsRoute.premiumRecipeDetail(recipe))
                            }) {

                                PremiumRecipeCard(recipe: recipe)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 120)
                }
            }
        }
        .background(Color.themeBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

struct ChooseMealSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Environment(DIContainer.self) private var di   // for repo access
    @Query private var summaries: [DailySummary]
    let recipe: PremiumRecipe; let calories: Int; let p: Double; let f: Double; let c: Double
    @State private var selectedMeal = "Dinner"; let meals = ["Breakfast", "Lunch", "Dinner", "Snack"]

    init(recipe: PremiumRecipe, calories: Int, p: Double, f: Double, c: Double) {
        self.recipe = recipe
        self.calories = calories
        self.p = p
        self.f = f
        self.c = c
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = #Predicate<DailySummary> { $0.date >= today && $0.date < tomorrow }
        self._summaries = Query(filter: predicate)
    }
    var body: some View {
        VStack(spacing: 24) {
            Text("Choose a meal").font(.title2.bold()).padding(.top, 24)
            Picker("Meal", selection: $selectedMeal) { ForEach(meals, id: \.self) { meal in Text(meal).tag(meal) } }.pickerStyle(.wheel).frame(height: 120)
            Button(action: {
                HapticManager.shared.impact(style: .heavy)
                Task {
                    await saveToDiary()
                    await MainActor.run { dismiss() }
                }
            }) {
                Text("Select").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 18).background(Color.themePink).cornerRadius(24).shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4)
            }
            .buttonStyle(BounceButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(Color.themeBg.ignoresSafeArea())
    }

    private func saveToDiary() async {
        // Route summary creation/ensure through the @ModelActor-powered repository
        _ = try? await di.summaryRepository.ensureSummary(for: Date.now)

        // Prefer the one from the local @Query (live from main context)
        guard let summary = summaries.first else { return }

        let newFood = FoodItem(name: recipe.title, weight: 100, calories: calories, protein: p, fats: f, carbs: c)
        // Attach via relationship; explicit insert for the item/meal is kept for safety with current cascades
        if let meal = (summary.meals ?? []).first(where: { $0.title == selectedMeal }) {
            meal.foodItems = (meal.foodItems ?? []) + [newFood]
        } else {
            let newMeal = Meal(title: selectedMeal, date: .now, foodItems: [newFood])
            context.insert(newMeal)
            summary.meals = (summary.meals ?? []) + [newMeal]
        }
        try? context.save()
        
        if let user = try? context.fetch(FetchDescriptor<User>()).first, user.isHealthKitEnabled {
            await HealthKitManager.shared.saveDietaryEnergy(calories: calories, date: .now)
        }
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
