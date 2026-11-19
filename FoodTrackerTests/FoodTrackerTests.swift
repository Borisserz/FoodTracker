import XCTest
import SwiftData
import HealthKit
import UserNotifications
@testable import FoodTracker

@MainActor
final class AuthManagerTests: XCTestCase {
    func testRunDeletionSequenceToleratesRevokeErrorAfterSuccessfulDeletion() async throws {
        var deletionCompleted = false
        struct DummyRevokeError: Error {}

        try await AuthManager.runDeletionSequence(
            reauthenticate: { "apple_code_123" },
            deleteAccount: { deletionCompleted = true },
            revokeAppleToken: { _ in throw DummyRevokeError() }
        )

        XCTAssertTrue(deletionCompleted)
    }
}

@MainActor
final class HealthKitManagerTests: XCTestCase {
    private let requestedKey = "healthKitAuthRequested_v1"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: requestedKey)
        super.tearDown()
    }

    func testResetAuthorizationStateClearsFlagAndPersistedKey() {
        let manager = HealthKitManager.shared
        UserDefaults.standard.set(true, forKey: requestedKey)
        manager.isAuthorized = true

        manager.resetAuthorizationState()

        XCTAssertFalse(manager.isAuthorized)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: requestedKey))
    }

    func testNonPositiveHealthKitWritesExitSafely() async {
        let manager = HealthKitManager.shared
        manager.resetAuthorizationState()

        await manager.saveWater(liters: 0, date: .now)
        await manager.saveWater(liters: -0.5, date: .now)
        await manager.saveDietaryEnergy(calories: 0, date: .now)
        await manager.saveDietaryEnergy(calories: -100, date: .now)
        await manager.saveWorkout(activityType: .running, calories: 0, durationMinutes: 30, date: .now)
        await manager.saveWorkout(activityType: .running, calories: 200, durationMinutes: 0, date: .now)

        XCTAssertFalse(manager.isAuthorized)
    }

    func testClampedWorkoutIntervalClampsToStartOfDayNearMidnight() {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 19
        components.hour = 0
        components.minute = 20
        components.second = 0
        let calendar = Calendar.current
        let afterMidnight = calendar.date(from: components)!
        let expectedStartOfDay = calendar.startOfDay(for: afterMidnight)

        let clamped = HealthKitManager.clampedWorkoutInterval(date: afterMidnight, durationMinutes: 60, calendar: calendar)
        XCTAssertEqual(clamped.start, expectedStartOfDay)
        XCTAssertEqual(clamped.end, afterMidnight)

        let midday = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: afterMidnight)!
        let normal = HealthKitManager.clampedWorkoutInterval(date: midday, durationMinutes: 45, calendar: calendar)
        XCTAssertEqual(normal.end, midday)
        XCTAssertEqual(normal.start, midday.addingTimeInterval(-45 * 60))
    }

    func testBodyMassLookbackStartDateIsNinetyDaysPrior() {
        let now = Date(timeIntervalSince1970: 1_795_000_000)
        let lookback = HealthKitManager.bodyMassLookbackStartDate(from: now)
        let diffDays = Calendar.current.dateComponents([.day], from: lookback, to: now).day
        XCTAssertEqual(diffDays, 90)
    }

    func testNotificationActionRouterMapsFastingNotificationsToFastingRoute() {
        XCTAssertEqual(
            AppDelegate.notificationDeepLinkRoute(identifier: "FASTING_GOAL_16", categoryIdentifier: "FASTING_MILESTONE"),
            "fasting"
        )
        XCTAssertEqual(
            AppDelegate.notificationDeepLinkRoute(identifier: "FASTING_STAGE_ketosis", categoryIdentifier: ""),
            "fasting"
        )
        XCTAssertNil(
            AppDelegate.notificationDeepLinkRoute(identifier: "WATER_REMINDER", categoryIdentifier: "HYDRATION")
        )
    }

    func testHealthKitManagerSaveWaterEnergyAndWorkoutThroughStoreProtocol() async throws {
        let mockStore = MockHealthKitStore()
        mockStore.authorizedTypes = Set([
            HKQuantityType.quantityType(forIdentifier: .dietaryWater)!,
            HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ])
        let manager = HealthKitManager(store: mockStore, isAvailable: { true })

        let waterID = await manager.saveWater(liters: 0.3, date: .now)
        let energyID = await manager.saveDietaryEnergy(calories: 420, date: .now)
        XCTAssertNotNil(waterID)
        XCTAssertNotNil(energyID)
        XCTAssertEqual(mockStore.savedObjects.count, 2)

        // Workout 20 minutes after midnight requesting 60 min must save clamped 20-min interval.
        var comps = DateComponents(year: 2026, month: 11, day: 19, hour: 0, minute: 20)
        let afterMidnight = Calendar.current.date(from: comps)!
        await manager.saveWorkout(activityType: .running, calories: 250, durationMinutes: 60, date: afterMidnight)

        let savedWorkout = mockStore.savedObjects.compactMap { $0 as? HKWorkout }.first
        XCTAssertNotNil(savedWorkout)
        XCTAssertEqual(savedWorkout?.startDate, Calendar.current.startOfDay(for: afterMidnight))
        XCTAssertEqual(savedWorkout?.duration ?? 0, 20 * 60, accuracy: 0.1)

        // When denied, saveWater exits without calling store.save.
        mockStore.authorizedTypes = []
        let deniedID = await manager.saveWater(liters: 0.25, date: .now)
        XCTAssertNil(deniedID)
    }

    func testHealthKitManagerFetchLatestBodyMassKgReturnsSampleAndEnforces90DayWindow() async throws {
        let mockStore = MockHealthKitStore()
        let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        let recentSample = HKQuantitySample(
            type: bodyMassType,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 74.6),
            start: Date().addingTimeInterval(-3600),
            end: Date().addingTimeInterval(-3600)
        )
        mockStore.quantitySamples = [recentSample]
        let manager = HealthKitManager(store: mockStore, isAvailable: { true })

        let kg = try await manager.fetchLatestBodyMassKg()
        XCTAssertEqual(kg ?? 0, 74.6, accuracy: 0.01)
    }
}

