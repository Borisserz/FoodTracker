import SwiftUI
import SwiftData

// MARK: - РОУТИНГ ДЛЯ НОВОГО ЭКРАНА FOODS
enum FoodsRoute: Hashable {
    case recipes
    case diets
    case learn // НОВЫЙ РОУТ ДЛЯ ОБУЧЕНИЯ
    case createRecipe
    case recipeDetail(CustomRecipe)
    case premiumRecipeDetail(PremiumRecipe)
}

// MARK: - ГЛАВНЫЙ VIEW FOODS (БЫВШИЙ HISTORY)
struct FoodsDashboardView: View {
    @Environment(\.modelContext) private var context
    @State private var path = NavigationPath()
    
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
                    
                    // 1. БЛОК ГЛАВНЫХ КНОПОК НАВИГАЦИИ
                    VStack(spacing: 16) {
                        // Верхний ряд (2 кнопки)
                        HStack(spacing: 16) {
                            FoodsFeatureCard(title: "Recipes", subtitle: "Custom & Chefs", icon: "book.pages.fill", color: .themePink) {
                                path.append(FoodsRoute.recipes)
                            }
                            
                            FoodsFeatureCard(title: "Diet Plans", subtitle: "Keto, Vegan...", icon: "leaf.fill", color: .green) {
                                path.append(FoodsRoute.diets)
                            }
                        }
                        
                        // Нижний ряд (1 широкая кнопка Академии)
                        FoodsFeatureCard(title: "Academy", subtitle: "Tips, Guides & Habits", icon: "graduationcap.fill", color: .blue) {
                            path.append(FoodsRoute.learn)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    
                    
                    // 2. БЛОК ИСТОРИИ ПРИЕМОВ ПИЩИ
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
                            EmptyStateView(imageName: "fork.knife", title: "No History", description: message)
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
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 120) // Отступ под TabBar
            }
            .background(Color.themeBg.ignoresSafeArea())
            .navigationTitle("Explore")
            .navigationDestination(for: FoodsRoute.self) { route in
                            switch route {
                            case .recipes:
                                RecipesContainerView(path: $path)
                            case .diets:
                                DietsListView()
                            case .learn:
                                LearnDashboardView() // ОТКРЫВАЕМ НОВЫЙ ЭКРАН
                            case .createRecipe:
                                CreateRecipeView(path: $path)
                            case .recipeDetail(let recipe):
                                RecipeDetailView(recipe: recipe, path: $path)
                            case .premiumRecipeDetail(let recipe): // <--- ДОБАВИЛИ ЭТО
                                PremiumRecipeDetailView(recipe: recipe) // <--- ДОБАВИЛИ ЭТО
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

// MARK: - ПЛАШКИ НАВИГАЦИИ
struct FoodsFeatureCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        }
        .buttonStyle(BounceButtonStyle())
    }
}

// MARK: - СТРОКА ИСТОРИИ ПРИЕМА ПИЩИ
struct FrequentMealRow: View {
    let timeTag: String; let title: String; let ingredients: String; let calories: String; let color: Color
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(timeTag).font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(.horizontal, 6).padding(.vertical, 4).background(color).cornerRadius(6)
                Text(title).font(.headline)
                Text(ingredients).font(.caption).foregroundColor(.gray).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundColor(.red.opacity(0.8)).font(.caption)
                }
                Text("\(calories) kcal").font(.headline).foregroundColor(.themePink)
            }
        }.premiumCardStyle()
    }
}

// =========================================================================
// MARK: - НОВЫЙ ЭКРАН: АКАДЕМИЯ (LEARN DASHBOARD)
// =========================================================================

struct LearnDashboardView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Вводный текст
                Text("Build healthy habits, understand your body, and achieve your goals with our guides.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Рендерим категории
                ForEach(ArticleCategory.mockData) { category in
                    LearnCategorySection(category: category)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.themeBg.ignoresSafeArea())
        .navigationTitle("Academy")
        .navigationBarTitleDisplayMode(.large)
    }
}


// MARK: - МОДЕЛИ ДАННЫХ ДЛЯ ОБУЧЕНИЯ
struct Article: Identifiable {
    let id = UUID()
    let title: String
    let isLocked: Bool
    let color1: Color
    let color2: Color
    let iconName: String // Для имитации красивой обложки
}

struct ArticleCategory: Identifiable {
    let id = UUID()
    let title: String
    let completedCount: Int
    let articles: [Article]
    
    var totalCount: Int { articles.count }
    
    static let mockData: [ArticleCategory] = [
        ArticleCategory(title: "Why calorie counting always works", completedCount: 0, articles: [
            Article(title: "Let's talk about how universal calorie counting is", isLocked: false, color1: .themeOrange, color2: .themeYellow, iconName: "scale.3d"),
            Article(title: "What's a 'cheat meal' and is it worth it?", isLocked: true, color1: .themePink, color2: .purple, iconName: "takeoutbag.and.cup.and.straw.fill"),
            Article(title: "What happens to your body when you lose 5kg?", isLocked: true, color1: .blue, color2: .cyan, iconName: "figure.mind.and.body")
        ]),
        ArticleCategory(title: "How to actually lose weight", completedCount: 1, articles: [
            Article(title: "How quickly can I lose weight?", isLocked: false, color1: .green, color2: .mint, iconName: "clock.fill"),
            Article(title: "The 'traffic light' hack", isLocked: true, color1: .red, color2: .orange, iconName: "lightbulb.fill"),
            Article(title: "Slipped up? Here's what to do the next day", isLocked: true, color1: .purple, color2: .indigo, iconName: "arrow.uturn.backward.circle.fill")
        ])
    ]
}

// MARK: - СЕКЦИЯ КАТЕГОРИИ
struct LearnCategorySection: View {
    let category: ArticleCategory
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Заголовок и прогресс-бар
            VStack(alignment: .leading, spacing: 8) {
                Text(category.title)
                    .font(.title3)
                    .bold()
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    // Кастомный мини-прогресс бар
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.gray.opacity(0.2))
                            Capsule()
                                .fill(Color.themePink)
                                .frame(width: geo.size.width * CGFloat(category.completedCount) / CGFloat(max(category.totalCount, 1)))
                        }
                    }
                    .frame(width: 60, height: 6)
                    
                    Text("\(category.completedCount)/\(category.totalCount) completed")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            // Горизонтальный скролл со статьями
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(category.articles) { article in
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            // TODO: Открытие статьи или экрана пейволла
                        }) {
                            ArticleCardView(article: article)
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10) // Для тени
            }
        }
    }
}

// MARK: - КАРТОЧКА СТАТЬИ
struct ArticleCardView: View {
    let article: Article
    
    var body: some View {
        VStack(spacing: 0) {
            // ВЕРХНЯЯ ЧАСТЬ: Имитация картинки (Градиент + Иконка)
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [article.color1, article.color2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Иконка на фоне для красоты
                Image(systemName: article.iconName)
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 10, y: 10)
                
                // Иконка замка (Платный контент)
                if article.isLocked {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 28, height: 28)
                            .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(12)
                }
            }
            .frame(height: 110)
            .clipped()
            
            // НИЖНЯЯ ЧАСТЬ: Белый фон и текст
            VStack(alignment: .leading) {
                Text(article.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 80)
            .background(Color.white)
        }
        .frame(width: 160) // Фиксированная ширина карточки
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}
