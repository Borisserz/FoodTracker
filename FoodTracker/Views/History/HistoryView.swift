import SwiftUI
import SwiftData

// MARK: - РОУТИНГ ДЛЯ НОВОГО ЭКРАНА FOODS
enum FoodsRoute: Hashable {
    case recipes
    case diets
    case learn
    case createRecipe
    case recipeDetail(CustomRecipe)
    case premiumRecipeDetail(PremiumRecipe)
    case articleDetail(Article)
    case filteredList(String, [PremiumRecipe])
    case mealDetail(title: String, date: Date)// Добавлено для поддержки фильтров
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
                                    // Делаем всю карточку кликабельной
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
                    LearnDashboardView(path: $path)
                case .createRecipe:
                    CreateRecipeView(path: $path)
                case .recipeDetail(let recipe):
                    RecipeDetailView(recipe: recipe, path: $path)
                case .premiumRecipeDetail(let recipe):
                    PremiumRecipeDetailView(recipe: recipe)
                case .filteredList(let title, let recipes):
                    FilteredRecipesListView(title: title, recipes: recipes, path: $path)
                case .articleDetail(let article):
                    ArticleDetailView(article: article)
                case .mealDetail(let title, let date):
                    MealDetailView(title: title, date: date)
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
                // Кнопка удаления (работает независимо от клика по карточке)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red.opacity(0.8))
                        .font(.caption)
                        .padding(4) // Увеличиваем зону клика для корзины
                }
                
                Text("\(calories) kcal")
                    .font(.headline)
                    .foregroundColor(.themePink)
            }
            
            // Иконка-стрелочка (Chevron)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.gray.opacity(0.3))
        }
        .premiumCardStyle()
    }
}

// =========================================================================
// MARK: - ЭКРАНЫ АКАДЕМИИ (ИНТЕРФЕЙС)
// =========================================================================

struct LearnDashboardView: View {
    @Binding var path: NavigationPath
    @State private var dataLoader = AcademyDataLoader()
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 32) {
                // Вводный текст
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
                
                if dataLoader.categories.isEmpty {
                    ProgressView("Loading academy...")
                        .padding(.top, 50)
                } else {
                    // Рендерим категории из JSON
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

// MARK: - СЕКЦИЯ КАТЕГОРИИ
struct LearnCategorySection: View {
    let category: ArticleCategory
    @Binding var path: NavigationPath
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Заголовок и прогресс-бар
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
            
            // Горизонтальный скролл со статьями
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(category.articles) { article in
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            if article.isLocked {
                                // TODO: Показать экран подписки (Paywall)
                                print("Locked!")
                            } else {
                                path.append(FoodsRoute.articleDetail(article))
                            }
                        }) {
                            ArticleCardView(article: article)
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 15)
            }
        }
    }
}

// MARK: - КАРТОЧКА СТАТЬИ
struct ArticleCardView: View {
    let article: Article
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                LinearGradient(
                    colors: [article.color1, article.color2],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                Image(systemName: article.iconName)
                    .font(.system(size: 70))
                    .foregroundColor(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 10, y: 15)
                
                HStack(spacing: 4) {
                    Image(systemName: "book.fill").font(.system(size: 10))
                    Text("\(article.readTime) min").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8).padding(.vertical, 6)
                .background(.ultraThinMaterial).environment(\.colorScheme, .dark)
                .clipShape(Capsule()).padding(12)
                
                if article.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                        .padding(10).background(Color.black.opacity(0.4)).clipShape(Circle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(12)
                }
            }
            .frame(height: 120).clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                Text(article.title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(.primary).lineLimit(2).multilineTextAlignment(.leading)
                Text(article.subtitle).font(.system(size: 12, weight: .medium)).foregroundColor(.gray).lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).frame(height: 100).background(Color.white)
        }
        .frame(width: 180).cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
    }
}

// MARK: - ЭКРАН ЧТЕНИЯ СТАТЬИ
struct ArticleDetailView: View {
    let article: Article
    @Environment(\.dismiss) var dismiss
    
    // Парсим Markdown из JSON в красивый AttributedString
    private var markdownText: AttributedString {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.allowsExtendedAttributes = true
            options.interpretedSyntax = .full
            return try AttributedString(markdown: article.content, options: options)
        } catch {
            return AttributedString(article.content) // Если вдруг ошибка
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.themeBg.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // 1. ШАПКА (Градиент и Иконка)
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [article.color1, article.color2],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        
                        // Фоновая иконка
                        Image(systemName: article.iconName)
                            .font(.system(size: 150))
                            .foregroundColor(.white.opacity(0.15))
                            .offset(x: UIScreen.main.bounds.width * 0.4, y: 30)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "clock.fill")
                                Text("\(article.readTime) min read")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .clipShape(Capsule())
                            
                            Text(article.title)
                                .font(.system(size: 34, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineSpacing(4)
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 60) // Отступ для наслоения карточки текста
                    }
                    .frame(height: 380)
                    
                    // 2. КОНТЕНТ (Белая карточка с закруглениями)
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Рендерим Markdown
                        Text(markdownText)
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .lineSpacing(8)
                            .foregroundColor(.primary.opacity(0.9))
                        
                        Divider().padding(.vertical, 16)
                        
                        Button(action: {
                            HapticManager.shared.impact(style: .heavy)
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.title2)
                                Text("Mark as Completed")
                                    .font(.headline)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(LinearGradient(colors: [article.color1, article.color2], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(20)
                            .shadow(color: article.color1.opacity(0.4), radius: 10, y: 5)
                        }
                        .buttonStyle(BounceButtonStyle())
                        
                        Spacer(minLength: 120) // Отступ для нижнего Tab Bar
                    }
                    .padding(24)
                    .background(Color.themeBg) // Фон статьи
                    .cornerRadius(32, corners: [.topLeft, .topRight]) // Закругляем только верх
                    .offset(y: -32) // Поднимаем карточку на шапку
                    .padding(.bottom, -32) // Компенсируем сдвиг
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // 3. ПЛАВАЮЩАЯ КНОПКА НАЗАД (Поверх всего)
            HStack {
                Button(action: {
                    HapticManager.shared.impact(style: .light)
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.25)) // Темная прозрачность для читаемости на любом фоне
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 60) // Отступ от челки/островка
        }
        .navigationBarHidden(true)
    }
}
