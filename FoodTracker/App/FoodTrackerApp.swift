import SwiftUI
import SwiftData

@main
struct FoodTrackerApp: App {
    let modelContainer: ModelContainer
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .preferredColorScheme(.light)
        }
    }
    
    init() {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(
                for: User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self, DailySummary.self,
                configurations: config
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    
    var body: some View {
        TabView {
            HomeDashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }
            
            ChefRecipesView()
                .tabItem { Label("Chefs", systemImage: "star.circle.fill") }
            
            SuperFoodsView()
                .tabItem { Label("Foods", systemImage: "leaf.arrow.circlepath") }
            
            ProfileWrapperView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(.themePink)
        .onAppear {
            initializeUserIfNeeded()
        }
    }
    
    private func initializeUserIfNeeded() {
        if users.isEmpty {
            let defaultUser = User(name: "Alex", weight: 75.0, height: 180.0, age: 28, gender: "Male")
            context.insert(defaultUser)
            try? context.save()
        }
    }
}
