import Foundation
import SwiftData

@MainActor
enum LocalDataResetService {
    private static let onboardingAndFeatureDefaultsKeys: [String] = [
        "hasCompletedOnboarding_v2",
        "hasCompletedInitialOnboarding_v2",
        "hasCompletedOnboarding",
        "hasSeenSpotlightTour_v1",
        "hasCompletedSpotlightTour_v5",
        "has_seen_widget_promo",
        "CompletedAcademyArticles",
        "isFasting",
        "fastingPlanName",
        "fastingTargetHours",
        "fastingStartTime",
        "remindMeals",
        "remindWater",
        "remindWeight",
        "useMetricSystem",
        "xpClaimedDateKeys",
        "healthKitAuthRequested_v1",
        "isPremiumActivated",
        "SelectedThemeIndex",
        "dailyQuestStates_v1",
        "dailyQuestClaimed_v1",
        "favoriteRecipeIDs",
        "favoriteRecipeTitles_v1",
        "favoriteFoodNames_v1",
        "blockedCommunityFoods",
        "loggedMealsCount",
        "lastReviewPromptAppVersion",
        "app_first_launch_date",
        AIPhotoConsentManager.defaultsKey
    ]

    /// Wipes all local SwiftData records, resets active fasting timers, clears app-specific defaults, and refreshes widgets.
    static func wipeAllData(in context: ModelContext, defaults: UserDefaults = .standard) {
        let modelTypes: [any PersistentModel.Type] = [
            MealPlanItem.self,
            MealPlanDay.self,
            WeeklyMealPlan.self,
            FoodItem.self,
            Meal.self,
            Beverage.self,
            ActivityLog.self,
            DailySummary.self,
            CustomRecipe.self,
            ShoppingItem.self,
            WeightLog.self,
            AIChatSession.self,
            User.self
        ]

        for modelType in modelTypes {
            deleteAll(modelType, in: context)
        }
        try? context.save()

        if FastingManager.shared.isFasting {
            FastingManager.shared.endFast()
        }

        BeforeAfterStorage.clearAll()

        for key in onboardingAndFeatureDefaultsKeys {
            defaults.removeObject(forKey: key)
        }
        WorkoutSyncManager.clearLocalSyncMetadata(defaults: defaults)
        HealthKitManager.shared.resetAuthorizationState()

        if defaults === UserDefaults.standard {
            UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)?.removeObject(forKey: "useMetricSystem")
            ThemeManager.shared.currentThemeIndex = 0
            AcademyDataLoader.shared.resetProgress()
            RecipeDataLoader.shared.resetFavorites()
            SpotlightTourManager.shared.isTourActive = false
            ReminderNotificationScheduler.sync(mealsEnabled: false, waterEnabled: false, weightEnabled: false)
            AIPhotoConsentManager.shared.syncFromDefaults()
        }

        WidgetReloader.reloadAll()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        guard let objects = try? context.fetch(FetchDescriptor<T>()) else { return }
        for object in objects {
            context.delete(object)
        }
    }
}