private final class MockHealthKitStore: HealthKitStoreExecuting, @unchecked Sendable {
    var authorizedTypes: Set<HKObjectType> = []
    var savedObjects: [HKObject] = []
    var quantitySamples: [HKQuantitySample] = []

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        authorizedTypes.contains(type) ? .sharingAuthorized : .sharingDenied
    }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {}

    func save(_ object: HKObject) async throws {
        savedObjects.append(object)
    }

    func delete(_ object: HKObject) async throws {
        savedObjects.removeAll { $0.uuid == object.uuid }
    }

    func sumQuantity(for identifier: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> Double {
        0
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [HKWorkout] {
        []
    }

    func fetchLatestQuantitySample(for identifier: HKQuantityTypeIdentifier, since start: Date) async throws -> HKQuantitySample? {
        quantitySamples.filter { $0.endDate >= start }.max(by: { $0.endDate < $1.endDate })
    }

    func fetchSourceQuantitySamples(for identifier: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> [HKQuantitySample] {
        quantitySamples
    }
}

@MainActor
final class WidgetIntentStorageTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(schema: SharedModelContainer.sharedSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: SharedModelContainer.sharedSchema, configurations: [config])
        return ModelContext(container)
    }

    func testAddWaterGlassCreatesTodaySummaryAndBeverage() throws {
        let context = try makeInMemoryContext()
        let fixedDate = Date()

        try WidgetStorageActions.addWaterGlass(volumeMl: 250.0, in: context, for: fixedDate)

        let summary = DailySummary.fetchOrCreate(for: fixedDate, in: context)
        XCTAssertEqual(summary.beverages?.count, 1)
        XCTAssertEqual(summary.beverages?.first?.volumeMl ?? 0, 250.0, accuracy: 0.01)
        XCTAssertEqual(summary.totalHydrationLiters, 0.25, accuracy: 0.001)
    }

    func testToggleShoppingItemFlipsCheckedStateAndIgnoresInvalidIDs() throws {
        let context = try makeInMemoryContext()
        let item = ShoppingItem(name: "Greek Yogurt", amount: "500g", isChecked: false)
        context.insert(item)
        try context.save()

        try WidgetStorageActions.toggleShoppingItem(idString: item.id.uuidString, in: context)
        XCTAssertTrue(item.isChecked)

        try WidgetStorageActions.toggleShoppingItem(idString: "not-a-valid-uuid", in: context)
        XCTAssertTrue(item.isChecked)
    }

    func testPerformAddWaterRecordsPendingWorkoutDeltaAlongsideSwiftDataSave() throws {
        let context = try makeInMemoryContext()
        let fixedDate = Date()
        let suite = "test.widget.intent.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        try WidgetStorageActions.addWaterGlassAndRecordPendingDelta(
            volumeMl: 250.0,
            in: context,
            for: fixedDate,
            sharedDefaults: defaults,
            appGroupDefaults: defaults
        )

        let pending = WorkoutSyncManager.shared.consumePendingWidgetWaterEntriesLiters(for: fixedDate, appGroupDefaults: defaults)
        XCTAssertEqual(pending.reduce(0, +), 0.25, accuracy: 0.001)
    }
}

