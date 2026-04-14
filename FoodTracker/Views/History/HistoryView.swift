import SwiftUI
import SwiftData

// MARK: - РОУТИНГ ДЛЯ РЕЦЕПТОВ
enum RecipeRoute: Hashable {
    case create
    case detail(CustomRecipe)
}

// MARK: - ГЛАВНЫЙ VIEW ИСТОРИИ
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @State private var path = NavigationPath()
    
    @Query(sort: \CustomRecipe.name) private var recipes: [CustomRecipe]
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
                VStack(spacing: 24) {
                    
                    // БЛОК РЕЦЕПТОВ
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
                                            // ИСПРАВЛЕНО: CustomRecipeCard теперь определена ниже
                                            CustomRecipeCard(
                                                title: recipe.name,
                                                calories: "\(recipe.totalCalories) kcal",
                                                items: recipe.info,
                                                cookingTime: recipe.cookingTime,
                                                difficulty: recipe.difficulty
                                            )
                                            // ИСПРАВЛЕНО: Этот модификатор теперь работает
                                            .foregroundColor(.primary)
                                        }
                                    }
                                }
                            }
                        }
                    }.padding(.top)
                    
                    // БЛОК ИСТОРИИ ПРИЕМОВ ПИЩИ
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Meals Logged").font(.title3).bold()
                        
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
                            // ИСПРАВЛЕНО: EmptyStateView теперь определена ниже
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

// MARK: - Вспомогательные View (добавлены для решения ошибок)

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

struct CustomRecipeCard: View {
    let title: String
    let calories: String
    let items: String
    let cookingTime: Int?
    let difficulty: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .lineLimit(1)
            
            Text(items)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack(spacing: 12) {
                if let cookingTime = cookingTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text("\(cookingTime)m")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
                
                if let difficulty = difficulty {
                    Text(difficulty)
                        .font(.caption2.bold())
                        .foregroundColor(.themeOrange)
                }
                
                Spacer()
            }
            
            Spacer()
            
            Text(calories)
                .font(.headline)
                .foregroundColor(.themePink)
        }
        .padding()
        .frame(width: 160, height: 140) // Задаем фиксированный размер для консистентности
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
    }
}

