import SwiftUI
import SwiftData

enum FoodsRoute: Hashable {
    case recipes
    case diets
    case learn
    case createRecipe
    case recipeDetail(CustomRecipe)
    case premiumRecipeDetail(PremiumRecipe)
    case articleDetail(Article)
    case filteredList(String, [PremiumRecipe])
    case mealDetail(title: String, date: Date)
    case shoppingList
    case fasting
    case fastingDetail(FastingPlan)
}

struct FoodsDashboardView: View {
    @Environment(\.modelContext) private var context
    @State private var path = NavigationPath()
    @Environment(RecipeDataLoader.self) private var dataLoader
    @Query(sort: \Meal.date, order: .reverse) private var meals: [Meal]

    @State private var selectedFilter: String = "All"
    let filterOptions = ["All", "Breakfast", "Lunch", "Snack", "Dinner"]

    var filteredMeals: [Meal] {
        if selectedFilter == "All" {
            return meals
        } else {
            return meals.filter { $0.title == selectedFilter }
        }
    }

    var body: some View {
            NavigationStack(path: $path) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {

                        if FastingManager.shared.isFasting {
                            ActiveFastingCard()
                                .padding(.horizontal)
                                .padding(.top, 10)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                    VStack(spacing: 16) {
                        RecipesHeroCard {
                            path.append(FoodsRoute.recipes)
                        }

                        HStack(spacing: 16) {
                            DietGridCard {
                                path.append(FoodsRoute.diets)
                            }
                            
                            AcademyGridCard {
                                path.append(FoodsRoute.learn)
                            }
                        }

                        FastingWideCard {
                            path.append(FoodsRoute.fasting)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Meals Logged")
                            .font(.title2).bold()
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(filterOptions, id: \.self) { option in
                                    Button(action: {
                                        withAnimation(.spring()) { selectedFilter = option }
                                    }) {
                                        Text(option)
                                            .font(.subheadline).bold()
                                            .padding(.horizontal, 16).padding(.vertical, 8)
                                            .background(selectedFilter == option ? Color.themePink : Color.white)
                                            .foregroundColor(selectedFilter == option ? .white : .primary)
                                            .cornerRadius(20)
                                            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                        }

                        if filteredMeals.isEmpty {
                            let message = selectedFilter == "All" ? "Your logged meals will appear here." : "No meals logged for \(selectedFilter)."
                            EmptyStateView(imageName: "fork.knife", title: String(localized: "No History"), description: message)
                                .frame(height: 200).premiumCardStyle()
                                .padding(.horizontal)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredMeals) { meal in
                                    FrequentMealRow(
                                        timeTag: meal.title,
                                        title: meal.date.formatted(date: .abbreviated, time: .shortened),
                                        ingredients: meal.foodItems.map { $0.name }.joined(separator: ", "),
                                        calories: "\(meal.totalCalories)",
                                        color: colorForMeal(meal.title),
                                        onDelete: { deleteMeal(meal) }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        HapticManager.shared.impact(style: .light)
                                        path.append(FoodsRoute.mealDetail(title: meal.title, date: meal.date))
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 120)
            }
            .background(Color.themeBg.ignoresSafeArea())
            .navigationTitle("Explore")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        path.append(FoodsRoute.shoppingList)
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color.themePink.opacity(0.1))
                                .frame(width: 36, height: 36)
                            Image(systemName: "cart.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.themePink)
                        }
                    }
                }
            }
            .navigationDestination(for: FoodsRoute.self) { route in
                switch route {
                case .recipes: RecipesContainerView(path: $path)
                case .diets: DietsListView()
                case .learn: LearnDashboardView(path: $path)
                case .createRecipe: CreateRecipeView(path: $path)
                case .recipeDetail(let recipe): RecipeDetailView(recipe: recipe, path: $path)
                case .premiumRecipeDetail(let recipe): PremiumRecipeDetailView(recipe: recipe)
                case .filteredList(let title, let recipes): FilteredRecipesListView(title: title, recipes: recipes, path: $path)
                case .articleDetail(let article): ArticleDetailView(article: article)
                case .mealDetail(let title, let date): MealDetailView(title: title, date: date)
                case .shoppingList: ShoppingListView()
                case .fasting: FastingDashboardView()
                case .fastingDetail(let plan): PremiumFastingDetailView(plan: plan)
                }
            }
        }
    }

    private func deleteMeal(_ meal: Meal) {
        withAnimation {
            context.delete(meal)
            try? context.save()
        }
    }

    private func colorForMeal(_ title: String) -> Color {
        switch title {
        case "Breakfast": return .themeYellow
        case "Lunch": return .themePeach
        case "Snack": return .themeOrange
        case "Dinner": return .themePink
        default: return .gray
        }
    }
}

