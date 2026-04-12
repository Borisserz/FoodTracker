import SwiftUI
import SwiftData

// MARK: - РОУТИНГ ДЛЯ РЕЦЕПТОВ
enum RecipeRoute: Hashable {
    case create
    case detail(CustomRecipe)
}


struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @State private var path = NavigationPath()
    
    @Query(sort: \CustomRecipe.name) private var recipes: [CustomRecipe]
    @Query(sort: \Meal.date, order: .reverse) private var meals: [Meal]
    
    // 1. Возвращаем состояние для фильтра и опции
    @State private var selectedFilter: String = "All"
    let filterOptions = ["All", "Breakfast", "Lunch", "Snack", "Dinner"]
    
    // 2. НОВАЯ ЛОГИКА ФИЛЬТРАЦИИ для SwiftData
    // Это вычисляемое свойство будет "на лету" фильтровать
    // результаты, полученные из базы данных.
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
                VStack(spacing: 24) {
                    
                    // БЛОК РЕЦЕПТОВ (без изменений)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("My Custom Recipes").font(.title3).bold()
                            Spacer()
                            Button(action: { path.append(RecipeRoute.create) }) {
                                Image(systemName: "plus.circle.fill").foregroundColor(.themePink).font(.title2)
                            }
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                if recipes.isEmpty {
                                    Text("No custom recipes yet. Tap + to create one!")
                                        .font(.subheadline).foregroundColor(.gray).padding(.vertical, 20)
                                } else {
                                    ForEach(recipes) { recipe in
                                        Button(action: { path.append(RecipeRoute.detail(recipe)) }) {
                                            CustomRecipeCard(
                                                title: recipe.name,
                                                calories: "\(recipe.totalCalories) kcal",
                                                items: recipe.info,
                                                cookingTime: recipe.cookingTime,
                                                difficulty: recipe.difficulty
                                            ).foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }.padding(.top)
                    
                    // БЛОК ИСТОРИИ ПРИЕМОВ ПИЩИ С ВОЗВРАЩЕННЫМИ ФИЛЬТРАМИ
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Meals Logged").font(.title3).bold()
                        
                        // 3. Возвращаем UI для кнопок-фильтров
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
                        
                        // 4. Используем наш новый отфильтрованный массив `filteredMeals`
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
                                        color: colorForMeal(meal.title), // Динамический цвет
                                        onDelete: { deleteMeal(meal) }
                                    )
                                }
                            }
                        }
                    }
                }.padding(.horizontal)
            }
            .background(Color.themeBg)
            .navigationTitle("History")
            .navigationDestination(for: RecipeRoute.self) { route in
                switch route {
                case .create: CreateRecipeView(path: $path)
                case .detail(let recipe): RecipeDetailView(recipe: recipe, path: $path)
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
    
    // Вспомогательная функция для красивых цветов
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
struct FrequentMealRow: View {
    let timeTag: String; let title: String; let ingredients: String; let calories: String; let color: Color
    var onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(timeTag).font(.system(size: 10, weight: .bold)).foregroundColor(.white).padding(4).background(color).cornerRadius(4)
                Text(title).font(.headline)
                Text(ingredients).font(.caption).foregroundColor(.gray).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                Button(action: onDelete) {
                    Image(systemName: "trash").foregroundColor(.red).font(.caption)
                }
                Text("\(calories) kcal").font(.headline).foregroundColor(.themePink)
            }
        }.premiumCardStyle()
    }
}