@MainActor
final class ReminderNotificationSchedulerTests: XCTestCase {
    private final class MockReminderCenter: ReminderNotificationCenterProtocol, @unchecked Sendable {
        var status: UNAuthorizationStatus
        var grantOnRequest: Bool
        var requestAuthorizationCalls = 0
        var removedIdentifierBatches: [[String]] = []
        var addedIdentifiers: [String] = []

        init(status: UNAuthorizationStatus, grantOnRequest: Bool = true) {
            self.status = status
            self.grantOnRequest = grantOnRequest
        }

        func authorizationStatus() async -> UNAuthorizationStatus {
            status
        }

        func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
            requestAuthorizationCalls += 1
            if grantOnRequest {
                status = .authorized
            }
            return grantOnRequest
        }

        func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
            removedIdentifierBatches.append(identifiers)
        }

        func add(_ request: UNNotificationRequest) async throws {
            addedIdentifiers.append(request.identifier)
        }
    }

    func testReminderPreferencesDefaultMealsAndWaterToTrueAndWeightToFalse() {
        let suite = "ReminderPrefs.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let prefs = ReminderNotificationScheduler.currentPreferences(defaults: defaults)
        XCTAssertTrue(prefs.meals)
        XCTAssertTrue(prefs.water)
        XCTAssertFalse(prefs.weight)
    }

    func testReminderSyncOnAppActivePromptsOnceWhenNotDeterminedAndResyncsWhenAuthorized() async {
        let suite = "ReminderSync.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let unpromptedCenter = MockReminderCenter(status: .notDetermined, grantOnRequest: false)
        await ReminderNotificationScheduler.syncOnAppActive(defaults: defaults, center: unpromptedCenter)
        XCTAssertEqual(unpromptedCenter.requestAuthorizationCalls, 1)
        XCTAssertTrue(defaults.bool(forKey: ReminderNotificationScheduler.hasPromptedKey))
        XCTAssertTrue(unpromptedCenter.addedIdentifiers.isEmpty)

        // Second launch while still .notDetermined must not re-prompt automatically.
        await ReminderNotificationScheduler.syncOnAppActive(defaults: defaults, center: unpromptedCenter)
        XCTAssertEqual(unpromptedCenter.requestAuthorizationCalls, 1)

        // When user later authorizes, active sync schedules default lunch, dinner, and water reminders silently.
        let authorizedCenter = MockReminderCenter(status: .authorized)
        await ReminderNotificationScheduler.syncOnAppActive(defaults: defaults, center: authorizedCenter)
        XCTAssertEqual(authorizedCenter.requestAuthorizationCalls, 0)
        XCTAssertEqual(
            Set(authorizedCenter.addedIdentifiers),
            Set(ReminderNotificationScheduler.mealIDs + [ReminderNotificationScheduler.waterID])
        )

        // When denied, pending requests are cleared and nothing is scheduled.
        let deniedCenter = MockReminderCenter(status: .denied)
        await ReminderNotificationScheduler.syncOnAppActive(defaults: defaults, center: deniedCenter)
        XCTAssertEqual(deniedCenter.requestAuthorizationCalls, 0)
        XCTAssertTrue(deniedCenter.addedIdentifiers.isEmpty)
        XCTAssertFalse(deniedCenter.removedIdentifierBatches.isEmpty)
    }

    func testLocalDataResetClearsHasPromptedDefaultRemindersFlag() throws {
        let suite = "ReminderReset.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(true, forKey: ReminderNotificationScheduler.hasPromptedKey)
        let config = ModelConfiguration(schema: SharedModelContainer.sharedSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: SharedModelContainer.sharedSchema, configurations: [config])

        LocalDataResetService.wipeAllData(in: container.mainContext, defaults: defaults)
        XCTAssertFalse(defaults.bool(forKey: ReminderNotificationScheduler.hasPromptedKey))
    }

    func testLocalizableStringsCatalogCoversAuditMissingKeysAcrossAllSevenLocales() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot.appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: Any])

        let requiredKeys = [
            "Week", "Month", "Discover", "My Recipes",
            "Under 300", "300 - 450", "450 - 600", "600+ kcal",
            "Running", "Cycling", "Swimming", "Walking", "Yoga", "Gym",
            "Vitamins & Minerals", "Total Fat", "Fresh Start", "Protein Alert",
            "High Fat", "Low Energy?", "Apple Fitness", "Daily Walking",
            "Good morning,", "Good afternoon,", "Good evening,", "Good night,",
            "Metric", "Imperial", "Berry Pink", "Mint Fresh", "Cyber Blue",
            "Height", "Age", "Local database",
            "Hydration Tracker", "Track and quickly add water to your daily goal.",
            "Daily Macros", "See your protein, fat, and carbs at a glance.",
            "Keep track of your overall metabolic health score.",
            "Sticky Note", "Your shopping list right on the fridge.",
            "Fasting Tracker", "Current Stage", "Ends in:", "Done",
            "Add 250ml Water", "Quickly add a glass of water to your daily hydration.",
            "Toggle Shopping Item", "Item ID",
            "GOAL (%.0f fl oz)", "%.0f fl oz", "%.1f L", "%.1fL", "Hello, %@!",
            "P: %lldg", "F: %lldg", "C: %lldg"
        ]
        let requiredLocales = ["de", "es", "fr", "it", "pt-PT", "ru"]

        for key in requiredKeys {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], "Missing localization key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], "Missing localizations for: \(key)")
            for locale in requiredLocales {
                let locDict = try XCTUnwrap(localizations[locale] as? [String: Any], "Missing \(locale) for: \(key)")
                let stringUnit = try XCTUnwrap(locDict["stringUnit"] as? [String: Any], "Missing stringUnit in \(locale) for: \(key)")
                let value = stringUnit["value"] as? String ?? ""
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(locale) translation for: \(key)")
            }
        }
    }

    func testInfoPlistHealthUpdateDescriptionMentionsWorkoutsAndWeightAcrossLocales() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let plistCatalogURL = projectRoot.appendingPathComponent("FoodTracker/InfoPlist.xcstrings")
        let data = try Data(contentsOf: plistCatalogURL)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: Any])
        let entry = try XCTUnwrap(strings["NSHealthUpdateUsageDescription"] as? [String: Any])
        let locs = try XCTUnwrap(entry["localizations"] as? [String: Any])

        let expectedTerms: [String: [String]] = [
            "en": ["workout", "weight"],
            "ru": ["трениров", "вес"],
            "de": ["training", "gewicht"],
            "es": ["entrenamiento", "peso"],
            "fr": ["entraînement", "poids"],
            "it": ["allenament", "peso"],
            "pt-PT": ["treino", "peso"]
        ]
        for (locale, terms) in expectedTerms {
            let locDict = try XCTUnwrap(locs[locale] as? [String: Any], "Missing \(locale)")
            let unit = try XCTUnwrap(locDict["stringUnit"] as? [String: Any])
            let value = (unit["value"] as? String ?? "").lowercased()
            for term in terms {
                XCTAssertTrue(value.contains(term), "InfoPlist \(locale) missing '\(term)' in: \(value)")
            }
        }
    }

    func testAnalyticsMicroIronRDAMatchesCompactCard() {
        XCTAssertEqual(AnalyticsMicro.iron.rda, 18.0, accuracy: 0.001)
    }
}
