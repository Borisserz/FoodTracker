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

extension PremiumRecipe {
    func toAIChefRecipe() -> AIChefRecipe {
        let parsedCookTime = Int(time.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 20
        let cookTime = parsedCookTime > 0 ? parsedCookTime : 20
        let stepIcons = ["flame.fill", "scalemass.fill", "clock.fill", "fork.knife", "sparkles"]
        let mappedSteps: [RecipeStep] = directions.enumerated().map { idx, stepText in
            RecipeStep(
                instruction: stepText,
                imageName: stepIcons[idx % stepIcons.count],
                aiTip: nil
            )
        }
        let fallbackSteps = mappedSteps.isEmpty
            ? [RecipeStep(instruction: description, imageName: "fork.knife", aiTip: nil)]
            : mappedSteps

        let difficultyScore: Int
        if tags.contains(where: { $0.localizedCaseInsensitiveContains("Easy") }) {
            difficultyScore = 1
        } else if tags.contains(where: { $0.localizedCaseInsensitiveContains("Hard") }) {
            difficultyScore = 4
        } else {
            difficultyScore = min(max(fallbackSteps.count / 2 + 1, 1), 5)
        }

        let formattedIngredients = ingredients.map { "\($0.name) (\($0.amount))" }

        return AIChefRecipe(
            id: id ?? title,
            title: title,
            calories: caloriesPerServing,
            protein: Int(protein.rounded()),
            fat: Int(fat.rounded()),
            carbs: Int(carbs.rounded()),
            heroImage: imageUrl,
            cookTime: cookTime,
            difficulty: difficultyScore,
            history: description,
            ingredients: formattedIngredients,
            steps: fallbackSteps,
            platingTip: String(localized: "Serve warm and garnish cleanly for best presentation."),
            tags: tags
        )
    }
}
struct ChefCalorieRange {
    let title: String
    let minCalories: Int
    let maxCalories: Int

    @MainActor
    var color: Color {
        switch minCalories {
        case ..<300: return .green
        case 300..<450: return .themeYellow
        case 450..<600: return .themeOrange
        default: return .themePink
        }
    }
}

enum ChefCalorieRangeCatalog {
    static let ranges: [ChefCalorieRange] = [
        ChefCalorieRange(title: "Under 300", minCalories: 0, maxCalories: 299),
        ChefCalorieRange(title: "300 - 450", minCalories: 300, maxCalories: 449),
        ChefCalorieRange(title: "450 - 600", minCalories: 450, maxCalories: 599),
        ChefCalorieRange(title: "600+ kcal", minCalories: 600, maxCalories: 5000)
    ]
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
                TabButton(title: "Discover", tabIndex: 0, selectedTab: $selectedTab, animation: animation)
                TabButton(title: "My Recipes", tabIndex: 1, selectedTab: $selectedTab, animation: animation)
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

                 DiscoverTabView(path: $path, allRecipes: dataLoader.recipes, searchText: searchText)
                     .tag(0)

                 MyRecipesTabView(path: $path, customRecipes: customRecipes, allRecipes: dataLoader.recipes, searchText: searchText)
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
                Text(LocalizedStringKey(title))
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
    let searchText: String

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchedRecipes: [PremiumRecipe] {
        guard !trimmedQuery.isEmpty else { return allRecipes }
        return allRecipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(trimmedQuery) ||
            recipe.description.localizedCaseInsensitiveContains(trimmedQuery) ||
            recipe.tags.contains(where: { $0.localizedCaseInsensitiveContains(trimmedQuery) }) ||
            recipe.ingredients.contains(where: { $0.name.localizedCaseInsensitiveContains(trimmedQuery) })
        }
    }

    let calorieRanges = ChefCalorieRangeCatalog.ranges

