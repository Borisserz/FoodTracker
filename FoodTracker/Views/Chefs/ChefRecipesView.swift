import SwiftUI
import SwiftData

// MARK: - 1. Data Model & Mock Data
struct ChefRecipe: Identifiable, Equatable {
    let id = UUID()
    let chef: String
    let name: String
    let calories: String
    let time: String
    let isPro: Bool
    let color1: Color
    let color2: Color
    let icon: String
    let description: String
}

let mockChefRecipes: [ChefRecipe] = [
    // Gordon Ramsay
    ChefRecipe(
        chef: "Gordon Ramsay", name: "Fit Beef Wellington", calories: "550 kcal", time: "45m", isPro: true,
        color1: .themePink, color2: .themeOrange, icon: "flame.fill",
        description: "A lean and protein-packed take on the classic Wellington."
    ),
    ChefRecipe(
        chef: "Gordon Ramsay", name: "Mediterranean Salmon", calories: "420 kcal", time: "30m", isPro: true,
        color1: .blue, color2: .cyan, icon: "fish.fill",
        description: "Fresh Atlantic salmon pan-seared with a drizzle of olive oil."
    ),
    // Jamie Oliver
    ChefRecipe(
        chef: "Jamie Oliver", name: "15-Min Healthy Pasta", calories: "480 kcal", time: "15m", isPro: true,
        color1: .green, color2: .mint, icon: "leaf.fill",
        description: "Quick, simple, and packed with hidden veggies."
    ),
    ChefRecipe(
        chef: "Jamie Oliver", name: "Veggie Salad Supreme", calories: "290 kcal", time: "20m", isPro: false,
        color1: .green, color2: .themeYellow, icon: "carrot.fill",
        description: "A beautiful, colorful bowl of goodness."
    )
]

struct RecipeCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - КОНТЕЙНЕР ВСЕХ РЕЦЕПТОВ (ПОЛЬЗОВАТЕЛЬ + ШЕФЫ)
struct RecipesContainerView: View {
    @Binding var path: NavigationPath
    @Query(sort: \CustomRecipe.name) private var customRecipes: [CustomRecipe]
    
    @Namespace private var animation
    @State private var selectedRecipe: ChefRecipe? = nil
    @State private var showDetail: Bool = false
    
    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    
                    // 1. МОИ КАСОМНЫЕ РЕЦЕПТЫ
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("My Recipes").font(.title2).bold()
                            Spacer()
                            Button(action: { path.append(FoodsRoute.createRecipe) }) {
                                Image(systemName: "plus.circle.fill").foregroundColor(.themePink).font(.title)
                            }
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                if customRecipes.isEmpty {
                                    Text("No custom recipes yet. Tap + to create one!")
                                        .font(.subheadline).foregroundColor(.gray).padding(.vertical, 20)
                                } else {
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
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top)
                    
                    Divider().padding(.horizontal)
                    
                    // 2. РЕЦЕПТЫ ОТ ШЕФОВ (ОРИГИНАЛЬНЫЙ КОД)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Chef Specials").font(.title2).bold()
                            .padding(.horizontal)
                        
                        ChefSectionView(
                            chefName: "Gordon Ramsay",
                            sectionIcon: "flame.fill",
                            recipes: mockChefRecipes.filter { $0.chef == "Gordon Ramsay" },
                            animation: animation,
                            selectedRecipe: $selectedRecipe,
                            showDetail: $showDetail
                        )
                        .padding(.horizontal)
                        
                        ChefSectionView(
                            chefName: "Jamie Oliver",
                            sectionIcon: "leaf.fill",
                            recipes: mockChefRecipes.filter { $0.chef == "Jamie Oliver" },
                            animation: animation,
                            selectedRecipe: $selectedRecipe,
                            showDetail: $showDetail
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(Color.themeBg.ignoresSafeArea())
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            
            // FULLSCREEN DETAIL STATE (Overlay)
            if showDetail, let recipe = selectedRecipe {
                ChefRecipeDetailView(
                    recipe: recipe,
                    animation: animation,
                    onDismiss: dismissDetail
                )
                .transition(.identity)
                .zIndex(1)
            }
        }
    }
    
    private func dismissDetail() {
        withAnimation(.spring(response: 0.55, dampingFraction: 0.75, blendDuration: 0)) {
            showDetail = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            selectedRecipe = nil
        }
    }
}

// MARK: - Карточка для кастомного рецепта
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
                        Image(systemName: "clock.fill").font(.caption)
                        Text("\(cookingTime)m").font(.caption)
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
        .frame(width: 160, height: 140)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Вспомогательные компоненты Шефов (Оригинальные)
