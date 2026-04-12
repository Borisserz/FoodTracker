import SwiftUI

// MARK: - Chef Recipes View
struct ChefRecipesView: View {
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Pro Badge
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Premium Feature")
                                .font(.caption)
                                .bold()
                                .padding(4)
                                .background(Color.white.opacity(0.3))
                                .cornerRadius(8)
                            
                            Text("Unlock Chef Recipes")
                                .font(.title3)
                                .bold()
                        }
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "lock.open.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.themePink, .themeOrange]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .padding()
                    
                    // Chef Sections
                    ChefSectionView(
                        chefName: "Gordon Ramsay",
                        icon: "flame.fill",
                        recipes: [
                            ("Fit Beef Wellington", "550 kcal", "45m", true),
                            ("Mediterranean Salmon", "420 kcal", "30m", true),
                            ("Scrambled Eggs", "320 kcal", "10m", false)
                        ]
                    )
                    .padding(.horizontal)
                    
                    ChefSectionView(
                        chefName: "Jamie Oliver",
                        icon: "leaf.fill",
                        recipes: [
                            ("15-Min Healthy Pasta", "480 kcal", "15m", true),
                            ("Veggie Salad Supreme", "290 kcal", "20m", false),
                            ("Green Smoothie Bowl", "350 kcal", "10m", true)
                        ]
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color.themeBg)
            .navigationTitle("Chef's Specials")
        }
    }
}

// MARK: - Chef Section View
struct ChefSectionView: View {
    let chefName: String
    let icon: String
    let recipes: [(name: String, calories: String, time: String, isPro: Bool)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.themeOrange)
                Text(chefName)
                    .font(.title3)
                    .bold()
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recipes, id: \.name) { recipe in
                        RecipeCard(
                            name: recipe.name,
                            calories: recipe.calories,
                            time: recipe.time,
                            isPro: recipe.isPro
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

// MARK: - Recipe Card
struct RecipeCard: View {
    let name: String
    let calories: String
    let time: String
    let isPro: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Photo placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .frame(height: 100)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundColor(.gray)
                )
            
            Text(name)
                .font(.subheadline)
                .bold()
                .lineLimit(1)
            
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption)
                        .foregroundColor(.themeOrange)
                    Text(calories)
                        .font(.caption2)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.themeYellow)
                    Text(time)
                        .font(.caption2)
                }
                
                Spacer()
                
                if isPro {
                    Text("PRO")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.themeOrange)
                        .cornerRadius(3)
                }
            }
        }
        .padding(10)
        .frame(width: 180)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2)
    }
}