struct RecipesHeroCard: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                // Background image with fallback
                AsyncImage(url: URL(string: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=800")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    LinearGradient(
                        colors: [.themePink.opacity(0.85), .themeOrange.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .frame(height: 190)
                .clipped()
                
                // Dark overlay gradient for readable texts
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5), .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("Recipes".uppercased())
                                .font(.system(.caption2, design: .rounded, weight: .black))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.themePink)
                                .clipShape(Capsule())
                            
                            Text("600+ DISHES")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.themeYellow)
                        }
                        
                        Text("Explore Healthy Cooking")
                            .font(.system(.title3, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                        
                        Text("Custom meals, step-by-step videos, and chef creations.")
                            .font(.system(.caption, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    // Floating interactive chevron button
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(16)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.1), radius: 12, y: 6)
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Recipes: Explore Healthy Cooking. 600+ dishes, custom meals, and step-by-step videos.")
        .accessibilityAddTraits(.isButton)
    }
}

struct DietGridCard: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Top Visual Gradient & Icon
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Color.green.opacity(0.85), Color.teal],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.2))
                        .offset(x: 45, y: 15)
                        .accessibilityHidden(true)
                    
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                }
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .clipped()
                
                // Bottom content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Diet Plans")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("Keto, Vegan & More")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
            }
            .frame(height: 115)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Diet Plans: Keto, Vegan & More.")
        .accessibilityAddTraits(.isButton)
    }
}

struct AcademyGridCard: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Top Visual Gradient & Icon
                ZStack(alignment: .topLeading) {
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.2))
                        .offset(x: 45, y: 15)
                        .accessibilityHidden(true)
                    
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.2))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                }
                .frame(height: 60)
                .frame(maxWidth: .infinity)
                .clipped()
                
                // Bottom content
                VStack(alignment: .leading, spacing: 4) {
                    Text("Academy")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("Nutrition Guides")
                        .font(.system(.caption2, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
            }
            .frame(height: 115)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Academy: Nutrition Guides.")
        .accessibilityAddTraits(.isButton)
    }
}

struct FastingWideCard: View {
    let action: () -> Void
    var manager = FastingManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Left Icon Accent with subtle animation/rotation or glow
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: manager.isFasting ? [manager.currentPhase.color.opacity(0.2), manager.currentPhase.color.opacity(0.4)] : [Color.themeOrange.opacity(0.15), Color.themeOrange.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    
                    Image(systemName: manager.isFasting ? manager.currentPhase.icon : "timer")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(manager.isFasting ? manager.currentPhase.color : Color.themeOrange)
                }
                .padding(.leading, 12)
                
                // Content Texts
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Fasting")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        if manager.isFasting {
                            Text("ACTIVE")
                                .font(.system(.caption2, design: .rounded, weight: .black))
                                .foregroundStyle(manager.currentPhase.color)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(manager.currentPhase.color.opacity(0.15))
                                .clipShape(Capsule())
                        } else {
                            Text("16:8, OMAD")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundStyle(Color.themeOrange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.themeOrange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    
                    if manager.isFasting {
                        Text("Current: \(manager.planName) • \(manager.elapsedTimeString) elapsed")
                            .font(.system(.subheadline, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Track fasting windows, monitor streaks & ketosis.")
                            .font(.system(.subheadline, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Right Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 12)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 14)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: manager.isFasting ? manager.currentPhase.color.opacity(0.1) : Color.black.opacity(0.05), radius: 12, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(manager.isFasting ? manager.currentPhase.color.opacity(0.2) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(BounceButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(manager.isFasting ? "Fasting tracker active, current fast: \(manager.planName), time elapsed: \(manager.elapsedTimeString)" : "Fasting Tracker: track fasting windows, monitor streaks and ketosis.")
        .accessibilityAddTraits(.isButton)
    }
}

struct FrequentMealRow: View {
    let timeTag: String; let title: String; let ingredients: String; let calories: String; let color: Color
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(timeTag)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(color)
                    .cornerRadius(6)

                Text(title)
                    .font(.headline)

                Text(ingredients)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.8))
                        .font(.caption)
                        .padding(4)
                }

                Text("\(calories) kcal")
                    .font(.headline)
                    .foregroundColor(.themePink)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray.opacity(0.3))
        }
        .premiumCardStyle()
    }
}

struct LearnDashboardView: View {
    @Binding var path: NavigationPath
    @Environment(AcademyDataLoader.self) private var dataLoader

    private var totalArticles: Int {
        dataLoader.categories.reduce(0) { $0 + $1.totalCount }
    }
    
    private var completedArticles: Int {
        dataLoader.categories.reduce(0) { $0 + $1.completedCount }
    }
    