struct ChefSectionView: View {
    let chefName: String
    let sectionIcon: String
    let recipes: [ChefRecipe]
    
    var animation: Namespace.ID
    @Binding var selectedRecipe: ChefRecipe?
    @Binding var showDetail: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: sectionIcon).foregroundColor(.themeOrange)
                Text(chefName).font(.title3).bold()
                Spacer()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recipes) { recipe in
                        RecipeCard(recipe: recipe, animation: animation, selectedRecipe: $selectedRecipe, showDetail: $showDetail)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct RecipeCard: View {
    let recipe: ChefRecipe
    var animation: Namespace.ID
    @Binding var selectedRecipe: ChefRecipe?
    @Binding var showDetail: Bool
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .medium)
            selectedRecipe = recipe
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75, blendDuration: 0)) {
                showDetail = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [recipe.color1, recipe.color2], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .matchedGeometryEffect(id: "bg_\(recipe.id)", in: animation)
                    Image(systemName: recipe.icon)
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                        .matchedGeometryEffect(id: "icon_\(recipe.id)", in: animation)
                }
                .frame(height: 100)
                
                Text(recipe.name)
                    .font(.subheadline).bold().foregroundColor(.primary).lineLimit(1)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) { Image(systemName: "flame.fill").font(.caption).foregroundColor(.themeOrange); Text(recipe.calories).font(.caption2).foregroundColor(.gray) }
                    HStack(spacing: 4) { Image(systemName: "clock.fill").font(.caption).foregroundColor(.themeYellow); Text(recipe.time).font(.caption2).foregroundColor(.gray) }
                    Spacer()
                }
            }
            .padding(10).frame(width: 180).background(Color.white).cornerRadius(12).shadow(color: Color.black.opacity(0.05), radius: 2)
        }
        .buttonStyle(RecipeCardButtonStyle())
        .opacity(selectedRecipe?.id == recipe.id && showDetail ? 0 : 1)
    }
}

struct ChefRecipeDetailView: View {
    let recipe: ChefRecipe
    var animation: Namespace.ID
    var onDismiss: () -> Void
    @State private var showContent = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                GeometryReader { geo in
                    let minY = geo.frame(in: .global).minY
                    let isScrollingDown = minY > 0
                    ZStack {
                        RoundedRectangle(cornerRadius: 0)
                            .fill(LinearGradient(colors: [recipe.color1, recipe.color2], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .matchedGeometryEffect(id: "bg_\(recipe.id)", in: animation)
                        Image(systemName: recipe.icon).font(.system(size: 80)).foregroundColor(.white).shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                            .scaleEffect(1.0 + (isScrollingDown ? minY / 500 : 0))
                            .matchedGeometryEffect(id: "icon_\(recipe.id)", in: animation)
                    }
                    .frame(height: 380 + (isScrollingDown ? minY : 0))
                    .offset(y: isScrollingDown ? -minY : 0)
                }
                .frame(height: 380)
                .zIndex(1)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text(recipe.name).font(.title).bold().foregroundColor(.primary)
                    HStack(spacing: 16) {
                        Label(recipe.calories, systemImage: "flame.fill").foregroundColor(.themeOrange)
                        Label(recipe.time, systemImage: "clock.fill").foregroundColor(.themeYellow)
                    }.font(.subheadline.bold())
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About this recipe").font(.title3).bold()
                        Text(recipe.description).font(.body).foregroundColor(.secondary).lineSpacing(6)
                    }.premiumCardStyle()
                    
                    Button { HapticManager.shared.impact(style: .medium) } label: {
                        HStack { Text("Start Cooking"); Image(systemName: "chevron.right") }
                            .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding().background(Color.themePink).cornerRadius(12)
                    }.padding(.top, 10)
                }
                .padding(24).opacity(showContent ? 1 : 0).offset(y: showContent ? 0 : 20)
            }
        }
        .background(Color.themeBg.ignoresSafeArea()).ignoresSafeArea(edges: .top)
        .onAppear { withAnimation(.easeOut(duration: 0.3).delay(0.2)) { showContent = true } }
        .overlay(alignment: .topTrailing) {
            Button {
                HapticManager.shared.impact(style: .rigid)
                withAnimation(.easeOut(duration: 0.15)) { showContent = false }
                onDismiss()
            } label: { Image(systemName: "xmark").font(.system(size: 16, weight: .bold)).foregroundColor(.white).padding(10).background(.ultraThinMaterial).clipShape(Circle()) }
            .padding(.trailing, 20).padding(.top, 50).opacity(showContent ? 1 : 0).scaleEffect(showContent ? 1 : 0.8)
        }
    }
}
