import WidgetKit
import SwiftUI
import SwiftData

struct FoodTrackerEntry: TimelineEntry {
    let date: Date
    let hydrationLiters: Double
    let protein: Int
    let fat: Int
    let carbs: Int
    let totalCalories: Int
    let metabolicScore: Int
}

struct WidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FoodTrackerEntry {
        if let actualData = fetchTodayDataSynchronously() {
            return actualData
        }
        return FoodTrackerEntry(
            date: Date(),
            hydrationLiters: 1.25,
            protein: 80,
            fat: 45,
            carbs: 120,
            totalCalories: 1200,
            metabolicScore: 85
        )
    }

    private func fetchTodayDataSynchronously() -> FoodTrackerEntry? {
        let container = SharedModelContainer.shared.container
        let modelContext = ModelContext(container)
        
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate<DailySummary> { $0.date >= todayStart && $0.date < tomorrow }
        )
        
        do {
            if let todaySummary = try modelContext.fetch(descriptor).first {
                let calRatio = min(Double(todaySummary.totalFoodCalories) / 2000.0, 1.5)
                let calScore = calRatio <= 1.0 ? (calRatio * 50) : max(0, 50 - ((calRatio - 1.0) * 100))
                let hydRatio = min(todaySummary.totalHydrationLiters / 2.5, 1.0)
                let hydScore = hydRatio * 30
                let macroScore = 20.0
                let finalScore = Int(calScore + hydScore + macroScore)
                
                return FoodTrackerEntry(
                    date: Date(),
                    hydrationLiters: todaySummary.totalHydrationLiters,
                    protein: Int(todaySummary.totalProtein),
                    fat: Int(todaySummary.totalFats),
                    carbs: Int(todaySummary.totalCarbs),
                    totalCalories: todaySummary.totalFoodCalories,
                    metabolicScore: finalScore
                )
            }
        } catch {
            print("Failed to fetch widget data synchronously: \(error)")
        }
        return nil
    }

    func getSnapshot(in context: Context, completion: @escaping (FoodTrackerEntry) -> ()) {
        Task {
            let entry = await fetchTodayData(in: context)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FoodTrackerEntry>) -> ()) {
        Task {
            let entry = await fetchTodayData(in: context)
            // Reload every 1 hour, or when the app goes to background / intent is triggered
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    @MainActor
    private func fetchTodayData(in context: Context) -> FoodTrackerEntry {
        let container = SharedModelContainer.shared.container
        let modelContext = container.mainContext
        
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate<DailySummary> { $0.date >= todayStart && $0.date < tomorrow }
        )
        
        do {
            if let todaySummary = try modelContext.fetch(descriptor).first {
                
                // Calculate metabolic score using a simplified version of the logic from AnalyticsDashboardView
                let calRatio = min(Double(todaySummary.totalFoodCalories) / 2000.0, 1.5) // Assuming 2000 goal for widget
                let calScore = calRatio <= 1.0 ? (calRatio * 50) : max(0, 50 - ((calRatio - 1.0) * 100))
                let hydRatio = min(todaySummary.totalHydrationLiters / 2.5, 1.0)
                let hydScore = hydRatio * 30
                let macroScore = 20.0
                let finalScore = Int(calScore + hydScore + macroScore)
                
                return FoodTrackerEntry(
                    date: Date(),
                    hydrationLiters: todaySummary.totalHydrationLiters,
                    protein: Int(todaySummary.totalProtein),
                    fat: Int(todaySummary.totalFats),
                    carbs: Int(todaySummary.totalCarbs),
                    totalCalories: todaySummary.totalFoodCalories,
                    metabolicScore: finalScore
                )
            }
        } catch {
            print("Failed to fetch widget data: \(error)")
        }
        
        return placeholder(in: context)
    }
}

// MARK: - Shopping List Provider
struct ShoppingListEntry: TimelineEntry {
    let date: Date
    let items: [(id: String, name: String, amount: String, isChecked: Bool)]
}

struct ShoppingListTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShoppingListEntry {
        if let actualData = fetchItemsSynchronously(), !actualData.items.isEmpty {
            return actualData
        }
        return ShoppingListEntry(date: Date(), items: [
            (UUID().uuidString, "Eggs", "12", false),
            (UUID().uuidString, "Milk", "1L", false),
            (UUID().uuidString, "Avocado", "2", true),
            (UUID().uuidString, "Chicken Breast", "500g", false)
        ])
    }

    private func fetchItemsSynchronously() -> ShoppingListEntry? {
        let container = SharedModelContainer.shared.container
        let modelContext = ModelContext(container)
        
        var fetchDescriptor = FetchDescriptor<ShoppingItem>()
        fetchDescriptor.sortBy = [SortDescriptor(\.dateAdded, order: .reverse)]
        
        do {
            let allItems = try modelContext.fetch(fetchDescriptor)
            let active = allItems.filter { !$0.isChecked }
            let completed = allItems.filter { $0.isChecked }
            
            let displayItems = (active + completed).prefix(6).map { 
                (id: $0.id.uuidString, name: $0.name, amount: $0.amount, isChecked: $0.isChecked)
            }
            
            return ShoppingListEntry(date: Date(), items: Array(displayItems))
        } catch {
            print("Failed to fetch shopping items synchronously: \(error)")
        }
        return nil
    }

    func getSnapshot(in context: Context, completion: @escaping (ShoppingListEntry) -> ()) {
        Task {
            let entry = await fetchItems(in: context)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoppingListEntry>) -> ()) {
        Task {
            let entry = await fetchItems(in: context)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    @MainActor
    private func fetchItems(in context: Context) -> ShoppingListEntry {
        let container = SharedModelContainer.shared.container
        let modelContext = container.mainContext
        
        // Fetch all items, sort unchecked first, then by date
        var fetchDescriptor = FetchDescriptor<ShoppingItem>()
        fetchDescriptor.sortBy = [SortDescriptor(\.dateAdded, order: .reverse)]
        
        do {
            let allItems = try modelContext.fetch(fetchDescriptor)
            let active = allItems.filter { !$0.isChecked }
            let completed = allItems.filter { $0.isChecked }
            
            // Take top 6 items to fit in widget
            let displayItems = (active + completed).prefix(6).map { 
                (id: $0.id.uuidString, name: $0.name, amount: $0.amount, isChecked: $0.isChecked)
            }
            
            return ShoppingListEntry(date: Date(), items: Array(displayItems))
        } catch {
            print("Failed to fetch shopping items: \(error)")
        }
        
        return placeholder(in: context)
    }
}

