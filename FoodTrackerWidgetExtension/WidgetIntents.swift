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
            let container = SharedModelContainer.shared.container
            let context = container.mainContext

            do {
                let todaySummary = DailySummary.fetchOrCreate(for: Date(), in: context)
                let newBeverage = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 250.0)
                context.insert(newBeverage)
                todaySummary.addBeverage(newBeverage)
                try context.save()
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
            guard let uuid = UUID(uuidString: itemID) else { return }
            let container = SharedModelContainer.shared.container
            let context = container.mainContext
            
            let descriptor = FetchDescriptor<ShoppingItem>(
                predicate: #Predicate<ShoppingItem> { $0.id == uuid }
            )
            
            if let item = try? context.fetch(descriptor).first {
                item.isChecked.toggle()
                try? context.save()
                WidgetReloader.reloadAll()
            }
        }
        return .result()
    }
}
