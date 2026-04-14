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
    
    @State private var selectedTab = 0
    @State private var showQuickAddSheet = false
    
    init() {
        // Скрываем нативный TabBar, чтобы использовать свой кастомный
        UITabBar.appearance().isHidden = true
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeDashboardView().tag(0)
                HistoryView().tag(1)
                Color.clear.tag(2) // Пустое место для FAB
                SuperFoodsView().tag(3)
                ChefRecipesView().tag(4)
            }
            .tint(.themePink)
            
            // Кастомный TabBar с вырезом
            CustomTabBar(selectedTab: $selectedTab, showQuickAdd: $showQuickAddSheet)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onAppear {
            initializeUserIfNeeded()
        }
        .sheet(isPresented: $showQuickAddSheet) {
            AddMealView(selectedDate: .now)
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

// MARK: - Custom Tab Bar UI
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showQuickAdd: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            // Подложка с вырезом
            TabBarShape()
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.06), radius: 15, x: 0, y: -4)
                .frame(height: 90)
            
            HStack(spacing: 0) {
                TabBarItem(icon: "house.fill", title: "Home", tab: 0, selectedTab: $selectedTab)
                TabBarItem(icon: "clock.fill", title: "History", tab: 1, selectedTab: $selectedTab)
                
                Spacer().frame(width: 80) // Место под центральную кнопку
                
                TabBarItem(icon: "leaf.arrow.circlepath", title: "Foods", tab: 3, selectedTab: $selectedTab)
                TabBarItem(icon: "star.circle.fill", title: "Chefs", tab: 4, selectedTab: $selectedTab)
            }
            .padding(.top, 16)
            
            // Центральная кнопка (FAB)
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                showQuickAdd = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(Circle())
                    .shadow(color: Color.themePink.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .offset(y: -28) // Поднимаем над баром
        }
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let tab: Int
    @Binding var selectedTab: Int
    
    var body: some View {
        Button {
            HapticManager.shared.impact(style: .light)
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: selectedTab == tab ? .bold : .regular))
                Text(title)
                    .font(.system(size: 10, weight: selectedTab == tab ? .bold : .medium))
            }
            .foregroundColor(selectedTab == tab ? .themePink : .gray.opacity(0.5))
            .frame(maxWidth: .infinity)
        }
    }
}

struct TabBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let center = width / 2
        let curveWidth: CGFloat = 85
        let curveHeight: CGFloat = 40
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: center - curveWidth/2, y: 0))
        
        // Плавный вырез
        path.addCurve(to: CGPoint(x: center + curveWidth/2, y: 0),
                      control1: CGPoint(x: center - curveWidth/4, y: curveHeight),
                      control2: CGPoint(x: center + curveWidth/4, y: curveHeight))
        
        path.addLine(to: CGPoint(x: width, y: 0))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}
