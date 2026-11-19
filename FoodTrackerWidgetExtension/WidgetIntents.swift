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
            let context = SharedModelContainer.shared.container.mainContext
            do {
                try WidgetStorageActions.addWaterGlass(volumeMl: 250.0, in: context, for: Date())
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
            let context = SharedModelContainer.shared.container.mainContext
            do {
                try WidgetStorageActions.toggleShoppingItem(idString: itemID, in: context)
                WidgetReloader.reloadAll()
            } catch {
                print("Failed to toggle shopping item from intent: \(error)")
            }
        }
        return .result()
    }
}
