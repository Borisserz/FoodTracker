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
struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]
    
    @State private var selectedTab = 0
    
    // Стейты для новой логики добавления
    @State private var showQuickAddSheet = false
    @State private var mealToOpenInSmartAdd: IdentifiableString? = nil
    
    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == 2 {
                    // Нажатие на центральную кнопку "+"
                    HapticManager.shared.impact(style: .medium)
                    showQuickAddSheet = true
                } else {
                    selectedTab = newValue
                }
            }
        )) {
            HomeDashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)
            
            FoodsDashboardView() // БЫВШИЙ HISTORY
                .tabItem { Label("Foods", systemImage: "leaf.arrow.circlepath") }
                .tag(1)
            
            // Заглушка для центральной кнопки
            Color.clear
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(2)
            
            AnalyticsTabView() // НОВАЯ ВКЛАДКА С ГРАФИКАМИ
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
                .tag(3)
            
            ProfileWrapperView() // ПРОФИЛЬ ТЕПЕРЬ ОТДЕЛЬНЫЙ ТАБ
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(4)
        }
        .tint(.themePink)
        .onAppear {
            initializeUserIfNeeded()
        }
        .sheet(isPresented: $showQuickAddSheet) {
            PremiumQuickAddSheet(selectedDate: .now) { selectedMeal in
                self.mealToOpenInSmartAdd = IdentifiableString(value: selectedMeal)
            }
            .presentationDetents([.height(550)])
            .presentationCornerRadius(32)
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $mealToOpenInSmartAdd) { mealInfo in
            SmartAddFoodView(mealTitle: mealInfo.value) { selectedItems in
                addFoodsToMeal(title: mealInfo.value, items: selectedItems)
            }
        }
    }
    
    private func initializeUserIfNeeded() {
        if users.isEmpty {
            let defaultUser = User(name: "Alex", weight: 75.0, height: 180.0, age: 28, gender: "Male")
            context.insert(defaultUser)
            try? context.save()
        }
    }
    
    private func addFoodsToMeal(title: String, items: [FoodItem]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        let summary: DailySummary
        if let existing = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            summary = existing
        } else {
            summary = DailySummary(date: today)
            context.insert(summary)
        }
        
        if let existingMeal = summary.meals.first(where: { $0.title == title }) {
            existingMeal.foodItems.append(contentsOf: items)
        } else {
            let newMeal = Meal(title: title, date: .now, foodItems: items)
            context.insert(newMeal)
            summary.meals.append(newMeal)
        }
        try? context.save()
    }
}

struct QuickButton: View {
    let label: String
    var isPrimary: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isPrimary ? .themePink : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isPrimary ? Color.themePink.opacity(0.1) : Color.gray.opacity(0.05))
                .cornerRadius(12)
        }
    }
}