    private var progressFraction: Double {
        let total = totalArticles
        return total > 0 ? Double(completedArticles) / Double(total) : 0.0
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {

                VStack(alignment: .leading, spacing: 8) {
                    Text("Master Your Nutrition")
                        .font(.title2.bold())
                        .foregroundColor(.primary)

                    Text("Build healthy habits, understand your body, and achieve your goals with our science-backed guides.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 8)

                if !dataLoader.categories.isEmpty {
                    // Learning Progress Header Card
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("YOUR PROGRESS")
                                .font(.system(.caption2, design: .rounded, weight: .black))
                                .foregroundColor(.themePink)
                                .tracking(1)
                            
                            Text("Academy Master")
                                .font(.system(.title3, design: .rounded, weight: .heavy))
                                .foregroundColor(.primary)
                            
                            Text("\(completedArticles) of \(totalArticles) topics finished")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Progress Circle
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.1), lineWidth: 6)
                            
                            Circle()
                                .trim(from: 0, to: progressFraction)
                                .stroke(
                                    LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom),
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .shadow(color: Color.themePink.opacity(0.3), radius: 5, y: 3)
                            
                            Text("\(Int(progressFraction * 100))%")
                                .font(.system(.caption2, design: .rounded, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        .frame(width: 68, height: 68)
                    }
                    .padding(20)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
                    .padding(.horizontal)
                }

                if dataLoader.categories.isEmpty {
                    ProgressView("Loading academy...")
                        .padding(.top, 50)
                } else {

                    ForEach(dataLoader.categories) { category in
                        LearnCategorySection(category: category, path: $path)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.themeBg.ignoresSafeArea())
        .navigationTitle("Academy")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct LearnCategorySection: View {
    let category: ArticleCategory
    @Binding var path: NavigationPath

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            VStack(alignment: .leading, spacing: 8) {
                Text(category.title)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.primary)

                HStack(spacing: 12) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.2))
                            Capsule()
                                .fill(Color.themePink)
                                .frame(width: geo.size.width * CGFloat(category.completedCount) / CGFloat(max(category.totalCount, 1)))
                        }
                    }
                    .frame(width: 80, height: 6)

                    Text("\(category.completedCount) of \(category.totalCount) completed")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(category.articles) { article in
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            path.append(FoodsRoute.articleDetail(article))
                        }) {
                            ArticleCardView(article: article)
                        }
                        .buttonStyle(BounceButtonStyle())
                        .containerRelativeFrame(.horizontal, count: 2, span: 1, spacing: 16)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal)
                .padding(.bottom, 15)
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
}

struct ArticleCardView: View {
    let article: Article

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [article.color1.opacity(0.85), article.color2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: article.iconName)
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.22))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 8, y: 12)
                    .accessibilityHidden(true)

                HStack(spacing: 4) {
                    Image(systemName: "clock.fill").font(.system(size: 9))
                    Text("\(article.readTime) MIN").font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(.ultraThinMaterial).environment(\.colorScheme, .dark)
                .clipShape(Capsule()).padding(12)
            }
            .frame(height: 115).clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(article.subtitle)
                    .font(.system(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading).frame(height: 95)
            .background(.regularMaterial)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
    }
}

struct ArticleDetailView: View {
    let article: Article
    @Environment(\.dismiss) var dismiss

    @Environment(AcademyDataLoader.self) private var dataLoader

    private var isCompleted: Bool {
        dataLoader.completedArticleIDs.contains(article.id)
    }

    private var markdownText: AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.allowsExtendedAttributes = true
            options.interpretedSyntax = .full
            return try AttributedString(markdown: article.content, options: options)
        } catch {
            return AttributedString(article.content)
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.themeBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    GeometryReader { geo in
                        let minY = geo.frame(in: .global).minY
                        let isScrollingDown = minY > 0

                        ZStack(alignment: .bottomLeading) {
                            LinearGradient(
                                colors: [article.color1, article.color2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: isScrollingDown ? 380 + minY : 380)
                            .offset(y: isScrollingDown ? -minY : 0)

                            Image(systemName: article.iconName)
                                .font(.system(size: 150))
                                .foregroundStyle(.white.opacity(0.15))
                                .offset(x: UIScreen.main.bounds.width * 0.4, y: 30)
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock.fill")
                                    Text("\(article.readTime) min read")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                                .clipShape(Capsule())

                                Text(article.title)
                                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .lineSpacing(4)
                                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 60)
                            .offset(y: isScrollingDown ? -minY * 0.5 : 0)
                        }
                    }
                    .frame(height: 380)

                    VStack(alignment: .leading, spacing: 24) {

                        Text(markdownText)
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .lineSpacing(8)
                            .foregroundColor(.primary.opacity(0.9))

                        Divider().padding(.vertical, 16)

                        Button(action: {
                            HapticManager.shared.impact(style: .heavy)

                            if !isCompleted {

                                dataLoader.markAsCompleted(articleID: article.id)
                            }

                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.seal.fill")
                                    .font(.title2)
                                Text(isCompleted ? "Completed" : "Mark as Completed")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)

                            .background(
                                Group {
                                    if isCompleted {
                                        Color.gray
                                    } else {
                                        LinearGradient(colors: [article.color1, article.color2], startPoint: .leading, endPoint: .trailing)
                                    }
                                }
                            )
                            .cornerRadius(20)
                            .shadow(color: isCompleted ? .clear : article.color1.opacity(0.4), radius: 10, y: 5)
                        }
                        .buttonStyle(BounceButtonStyle())

                        Spacer(minLength: 120)
                    }
                    .padding(24)
                    .background(Color.themeBg)
                    .cornerRadius(32, corners: [.topLeft, .topRight])
                    .offset(y: -32)
                    .padding(.bottom, -32)
                }
            }
            .ignoresSafeArea(edges: .top)

            HStack {
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.25))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
        .navigationBarHidden(true)
    }
}
