import WidgetKit
import SwiftUI
import SwiftData

public struct FoodTrackerEntry: TimelineEntry {
    public let date: Date
    public let hydrationLiters: Double
    public let hydrationGoalLiters: Double
    public let protein: Int
    public let proteinGoal: Int
    public let fat: Int
    public let fatGoal: Int
    public let carbs: Int
    public let carbGoal: Int
    public let totalCalories: Int
    public let calorieGoal: Int
    public let metabolicScore: Int

    public init(
        date: Date,
        hydrationLiters: Double,
        hydrationGoalLiters: Double = 2.5,
        protein: Int,
        proteinGoal: Int = 150,
        fat: Int,
        fatGoal: Int = 70,
        carbs: Int,
        carbGoal: Int = 250,
        totalCalories: Int,
        calorieGoal: Int = 2000,
        metabolicScore: Int
    ) {
        self.date = date
        self.hydrationLiters = hydrationLiters
        self.hydrationGoalLiters = hydrationGoalLiters
        self.protein = protein
        self.proteinGoal = proteinGoal
        self.fat = fat
        self.fatGoal = fatGoal
        self.carbs = carbs
        self.carbGoal = carbGoal
        self.totalCalories = totalCalories
        self.calorieGoal = calorieGoal
        self.metabolicScore = metabolicScore
    }

    static func from(snapshot: DailyWidgetSnapshot, date: Date = Date()) -> FoodTrackerEntry {
        FoodTrackerEntry(
            date: date,
            hydrationLiters: snapshot.hydrationLiters,
            hydrationGoalLiters: snapshot.hydrationGoalLiters,
            protein: snapshot.protein,
            proteinGoal: snapshot.proteinGoal,
            fat: snapshot.fat,
            fatGoal: snapshot.fatGoal,
            carbs: snapshot.carbs,
            carbGoal: snapshot.carbGoal,
            totalCalories: snapshot.totalCalories,
            calorieGoal: snapshot.calorieGoal,
            metabolicScore: snapshot.metabolicScore
        )
    }
}

public struct ShoppingListEntry: TimelineEntry {
    public let date: Date
    public let items: [(id: String, name: String, amount: String, isChecked: Bool)]
    
    public init(date: Date, items: [(id: String, name: String, amount: String, isChecked: Bool)]) {
        self.date = date
        self.items = items
    }
}

struct WidgetTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FoodTrackerEntry {
        FoodTrackerEntry(
            date: Date(),
            hydrationLiters: 1.25,
            protein: 80,
            fat: 45,
            carbs: 120,
            totalCalories: 1200,
            metabolicScore: 85
        )
    }

    private func buildTodaySnapshot(in modelContext: ModelContext) -> DailyWidgetSnapshot {
        let today = Date()
        let todaySummary = DailySummary.fetchExisting(for: today, in: modelContext)
        let user = try? modelContext.fetch(FetchDescriptor<User>()).first
        return DailyWidgetSnapshot.compute(
            summary: todaySummary,
            user: user,
            sharedDefaults: UserDefaults(suiteName: WorkoutSyncManager.suiteName),
            date: today
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FoodTrackerEntry) -> ()) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            let snapshot = await fetchTodaySnapshot(in: context)
            completion(FoodTrackerEntry.from(snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FoodTrackerEntry>) -> ()) {
        Task {
            let now = Date()
            let snapshot = await fetchTodaySnapshot(in: context)
            let schedule = DailyWidgetSnapshot.timelineSchedule(for: snapshot, now: now)
            let entries = schedule.entries.map {
                FoodTrackerEntry.from(snapshot: $0.snapshot, date: $0.date)
            }
            let timeline = Timeline(entries: entries, policy: .after(schedule.reloadAt))
            completion(timeline)
        }
    }
    
    @MainActor
    private func fetchTodaySnapshot(in context: Context) -> DailyWidgetSnapshot {
        let container = SharedModelContainer.shared.container
        let modelContext = ModelContext(container)
        return buildTodaySnapshot(in: modelContext)
    }
}

struct ShoppingListTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ShoppingListEntry {
        ShoppingListEntry(date: Date(), items: [
            ("placeholder-eggs", "Eggs", "12", false),
            ("placeholder-milk", "Milk", "1L", false),
            ("placeholder-avocado", "Avocado", "2", true),
            ("placeholder-chicken", "Chicken Breast", "500g", false)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (ShoppingListEntry) -> ()) {
        if context.isPreview {
            completion(placeholder(in: context))
            return
        }
        Task {
            let entry = await fetchItems(in: context)
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ShoppingListEntry>) -> ()) {
        Task {
            let entry = await fetchItems(in: context)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
    
    @MainActor
    private func fetchItems(in context: Context) -> ShoppingListEntry {
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
            #if DEBUG
            print("Failed to fetch shopping items: \(error)")
            #endif
        }

        return ShoppingListEntry(date: Date(), items: [])
    }
}
