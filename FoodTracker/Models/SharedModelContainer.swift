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

public enum FoodTrackerSchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [
            User.self, Beverage.self, FoodItem.self, Meal.self, CustomRecipe.self, ActivityLog.self,
            DailySummary.self, AIChatSession.self, ShoppingItem.self,
            WeeklyMealPlan.self, MealPlanDay.self, MealPlanItem.self, WeightLog.self
        ]
    }
}

public enum FoodTrackerMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [FoodTrackerSchemaV1.self]
    }

    public static var stages: [MigrationStage] { [] }
}

public final class SharedModelContainer: @unchecked Sendable {
    public static let shared = SharedModelContainer()

    public static let appGroupIdentifier = "group.com.borisdev.FoodTracker2026"
    public static let iCloudContainerIdentifier = "iCloud.com.borisdev.FoodTracker2026"
    public static let widgetStoreMutationTimestampKey = "lastWidgetStoreMutationAt"

    public static var sharedSchema: Schema {
        Schema(versionedSchema: FoodTrackerSchemaV1.self)
    }

    public let container: ModelContainer
    /// True if persistent SQLite store failed and fell back to in-memory storage.
    public let didFallBackToInMemory: Bool
    /// True if App Group container was unavailable and store was placed in Application Support fallback.
    public let didUseFallbackDirectory: Bool

    public static func resolvedStoreDirectoryURL(
        appGroupContainerURL: URL?,
        fileManager: FileManager = .default
    ) -> (url: URL, didUseFallbackDirectory: Bool) {
        if let appGroupContainerURL {
            return (appGroupContainerURL, false)
        }
        let appSupportBase = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let fallbackDir = appSupportBase.appendingPathComponent("FoodTrackerStore", isDirectory: true)
        try? fileManager.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
        return (fallbackDir, true)
    }

    private init() {
        let schema = Self.sharedSchema
        let resolved = Self.resolvedStoreDirectoryURL(
            appGroupContainerURL: FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
            )
        )
        let dbURL = resolved.url.appendingPathComponent("FoodDatabase.sqlite")
        let isExtension = Bundle.main.bundlePath.hasSuffix(".appex")

        var fellBack = false
        self.container = Self.makeContainer(schema: schema, url: dbURL, enableCloudKit: !isExtension, didFallBackToInMemory: &fellBack)
        self.didFallBackToInMemory = fellBack
        self.didUseFallbackDirectory = resolved.didUseFallbackDirectory
    }

    @MainActor
    public static func refreshMainContext(_ context: ModelContext) {
        guard !context.hasChanges else { return }
        context.rollback()
    }

    public static func makeContainer(schema: Schema, url: URL, enableCloudKit: Bool = true) -> ModelContainer {
        var ignored = false
        return makeContainer(schema: schema, url: url, enableCloudKit: enableCloudKit, didFallBackToInMemory: &ignored)
    }

    private static func makeContainer(
        schema: Schema,
        url: URL,
        enableCloudKit: Bool,
        didFallBackToInMemory: inout Bool
    ) -> ModelContainer {
        didFallBackToInMemory = false
        if enableCloudKit {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                url: url,
                cloudKitDatabase: .private(iCloudContainerIdentifier)
            )
            if let cloudContainer = try? ModelContainer(
                for: schema,
                migrationPlan: FoodTrackerMigrationPlan.self,
                configurations: [cloudConfig]
            ) {
                return cloudContainer
            }
            print("⚠️ CloudKit init failed in SharedModelContainer, falling back to local store.")
        }

        let localConfig = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: FoodTrackerMigrationPlan.self,
                configurations: [localConfig]
            )
        } catch {
            print("⚠️ Local store init failed in SharedModelContainer (\(error)), falling back to in-memory store.")
            didFallBackToInMemory = true
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                preconditionFailure("Unable to initialize even an in-memory ModelContainer: \(error)")
            }
        }
    }
}