    var body: some View {

        return ScrollView(showsIndicators: false) {
            if !trimmedQuery.isEmpty {
                if searchedRecipes.isEmpty {
                    EmptyStateView(
                        imageName: "magnifyingglass",
                        title: "No Recipes Found",
                        description: "Try a different ingredient or recipe keyword."
                    )
                    .padding(.top, 60)
                    .padding(.bottom, 120)
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(searchedRecipes) { recipe in
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                path.append(FoodsRoute.premiumRecipeDetail(recipe))
                            }) {
                                PremiumRecipeCard(recipe: recipe)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 120)
                }
            } else {
            let sections = ChefDiscoverSections.partition(allRecipes)
            VStack(spacing: 32) {

                VStack(alignment: .leading, spacing: 16) {
                    Text("Pick Your Meal")
                        .font(.title2).bold()
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            MealTypeCard(title: "Breakfast", subtitle: "Start your day right", imageUrl: "https://images.unsplash.com/photo-1525351484163-7529414344d8?q=80&w=400", color: .themeYellow) {
                                openFiltered(title: "Breakfast", tags: ["Breakfast"])
                            }
                            MealTypeCard(title: "Lunch", subtitle: "Healthy & filling", imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=400", color: .green) {
                                openFiltered(title: "Lunch", tags: ["Lunch"])
                            }
                            MealTypeCard(title: "Dinner", subtitle: "Cozy evenings", imageUrl: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?q=80&w=400", color: .themePink) {
                                openFiltered(title: "Dinner", tags: ["Dinner"])
                            }
                            MealTypeCard(title: "Snack", subtitle: "Quick bites", imageUrl: "https://images.unsplash.com/photo-1505253716362-afaea1d3d1af?q=80&w=400", color: .themeOrange) {
                                openFiltered(title: "Snack", tags: ["Snack"])
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
                            ForEach(calorieRanges, id: \.title) { range in
                                Button(action: {
                                    HapticManager.shared.impact(style: .light)
                                    let filtered = allRecipes.filter { $0.caloriesPerServing >= range.minCalories && $0.caloriesPerServing <= range.maxCalories }
                                    path.append(FoodsRoute.filteredList(range.title, filtered))
                                }) {
                                    CalorieRangeCard(title: range.title, color: range.color)
                                }
                                .buttonStyle(BounceButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                }

                if !sections.highProtein.isEmpty {
                    RecipeHorizontalSection(title: "High Protein Power", recipes: sections.highProtein, path: $path)
                }
                if !sections.ketoLowCarb.isEmpty {
                    RecipeHorizontalSection(title: "Low Carb & Keto", recipes: sections.ketoLowCarb, path: $path)
                }
                if !sections.quickEasy.isEmpty {
                    RecipeHorizontalSection(title: "Quick & Easy", recipes: sections.quickEasy, path: $path)
                }
                if !sections.plantBased.isEmpty {
                    RecipeHorizontalSection(title: "Plant-Based", recipes: sections.plantBased, path: $path)
                }
                if !sections.chefsSpecials.isEmpty {
                    RecipeHorizontalSection(title: "Chef's Specials", recipes: sections.chefsSpecials, path: $path)
                }

            }
            .padding(.bottom, 120)
            }
        }
    }

    private func openFiltered(title: String, tags: [String]) {
        HapticManager.shared.impact(style: .medium)
        let filtered = ChefDiscoverSections.filter(allRecipes, matchingAnyCanonicalTags: tags)
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
                        Text(LocalizedStringKey(title))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(LocalizedStringKey(subtitle))
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

            Text(LocalizedStringKey(title))
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
    let searchText: String
    @Environment(\.modelContext) private var context

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredCustomRecipes: [CustomRecipe] {
        guard !trimmedQuery.isEmpty else { return customRecipes }
        return customRecipes.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.info.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var favoriteRecipes: [PremiumRecipe] {
        let favs = allRecipes.filter { $0.isFavorite }
        guard !trimmedQuery.isEmpty else { return favs }
        return favs.filter {
            $0.title.localizedCaseInsensitiveContains(trimmedQuery) ||
            $0.description.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

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

                    if filteredCustomRecipes.isEmpty {
                        EmptyStateView(
                            imageName: "frying.pan",
                            title: "No custom recipes yet",
                            description: "Your culinary masterpieces will appear here."
                        )
                        .frame(height: 150)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredCustomRecipes) { recipe in
                                CustomRecipePremiumCard(
                                    recipe: recipe,
                                    onSelect: {
                                        HapticManager.shared.impact(style: .light)
                                        path.append(FoodsRoute.recipeDetail(recipe))
                                    },
                                    onDelete: {
                                        deleteCustomRecipe(recipe)
                                    }
                                )
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
    var onSelect: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {

        let macros = recipe.toFoodItem()

        VStack(spacing: 0) {

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(recipe.info.uppercased())
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.themePink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.themePink.opacity(0.15))
                            .clipShape(Capsule())

                        if let onDelete {
                            Button(role: .destructive, action: onDelete) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete Recipe")
                        }
                    }

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
                        .trim(from: 0, to: min(Double(macros.calories) / 2000.0, 1.0))
                        .stroke(Color.themePink, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(macros.calories)")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                        Text("kcal / serv")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                .frame(width: 60, height: 60)
            }
            .padding(20)

            Divider().padding(.horizontal, 20)

            HStack(spacing: 20) {
                MacroPill(title: "Carbs", value: macros.carbs, color: .drinkWater)
                MacroPill(title: "Fat", value: macros.fats, color: .themeYellow)
                MacroPill(title: "Protein", value: macros.protein, color: .themePeach)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color.gray.opacity(0.03))
        }
        .background(Color.white)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .onTapGesture {
            onSelect?()
        }
        .contextMenu {
            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Recipe", systemImage: "trash")
                }
            }
        }
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
            Text(LocalizedStringKey(title))
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

    static let dietFilterOptions: [(String, String, Color)] = [
        ("Vegetarian", "leaf.fill", Color.green),
        ("Vegan", "leaf.arrow.circlepath", Color.mint),
        ("Low Carb", "fish.fill", Color.orange),
        ("High Protein", "dumbbell.fill", Color.blue),
        ("Ketogenic", "flame.fill", Color.red)
    ]

    let meals = [("Breakfast", "cup.and.saucer.fill"), ("Lunch", "takeoutbag.and.cup.and.straw.fill"), ("Dinner", "fork.knife"), ("Snack", "apple.logo"), ("Smoothie", "drop.fill")]
    let prep = [("Quickly Prepared", "timer"), ("On the Go", "figure.walk"), ("Few Ingredients", "cart.fill"), ("Baking", "oven.fill"), ("Easy", "hand.thumbsup.fill")]
    var diets: [(String, String, Color)] { Self.dietFilterOptions }

    var filteredRecipes: [PremiumRecipe] {
          if selectedTags.isEmpty { return allRecipes }
          return allRecipes.filter { recipe in
              selectedTags.isSubset(of: RecipeTagCatalog.canonicalTags(for: recipe.tags))
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
                        FilterIconSection(title: "Meals", items: meals, selection: $selectedTags)
                        FilterIconSection(title: "Preparation Method", items: prep, selection: $selectedTags)
                        FilterColoredSection(title: "Diets", items: diets, selection: $selectedTags)
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
            Text(LocalizedStringKey(title)).font(.headline).foregroundColor(.primary)

            RecipeTagLayout(spacing: 12) {
                ForEach(items, id: \.0) { item in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        if selection.contains(item.0) { selection.remove(item.0) } else { selection.insert(item.0) }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: item.1)
                                .font(.system(size: 14))
                            Text(LocalizedStringKey(item.0))
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
            Text(LocalizedStringKey(title)).font(.headline).foregroundColor(.primary)

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
                            Text(LocalizedStringKey(item.0))
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
                    Text(LocalizedStringKey(title))
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
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: recipe.imageUrl)) { phase in
                    if let image = phase.image { image.resizable().aspectRatio(contentMode: .fill) } else { Rectangle().fill(Color.gray.opacity(0.2)).overlay(ProgressView()) }
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

struct PremiumRecipeDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @State var recipe: PremiumRecipe
    @State private var servings: Int
    @State private var showMealSheet = false
    @State private var showAICooking = false
    @Environment(RecipeDataLoader.self) private var dataLoader
    init(recipe: PremiumRecipe) { self._recipe = State(initialValue: recipe); self._servings = State(initialValue: 1) }

    private var multiplier: Double { Double(servings) / Double(max(recipe.baseServings, 1)) }
    private var dynamicCalories: Int { recipe.caloriesPerServing * servings }
    private var dynamicProtein: Int { Int((recipe.protein * Double(servings)).rounded()) }
    private var dynamicFat: Int { Int((recipe.fat * Double(servings)).rounded()) }
    private var dynamicCarbs: Int { Int((recipe.carbs * Double(servings)).rounded()) }
    private var dynamicWeightGrams: Double {
        let totalBatchGrams = recipe.ingredients.reduce(0.0) { $0 + Double($1.weightGrams) }
        if totalBatchGrams > 0 {
            return max(50.0, (totalBatchGrams * multiplier).rounded())
        }
        return Double(servings) * 250.0
    }

    private var shareRecipeText: String {
        let ingredientsList = recipe.ingredients.map { "• \($0.name) (\($0.amount))" }.joined(separator: "\n")
        return "\(recipe.title)\n\(dynamicCalories) Cal • P \(dynamicProtein)g / F \(dynamicFat)g / C \(dynamicCarbs)g\n\n\(recipe.description)\n\n\(ingredientsList)"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    ZStack(alignment: .bottomLeading) {

                        AsyncImage(url: URL(string: recipe.imageUrl)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
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
                                Label("\(recipe.caloriesPerServing) Cal / serving", systemImage: "flame")
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
                                        Text("\(servings) / \(max(recipe.baseServings, 1))").font(.subheadline.bold()).foregroundColor(.gray)
                                        Spacer()
                                        Text("Servings").font(.caption).foregroundColor(.secondary)
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

                                                                ShoppingItem.insertDeduplicated(
                                                                    items: recipe.ingredients.map { (name: $0.name, amount: $0.amount) },
                                                                    recipeTitle: recipe.title,
                                                                    in: context
                                                                )
                                                                try? context.save()
                                                                WidgetReloader.reloadAll()

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

                                                        if recipe.baseServings > 1 && servings != recipe.baseServings {
                                                            Text("Calories shown per \(servings) serving(s); ingredient amounts reflect full \(recipe.baseServings)-serving batch.")
                                                                .font(.caption)
                                                                .foregroundColor(.secondary)
                                                        }

                                                        VStack(spacing: 16) {
                                                            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ingredient in
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
                                        HapticManager.shared.impact(style: .medium)
                                        showAICooking = true
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "sparkles")
                                            Text("Cook with AI")
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .clipShape(Capsule())
                                        .shadow(color: Color.themePink.opacity(0.3), radius: 5, y: 2)
                                    }
                                    .buttonStyle(BounceButtonStyle())
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
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .frame(width: 70, alignment: .leading)
                    Spacer()
                    Text("Recipe Info")
                        .font(.headline)
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                    Spacer()
                    HStack(spacing: 12) {

                        ShareLink(item: shareRecipeText) {
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
                }.padding(.horizontal, 20).padding(.top, 10)
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
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showMealSheet) {
            ChooseMealSheet(
                recipe: recipe,
                calories: dynamicCalories,
                p: Double(dynamicProtein),
                f: Double(dynamicFat),
                c: Double(dynamicCarbs),
                weightGrams: dynamicWeightGrams
            )
                .presentationDetents([.fraction(0.5), .large]).presentationCornerRadius(32).presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showAICooking) {
            NavigationStack {
                AgentCookingView(recipe: recipe.toAIChefRecipe(), isFlowPresented: $showAICooking)
            }
        }
    }
}

struct FilteredRecipesListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(RecipeDataLoader.self) private var dataLoader

    let title: String
    let recipes: [PremiumRecipe]
    @Binding var path: NavigationPath

    private var liveRecipes: [PremiumRecipe] {
        let latestByKey = Dictionary(
            uniqueKeysWithValues: dataLoader.recipes.map { ($0.id ?? $0.title, $0) }
        )
        return recipes.map { latestByKey[$0.id ?? $0.title] ?? $0 }
    }

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

                Text(LocalizedStringKey(title))
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
                if liveRecipes.isEmpty {

                    EmptyStateView(
                        imageName: "magnifyingglass",
                        title: "No Recipes Found",
                        description: "Try adjusting your filters to see more results."
                    )
                    .padding(.top, 80)
                } else {
                    LazyVStack(spacing: 20) {
                        ForEach(liveRecipes) { recipe in
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
    @Query private var users: [User]
    let recipe: PremiumRecipe; let calories: Int; let p: Double; let f: Double; let c: Double; let weightGrams: Double
    @State private var selectedMeal = "Dinner"; let meals = ["Breakfast", "Lunch", "Dinner", "Snack"]

    init(recipe: PremiumRecipe, calories: Int, p: Double, f: Double, c: Double, weightGrams: Double = 250.0) {
        self.recipe = recipe
        self.calories = calories
        self.p = p
        self.f = f
        self.c = c
        self.weightGrams = weightGrams
    }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Text("Choose a meal").font(.title2.bold()).padding(.top, 24)
                Picker("Meal", selection: $selectedMeal) { ForEach(meals, id: \.self) { meal in Text(LocalizedStringKey(meal)).tag(meal) } }.pickerStyle(.wheel).frame(height: 120)
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
        }
        .background(Color.themeBg.ignoresSafeArea())
    }

    private func saveToDiary() async {
        let startOfDay = Calendar.current.startOfDay(for: Date.now)
        let summary = DailySummary.fetchOrCreate(for: startOfDay, in: context)

        let resolvedWeight = max(50.0, weightGrams)
        let micros = MicronutrientEstimator.estimate(
            id: recipe.id ?? "",
            name: recipe.title,
            calories: calories,
            protein: p,
            fat: f,
            carbs: c,
            weight: resolvedWeight
        )
        let newFood = FoodItem(
            name: recipe.title,
            weight: resolvedWeight,
            calories: calories,
            protein: p,
            fats: f,
            carbs: c,
            omega3: micros.omega3,
            calcium: micros.calcium,
            potassium: micros.potassium,
            magnesium: micros.magnesium,
            iron: micros.iron,
            vitaminC: micros.vitaminC,
            vitaminD: micros.vitaminD
        )
        context.insert(newFood)
        let canonicalSlot = DailySummary.canonicalMealSlot(selectedMeal)
        if let meal = (summary.meals ?? []).first(where: { DailySummary.canonicalMealSlot($0.title) == canonicalSlot }) {
            meal.addFoodItem(newFood)
            meal.date = .now
        } else {
            let newMeal = Meal(title: canonicalSlot, date: .now, foodItems: [newFood])
            context.insert(newMeal)
            summary.addMeal(newMeal)
        }
        try? context.save()
        WidgetReloader.reloadAll()
        AppReviewManager.shared.userDidLogMeal()
        if users.first?.isHealthKitEnabled == true && calories > 0 {
            if let uuid = await HealthKitManager.shared.saveDietaryEnergy(calories: calories, date: .now) {
                newFood.healthKitSampleID = uuid.uuidString
                try? context.save()
            }
        }
    }
}

extension View { func recipeCustomCornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View { clipShape(RecipeRoundedCorner(radius: radius, corners: corners)) } }
struct RecipeRoundedCorner: Shape { var radius: CGFloat = .infinity; var corners: UIRectCorner = .allCorners; func path(in rect: CGRect) -> Path { let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius)); return Path(path.cgPath) } }
struct RecipeTagLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { let rows = computeRows(proposal: proposal, subviews: subviews); let height = rows.reduce(0) { $0 + $1.maxHeight } + CGFloat(max(0, rows.count - 1)) * spacing; return CGSize(width: proposal.width ?? 0, height: height) }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) { let rows = computeRows(proposal: proposal, subviews: subviews); var y = bounds.minY; for row in rows { var x = bounds.minX; for element in row.elements { let size = element.view.sizeThatFits(.unspecified); element.view.place(at: CGPoint(x: x, y: y), proposal: .unspecified); x += size.width + spacing }; y += row.maxHeight + spacing } }
    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] { var rows: [Row] = []; var currentRow = Row(); var currentX: CGFloat = 0; let maxWidth = proposal.width ?? 320; for subview in subviews { let size = subview.sizeThatFits(.unspecified); if currentX + size.width > maxWidth && !currentRow.elements.isEmpty { rows.append(currentRow); currentRow = Row(); currentX = 0 }; currentRow.elements.append(Element(view: subview, size: size)); currentRow.maxHeight = max(currentRow.maxHeight, size.height); currentX += size.width + spacing }; if !currentRow.elements.isEmpty { rows.append(currentRow) }; return rows }
    private struct Row { var elements: [Element] = []; var maxHeight: CGFloat = 0 }
    private struct Element { let view: LayoutSubview; let size: CGSize }
}
