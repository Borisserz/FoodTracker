import Foundation
import SwiftData
#if canImport(WidgetKit)
import WidgetKit
#endif

public enum WidgetReloader {
    public static func reloadAll() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

public final class SharedModelContainer: @unchecked Sendable {
    public static let shared = SharedModelContainer()
    
    public let container: ModelContainer
    
    private init() {
        let schema = Schema([
            User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self, ActivityLog.self, DailySummary.self, AIChatSession.self, ShoppingItem.self,
            WeeklyMealPlan.self, MealPlanDay.self, MealPlanItem.self, WeightLog.self
        ])
        
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.borisdev.WorkoutTracker") ?? FileManager.default.temporaryDirectory
        let dbURL = groupURL.appendingPathComponent("FoodDatabase.sqlite")
        let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")

        self.container = Self.makeContainer(schema: schema, url: dbURL, enableCloudKit: !isExtension)
    }

    public static func makeContainer(schema: Schema, url: URL, enableCloudKit: Bool = true) -> ModelContainer {
        if enableCloudKit {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                url: url,
                cloudKitDatabase: .private("iCloud.com.borisdev.FoodTracker2026")
            )
            if let cloudContainer = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
                return cloudContainer
            }
            print("⚠️ CloudKit init failed in SharedModelContainer, falling back to local store.")
        }

        let localConfig = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            print("⚠️ Local store init failed in SharedModelContainer (\(error)), falling back to in-memory store.")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                preconditionFailure("Unable to initialize even an in-memory ModelContainer: \(error)")
            }
        }
    }
}
