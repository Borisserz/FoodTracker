import Foundation
import SwiftData

@MainActor
public class SharedModelContainer {
    public static let shared = SharedModelContainer()
    
    public let container: ModelContainer
    
    private init() {
        let schema = Schema([
            User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self, DailySummary.self, AIChatSession.self, ShoppingItem.self,
            WeeklyMealPlan.self, MealPlanDay.self, MealPlanItem.self, WeightLog.self, ScannedFoodCache.self
        ])

        
        let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.borisdev.WorkoutTracker") ?? FileManager.default.temporaryDirectory
        let dbURL = groupURL.appendingPathComponent("FoodDatabase.sqlite")
        
        let cloudConfig = ModelConfiguration(
            schema: schema,
            url: dbURL,
            cloudKitDatabase: .private("iCloud.com.borisdev.FoodTracker2026")
        )
        
        do {
            self.container = try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            print("⚠️ CloudKit init failed in SharedModelContainer, falling back to local: \(error)")
            let localConfig = ModelConfiguration(schema: schema, url: dbURL, cloudKitDatabase: .none)
            self.container = try! ModelContainer(for: schema, configurations: [localConfig])
        }
    }
}
