import AppIntents
import SwiftData
import WidgetKit
import Foundation

// NOTE: SharedModelContainer and DataModels are compiled in this target

struct AddWaterIntent: AppIntent {
    static var title: LocalizedStringResource { "Add 250ml Water" }
    static var description: IntentDescription { "Quickly add a glass of water to your daily hydration." }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let context = ModelContext(SharedModelContainer.shared.container)
            do {
                let now = Date()
                let groupDefaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
                let useMetric = groupDefaults?.object(forKey: "useMetricSystem") as? Bool ?? true
                let volumeMl = WorkoutSyncManager.standardWaterGlassMl(useMetric: useMetric)
                try WidgetStorageActions.addWaterGlassAndRecordPendingDelta(
                    volumeMl: volumeMl,
                    in: context,
                    for: now
                )
                groupDefaults?.set(Date().timeIntervalSince1970, forKey: SharedModelContainer.widgetStoreMutationTimestampKey)
                WidgetReloader.reloadAll()
            } catch {
                print("Failed to add water from intent: \(error)")
            }
        }

        return .result()
    }
}

struct ToggleShoppingItemIntent: AppIntent {
    static var title: LocalizedStringResource { "Toggle Shopping Item" }

    @Parameter(title: "Item ID")
    var itemID: String

    init(itemID: String) {
        self.itemID = itemID
    }

    init() {
        self.itemID = ""
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let context = ModelContext(SharedModelContainer.shared.container)
            do {
                try WidgetStorageActions.toggleShoppingItem(idString: itemID, in: context)
                UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)?
                    .set(Date().timeIntervalSince1970, forKey: SharedModelContainer.widgetStoreMutationTimestampKey)
                WidgetReloader.reloadAll()
            } catch {
                print("Failed to toggle shopping item from intent: \(error)")
            }
        }
        return .result()
    }
}
