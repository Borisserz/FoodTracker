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
            
            // Find today's DailySummary
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: todayStart)!
            
            let descriptor = FetchDescriptor<DailySummary>(
                predicate: #Predicate<DailySummary> { $0.date >= todayStart && $0.date < tomorrow }
            )
            
            do {
                if let todaySummary = try context.fetch(descriptor).first {
                    // Add a beverage entry (250ml)
                    let newBeverage = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 250.0)
                    todaySummary.beverages = (todaySummary.beverages ?? []) + [newBeverage]
                    
                    try context.save()
                } else {
                    // Create new summary if it doesn't exist
                    let newSummary = DailySummary(date: Date())
                    let newBeverage = Beverage(name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 250.0)
                    newSummary.beverages = (newSummary.beverages ?? []) + [newBeverage]
                    context.insert(newSummary)
                    try context.save()
                }
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
            }
        }
        return .result()
    }
}
