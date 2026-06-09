import Foundation
import FirebaseAnalytics
import FirebaseCrashlytics

public final class TrackingManager {
    public static let shared = TrackingManager()
    private init() {}

    public enum Event {
        case onboardingCompleted(goal: String, diet: String)
        case mealLogged(mealType: String, totalCalories: Int)
        case waterLogged(volume: Double)
        case customRecipeCreated(ingredientsCount: Int)
        case appOpened(source: String)
        case aiChefUsed(queryLength: Int)
        case featureDiscovered(feature: String)
        case errorOccurred(errorType: String, screen: String)

        var name: String {
            switch self {
            case .onboardingCompleted: return "onboarding_completed"
            case .mealLogged: return "meal_logged"
            case .waterLogged: return "water_logged"
            case .customRecipeCreated: return "recipe_created"
            case .appOpened: return "app_opened"
            case .aiChefUsed: return "ai_chef_used"
            case .featureDiscovered: return "feature_discovered"
            case .errorOccurred: return "error_occurred"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onboardingCompleted(let goal, let diet): return ["goal": goal, "diet": diet]
            case .mealLogged(let mealType, let cals): return ["meal_type": mealType, "total_calories": cals]
            case .waterLogged(let volume): return ["volume_ml": volume]
            case .customRecipeCreated(let count): return ["ingredients_count": count]
            case .appOpened(let source): return ["source": source]
            case .aiChefUsed(let len): return ["query_length": len]
            case .featureDiscovered(let feature): return ["feature": feature]
            case .errorOccurred(let type, let screen): return ["error_type": type, "screen": screen]
            }
        }
    }

    public func track(_ event: Event) {
        Analytics.logEvent(event.name, parameters: event.parameters)
        Crashlytics.crashlytics().log(event.name)
    }

    public func setUserProperty(name: String, value: String?) {
        Analytics.setUserProperty(value, forName: name)
        Crashlytics.crashlytics().setCustomValue(value ?? "nil", forKey: name)
    }

    public func recordError(error: Error) {
        Crashlytics.crashlytics().record(error: error)
    }
}
