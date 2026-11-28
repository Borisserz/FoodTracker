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
    /// Error description if persistent local SQLite store failed to initialize.
    public let localStoreInitErrorDescription: String?

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
        var localErrorDescription: String? = nil
        self.container = Self.makeContainer(
            schema: schema,
            url: dbURL,
            enableCloudKit: !isExtension,
            didFallBackToInMemory: &fellBack,
            localStoreInitErrorDescription: &localErrorDescription
        )
        self.didFallBackToInMemory = fellBack
        self.didUseFallbackDirectory = resolved.didUseFallbackDirectory
        self.localStoreInitErrorDescription = localErrorDescription
    }

    @MainActor
    public static func refreshMainContext(_ context: ModelContext) {
        guard !context.hasChanges else { return }
        context.rollback()
    }

    public static func makeContainer(schema: Schema, url: URL, enableCloudKit: Bool = true) -> ModelContainer {
        var ignored = false
        var ignoredError: String? = nil
        return makeContainer(
            schema: schema,
            url: url,
            enableCloudKit: enableCloudKit,
            didFallBackToInMemory: &ignored,
            localStoreInitErrorDescription: &ignoredError
        )
    }

    private static func makeContainer(
        schema: Schema,
        url: URL,
        enableCloudKit: Bool,
        didFallBackToInMemory: inout Bool,
        localStoreInitErrorDescription: inout String?
    ) -> ModelContainer {
        didFallBackToInMemory = false
        localStoreInitErrorDescription = nil
        if enableCloudKit {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                url: url,
                cloudKitDatabase: .private(iCloudContainerIdentifier)
            )
            do {
                return try ModelContainer(
                    for: schema,
                    migrationPlan: FoodTrackerMigrationPlan.self,
                    configurations: [cloudConfig]
                )
            } catch {
                #if DEBUG
                print("⚠️ CloudKit init failed in SharedModelContainer, falling back to local store: \(error)")
                #endif
            }
        }

        let localConfig = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: FoodTrackerMigrationPlan.self,
                configurations: [localConfig]
            )
        } catch {
            #if DEBUG
            print("⚠️ Local store init failed in SharedModelContainer (\(error)), falling back to in-memory store.")
            #endif
            didFallBackToInMemory = true
            localStoreInitErrorDescription = error.localizedDescription
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [memoryConfig])
            } catch {
                preconditionFailure("Unable to initialize even an in-memory ModelContainer: \(error)")
            }
        }
    }
}
