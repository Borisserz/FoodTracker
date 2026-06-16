import SwiftUI
import WidgetKit

@main
struct FoodTrackerWidgetBundle: WidgetBundle {
    var body: some Widget {
        HydrationWidget()
        MacroRingsWidget()
        MetabolicScoreWidget()
        ShoppingListWidget()
    }
}

// MARK: - Hydration Widget
struct HydrationWidget: Widget {
    let kind: String = "HydrationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetTimelineProvider()) { entry in
            HydrationWidgetView(entry: entry)
        }
        .configurationDisplayName("Hydration Tracker")
        .description("Track and quickly add water to your daily goal.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Macro Rings Widget
struct MacroRingsWidget: Widget {
    let kind: String = "MacroRingsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetTimelineProvider()) { entry in
            MacroRingsWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Macros")
        .description("See your protein, fat, and carbs at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Metabolic Score Widget
struct MetabolicScoreWidget: Widget {
    let kind: String = "MetabolicScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetTimelineProvider()) { entry in
            MetabolicScoreWidgetView(entry: entry)
        }
        .configurationDisplayName("Metabolic Synergy")
        .description("Keep track of your overall metabolic health score.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Shopping List Widget
struct ShoppingListWidget: Widget {
    let kind: String = "ShoppingListWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ShoppingListTimelineProvider()) { entry in
            ShoppingListWidgetView(entry: entry)
        }
        .configurationDisplayName("Sticky Note")
        .description("Your shopping list right on the fridge.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
