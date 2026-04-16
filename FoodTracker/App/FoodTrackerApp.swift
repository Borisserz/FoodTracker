// FILE: FoodTracker/App/FoodTrackerApp.swift

import SwiftUI
import SwiftData

// MARK: - AI Chat Models
@Model final class AIChatSession {
    var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var messages: [AIChatMessage] = []
    
    init(title: String = "New Chat", date: Date = Date(), messages: [AIChatMessage] = []) {
        self.title = title
        self.date = date
        self.messages = messages
    }
}

struct AIChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    let isUser: Bool
    var text: String
    var isAnimating: Bool = false
    
    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - App Entry Point
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
                // ✅ ДОБАВЛЕНО: AIChatSession.self
                for: User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self, DailySummary.self, AIChatSession.self,
                configurations: config
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
}

struct IdentifiableString: Identifiable, Hashable {
    let id = UUID()
    let value: String
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    @Query private var summaries: [DailySummary]
    
    @State private var selectedTab = 0
    @State private var showQuickAddSheet = false
    @State private var mealToOpenInSmartAdd: IdentifiableString? = nil
    
    var body: some View {
        TabView(selection: Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == 2 {
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
            
            FoodsDashboardView()
                .tabItem { Label("Foods", systemImage: "leaf.arrow.circlepath") }
                .tag(1)
            
            Color.clear
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(2)
            
            AnalyticsTabView()
                .tabItem { Label("Analytics", systemImage: "chart.bar.fill") }
                .tag(3)
            
            AICoachDashboardView(selectedDate: Date())
                .tabItem { Label("Coach", systemImage: "sparkles") }
                .tag(4)
        }
        .tint(.themePink)
        .onAppear {
            initializeUserIfNeeded()
        }
        .sheet(isPresented: $showQuickAddSheet) {
            PremiumQuickAddSheet(selectedDate: Date()) { selectedMeal in
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
            let today = calendar.startOfDay(for: Date())
            
            let summary: DailySummary
            if let existing = summaries.first(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
                summary = existing
            } else {
                summary = DailySummary(date: today)
                context.insert(summary)
            }
            
            var newFoodItems: [FoodItem] = []
            for item in items {
                let copiedItem = FoodItem(
                    name: item.name, weight: item.weight, calories: item.calories,
                    protein: item.protein, fats: item.fats, carbs: item.carbs,
                    omega3: item.omega3, calcium: item.calcium, potassium: item.potassium,
                    magnesium: item.magnesium, iron: item.iron, vitaminC: item.vitaminC, vitaminD: item.vitaminD
                )
                context.insert(copiedItem)
                newFoodItems.append(copiedItem)
            }
            
            if let existingMeal = summary.meals.first(where: { $0.title == title }) {
                existingMeal.foodItems.append(contentsOf: newFoodItems)
            } else {
                let newMeal = Meal(title: title, date: Date(), foodItems: newFoodItems)
                context.insert(newMeal)
                summary.meals.append(newMeal)
            }
            try? context.save()
        }
    } 
