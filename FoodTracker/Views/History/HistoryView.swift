import SwiftUI
import SwiftData

// MARK: - РОУТИНГ ДЛЯ НОВОГО ЭКРАНА FOODS
enum FoodsRoute: Hashable {
    case recipes
    case diets
    case createRecipe
    case recipeDetail(CustomRecipe)
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
                    
                    // 1. ДВЕ БОЛЬШИЕ КНОПКИ: РЕЦЕПТЫ И ДИЕТЫ
                    HStack(spacing: 16) {
                        FoodsFeatureCard(title: "Recipes", subtitle: "Custom & Chefs", icon: "book.pages.fill", color: .themePink) {
                            path.append(FoodsRoute.recipes)
                        }
                        
                        FoodsFeatureCard(title: "Diet Plans", subtitle: "Keto, Vegan...", icon: "leaf.fill", color: .green) {
                            path.append(FoodsRoute.diets)
                        }
                    }
                    .padding(.top, 10)
                    
                    // 2. БЛОК ИСТОРИИ ПРИЕМОВ ПИЩИ
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Meals Logged").font(.title2).bold()
                        
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
                            .padding(.bottom, 4)
                        }
                        
                        if filteredMeals.isEmpty {
                            let message = selectedFilter == "All" ? "Your logged meals will appear here." : "No meals logged for \(selectedFilter)."
                            EmptyStateView(imageName: "fork.knife", title: "No History", description: message)
                                .frame(height: 200).premiumCardStyle()
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
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .background(Color.themeBg)
            .navigationTitle("Foods Hub")
            .navigationDestination(for: FoodsRoute.self) { route in
                switch route {
                case .recipes:
                    RecipesContainerView(path: $path)
                case .diets:
                    DietsListView()
                case .createRecipe:
                    CreateRecipeView(path: $path)
                case .recipeDetail(let recipe):
                    RecipeDetailView(recipe: recipe, path: $path)
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

// MARK: - Плашка для Рецептов и Диет
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

// MARK: - Строка истории
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
