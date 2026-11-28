import XCTest
import UIKit
import SwiftData
import HealthKit
import UserNotifications
@testable import FoodTracker

@MainActor
final class AuthManagerTests: XCTestCase {
    func testRunDeletionSequenceCompletesServerDeletionBeforeSurfacingRevokeError() async {
        var deletionCompleted = false
        struct DummyRevokeError: Error {}

        do {
            try await AuthManager.runDeletionSequence(
                reauthenticate: { "apple_code_123" },
                deleteAccount: { deletionCompleted = true },
                revokeAppleToken: { _ in throw DummyRevokeError() }
            )
            XCTFail("Expected AccountDeletionError.appleTokenRevocationFailed")
        } catch let error as AccountDeletionError {
            guard case .appleTokenRevocationFailed = error else {
                XCTFail("Expected appleTokenRevocationFailed, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

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
        XCTAssertEqual(
            AppDelegate.notificationDeepLinkRoute(identifier: "phase_4h", categoryIdentifier: ""),
            "fasting"
        )
        XCTAssertEqual(
            AppDelegate.notificationDeepLinkRoute(identifier: "fasting_goal_reached", categoryIdentifier: "FASTING_PHASE"),
            "fasting"
        )
        XCTAssertEqual(
            AppDelegate.notificationDeepLinkRoute(identifier: "WATER_REMINDER", categoryIdentifier: "HYDRATION"),
            "hydration"
        )
        XCTAssertNil(
            AppDelegate.notificationDeepLinkRoute(identifier: "UNKNOWN_ALERT", categoryIdentifier: "GENERAL")
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
        let comps = DateComponents(year: 2026, month: 11, day: 19, hour: 0, minute: 20)
        let afterMidnight = Calendar.current.date(from: comps)!
        let workoutResult = await manager.saveWorkout(activityType: .running, calories: 250, durationMinutes: 60, date: afterMidnight)

        let savedWorkout = mockStore.recordedWorkouts.first
        XCTAssertNotNil(workoutResult.workoutID)
        XCTAssertNotNil(savedWorkout)
        XCTAssertEqual(savedWorkout?.start, Calendar.current.startOfDay(for: afterMidnight))
        XCTAssertEqual(savedWorkout?.end.timeIntervalSince(savedWorkout?.start ?? afterMidnight) ?? 0, 20 * 60, accuracy: 0.1)

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

    func testHealthKitManagerIgnoresExternalSentinelOnWaterDeleteAndDeletesBodyMassByUUID() async throws {
        let mockStore = MockHealthKitStore()
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass)!
        mockStore.authorizedTypes = [waterType, bodyMassType]

        let localWater = HKQuantitySample(
            type: waterType,
            quantity: HKQuantity(unit: .liter(), doubleValue: 0.5),
            start: Date(),
            end: Date()
        )
        let weightSample = HKQuantitySample(
            type: bodyMassType,
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: 74.0),
            start: Date(),
            end: Date()
        )
        mockStore.quantitySamples = [localWater, weightSample]
        let manager = HealthKitManager(store: mockStore, isAvailable: { true })

        await manager.deleteWaterSample(
            idString: WorkoutSyncManager.externalWaterSentinelID,
            litersFallback: 0.5,
            date: .now
        )
        XCTAssertTrue(mockStore.deletedObjectUUIDs.isEmpty, "Deleting WorkoutTracker-imported water must never fallback-delete FoodTracker's own HK water sample")

        await manager.deleteBodyMassSample(
            idString: weightSample.uuid.uuidString,
            kgFallback: 74.0,
            date: .now
        )
        XCTAssertEqual(mockStore.deletedObjectUUIDs, [weightSample.uuid])
    }

    @MainActor
    func testDeleteWaterSampleDoesNotFallbackDeleteDifferentSampleWhenKnownUUIDIsMissing() async {
        let mockStore = MockHealthKitStore()
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        mockStore.authorizedTypes = [waterType]

        let stillValidGlass = HKQuantitySample(
            type: waterType,
            quantity: HKQuantity(unit: .liter(), doubleValue: 0.25),
            start: Date(),
            end: Date()
        )
        mockStore.quantitySamples = [stillValidGlass]
        let manager = HealthKitManager(store: mockStore, isAvailable: { true })

        // Request deletion of an already-removed UUID with identical 0.25 L volume.
        let missingUUID = UUID().uuidString
        await manager.deleteWaterSample(
            idString: missingUUID,
            litersFallback: 0.25,
            date: .now
        )
        XCTAssertTrue(
            mockStore.deletedObjectUUIDs.isEmpty,
            "When an exact HealthKit UUID is known but no longer present, must NOT fallback-delete a different sample of the same value"
        )
    }
}

private final class MockHealthKitStore: HealthKitStoreExecuting, @unchecked Sendable {
    var authorizedTypes: Set<HKObjectType> = []
    var savedObjects: [HKObject] = []
    var recordedWorkouts: [(activityType: HKWorkoutActivityType, start: Date, end: Date, calories: Int)] = []
    var quantitySamples: [HKQuantitySample] = []
    var deletedObjectUUIDs: [UUID] = []

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        authorizedTypes.contains(type) ? .sharingAuthorized : .sharingDenied
    }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {}

    func save(_ object: HKObject) async throws {
        savedObjects.append(object)
    }

    func finishWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        calories: Int,
        metadata: [String: Any]
    ) async throws -> (workoutID: UUID, energySampleID: UUID?) {
        recordedWorkouts.append((activityType: activityType, start: start, end: end, calories: calories))
        var energySampleID: UUID?
        if calories > 0, let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))
            let sample = HKQuantitySample(type: energyType, quantity: energyBurned, start: start, end: end)
            savedObjects.append(sample)
            energySampleID = sample.uuid
        }
        return (UUID(), energySampleID)
    }

    func delete(_ object: HKObject) async throws {
        deletedObjectUUIDs.append(object.uuid)
        savedObjects.removeAll { $0.uuid == object.uuid }
        quantitySamples.removeAll { $0.uuid == object.uuid }
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

    func testPerformAddWaterReconcilesExternalWorkoutTrackerWaterBeforeWriting() throws {
        let context = try makeInMemoryContext()
        let fixedDate = Date()
        let sharedSuite = "test.widget.reconcile.shared.\(UUID().uuidString)"
        let syncSuite = "test.widget.reconcile.sync.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: sharedSuite)!
        let syncDefaults = UserDefaults(suiteName: syncSuite)!
        defer {
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
            syncDefaults.removePersistentDomain(forName: syncSuite)
        }

        // Baseline: 0.5 L synced locally and in WorkoutTracker.
        let summary = DailySummary.fetchOrCreate(for: fixedDate, in: context)
        let initialDrink = Beverage(date: fixedDate, name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 500)
        context.insert(initialDrink)
        summary.addBeverage(initialDrink)
        try context.save()
        WorkoutSyncManager.shared.syncWater(0.5, for: fixedDate, sharedDefaults: sharedDefaults, appGroupDefaults: syncDefaults, localDefaults: syncDefaults)

        // WorkoutTracker logs +0.5 L -> shared is now 1.0 L before main FoodTracker app opens.
        sharedDefaults.set(1.0, forKey: WorkoutSyncManager.waterLitersKey(for: fixedDate))

        // User taps +250 ml on FoodTracker Widget.
        try WidgetStorageActions.addWaterGlassAndRecordPendingDelta(
            volumeMl: 250.0,
            in: context,
            for: fixedDate,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: syncDefaults
        )

        XCTAssertEqual(summary.totalPureWaterLiters, 1.25, accuracy: 0.01)
        XCTAssertEqual(sharedDefaults.double(forKey: WorkoutSyncManager.waterLitersKey(for: fixedDate)), 1.25, accuracy: 0.01)
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
        var pendingIdentifiers: Set<String> = []
        var addDelayNanoseconds: UInt64 = 0

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
            for id in identifiers {
                pendingIdentifiers.remove(id)
            }
        }

        func add(_ request: UNNotificationRequest) async throws {
            if addDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: addDelayNanoseconds)
            }
            addedIdentifiers.append(request.identifier)
            pendingIdentifiers.insert(request.identifier)
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

    func testReminderSchedulerSerializesConcurrentSyncCalls() async {
        let center = MockReminderCenter(status: .authorized)
        center.addDelayNanoseconds = 30_000_000

        async let first: Void = ReminderNotificationScheduler.syncAsync(
            mealsEnabled: true,
            waterEnabled: true,
            weightEnabled: false,
            center: center,
            requestAuthorizationIfNotDetermined: false
        )
        async let second: Void = ReminderNotificationScheduler.syncAsync(
            mealsEnabled: true,
            waterEnabled: true,
            weightEnabled: false,
            center: center,
            requestAuthorizationIfNotDetermined: false
        )
        _ = await (first, second)

        XCTAssertEqual(
            center.pendingIdentifiers,
            Set(ReminderNotificationScheduler.mealIDs + [ReminderNotificationScheduler.waterID]),
            "Serialized sync calls must leave all expected reminder IDs scheduled without mid-flight removal races"
        )
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

    func testAnalyticsMicroGenderAndAgeAwareRDAs() {
        let male30 = User(name: "Max", weight: 80, height: 180, age: 30, gender: "Male")
        let female30 = User(name: "Anna", weight: 60, height: 165, age: 30, gender: "Female")
        let female55 = User(name: "Elena", weight: 62, height: 165, age: 55, gender: "Female")
        let male72 = User(name: "Boris", weight: 75, height: 175, age: 72, gender: "Male")

        XCTAssertEqual(AnalyticsMicro.iron.rda(for: male30), 8.0, accuracy: 0.001)
        XCTAssertEqual(AnalyticsMicro.iron.rda(for: female30), 18.0, accuracy: 0.001)
        XCTAssertEqual(AnalyticsMicro.iron.rda(for: female55), 8.0, accuracy: 0.001)
        XCTAssertEqual(AnalyticsMicro.vitaminD.rda(for: female30), 15.0, accuracy: 0.001)
        XCTAssertEqual(AnalyticsMicro.vitaminD.rda(for: male72), 20.0, accuracy: 0.001)
    }

    func testChefCalorieRangesPartitionWithoutOverlap() {
        let ranges = ChefCalorieRangeCatalog.ranges
        XCTAssertEqual(ranges.count, 4)
        for boundary in [300, 450, 600] {
            let matching = ranges.filter { boundary >= $0.minCalories && boundary <= $0.maxCalories }
            XCTAssertEqual(matching.count, 1, "Boundary \(boundary) kcal must belong to exactly one range")
        }
    }

    func testMedicalCitationCatalogProvidesValidOfficialSourcesAndDietsExposeContraindications() {
        let all = MedicalCitation.allCases
        XCTAssertEqual(all.count, 5)
        for citation in all {
            XCTAssertEqual(citation.url.scheme, "https")
            XCTAssertNotNil(citation.url.host)
        }
        XCTAssertTrue(MedicalCitation.bmrAndTdee.url.absoluteString.contains("pubmed.ncbi.nlm.nih.gov"))
        XCTAssertTrue(MedicalCitation.bmi.url.absoluteString.contains("who.int"))
        XCTAssertTrue(MedicalCitation.dietaryGuidelines.url.absoluteString.contains("dietaryguidelines.gov"))
        XCTAssertTrue(MedicalCitation.micronutrients.url.absoluteString.contains("ods.od.nih.gov"))
        XCTAssertTrue(MedicalCitation.intermittentFasting.url.absoluteString.contains("pubmed.ncbi.nlm.nih.gov"))

        for diet in DietPlan.defaultDiets {
            XCTAssertFalse(diet.contraindications.isEmpty, "Diet \(diet.key) must declare medical contraindications")
        }
    }

    func testWave1DisclaimerAndConsentKeysLocalizedAcrossAllSevenLocales() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot.appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: Any])

        let requiredKeys = [
            "Estimates are for informational and educational purposes only and are not medical advice. Consult a healthcare professional before starting any diet or fasting protocol.",
            "Sources & Methodology",
            "Mifflin-St Jeor (BMR/TDEE)",
            "WHO BMI Classification",
            "USDA Dietary Guidelines",
            "NIH Micronutrient RDAs",
            "NEJM Fasting Review",
            "Medical Contraindications",
            "Consult a doctor before starting if any of the following apply:",
            "AI Data & Photo Consent",
            "Allow AI Analysis",
            "Allow AI Data & Photo Analysis",
            "Personalize with AI",
            "Review how your photos and nutrition context are processed before using AI features.",
            "Personalized for %@ with %lld kcal/day",
            "AI Limit Reached",
            "Temporary Storage Mode",
            "Fits ~%lld kcal • %@",
            "Replace Active Fast?",
            "%lld items",
            "Over Goal: **%lld**",
            "Day %lld",
            "Next glass in %lld min",
            "Calories shown per %lld serving(s); ingredient amounts reflect full %lld-serving batch."
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
}

@MainActor
final class AppStoreReadinessTests: XCTestCase {
    func testCriticalSFSymbolsExistInSystemCatalog() {
        for micro in AnalyticsMicro.allCases {
            XCTAssertNotNil(
                UIImage(systemName: micro.icon),
                "Invalid SF Symbol '\(micro.icon)' in AnalyticsMicro.\(micro)"
            )
        }

        for plan in FastingPlan.defaultPlans {
            XCTAssertNotNil(
                UIImage(systemName: plan.icon),
                "Invalid SF Symbol '\(plan.icon)' in FastingPlan '\(plan.title)'"
            )
            for benefit in plan.benefits {
                XCTAssertNotNil(
                    UIImage(systemName: benefit.icon),
                    "Invalid SF Symbol '\(benefit.icon)' in FastingPlan '\(plan.title)' benefit '\(benefit.text)'"
                )
            }
        }

        for (label, symbol, _) in AdvancedRecipeFilterSheet.dietFilterOptions {
            XCTAssertNotNil(
                UIImage(systemName: symbol),
                "Invalid SF Symbol '\(symbol)' in AdvancedRecipeFilterSheet diet '\(label)'"
            )
        }

        for diet in ["Keto", "Vegan", "Paleo", "Mediterranean", "Balanced"] {
            let symbol = SmartPlanBuilderFlow.iconForDiet(diet)
            XCTAssertNotNil(
                UIImage(systemName: symbol),
                "Invalid SF Symbol '\(symbol)' in SmartPlanBuilderFlow diet '\(diet)'"
            )
        }
    }

    func testAppTargetsIPhoneOnlyForV1Release() throws {
        let families = try XCTUnwrap(Bundle.main.infoDictionary?["UIDeviceFamily"] as? [Int])
        XCTAssertEqual(families, [1], "v1.0 release must target iPhone only until iPad layouts are implemented")
    }

    func testP0AuthAndPromoKeysLocalizedAcrossAllSevenLocales() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot.appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: Any])

        let keys = [
            "Open",
            "Failed to remove server account data (HTTP %lld). Please try again.",
            "No active user session found to delete.",
            "Your FoodTracker account and local data were deleted, but automatic Sign in with Apple revocation failed (%@). Please revoke access manually in iOS Settings → Apple Account → Sign in with Apple.",
            "Unable to retrieve Apple ID information.",
            "Missing Apple authorization code. Please try signing in with Apple again before deleting your account.",
            "Failed to obtain Google token.",
            "Google sign-in is not configured (no clientID).",
            "Failed to open login window.",
            "You are not signed in."
        ]
        for key in keys {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], "Missing key: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any], "Missing localizations: \(key)")
            for locale in ["en", "ru", "de", "es", "fr", "it", "pt-PT"] {
                let locDict = try XCTUnwrap(localizations[locale] as? [String: Any], "Missing \(locale) for \(key)")
                let unit = try XCTUnwrap(locDict["stringUnit"] as? [String: Any])
                let val = unit["value"] as? String ?? ""
                XCTAssertFalse(val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(locale) for \(key)")
            }
        }
    }

    func testCriticalNonEnglishStringsAreTranslatedInAllFiveLocales() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectRoot.appendingPathComponent("Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: Any])

        let checks: [(locale: String, key: String)] = [
            ("fr", "Net %lld calories, %@"),
            ("fr", "Expert"),
            ("fr", "EXPERT"),
            ("de", "Hydration"),
            ("de", "HYDRATION"),
            ("de", "Protein"),
            ("de", "PROTEIN"),
            ("de", "Level %lld"),
            ("de", "Imperial (lb, in, fl oz)"),
            ("de", "Imperial (lb, ft, oz)"),
            ("es", "Imperial (lb, in, fl oz)"),
            ("es", "Imperial (lb, ft, oz)"),
            ("pt-PT", "Imperial (lb, in, fl oz)"),
            ("pt-PT", "Imperial (lb, ft, oz)")
        ]

        for check in checks {
            let entry = try XCTUnwrap(strings[check.key] as? [String: Any], "Missing key \(check.key)")
            let locs = try XCTUnwrap(entry["localizations"] as? [String: Any])
            let enVal = (locs["en"] as? [String: Any])?["stringUnit"].flatMap { ($0 as? [String: Any])?["value"] as? String } ?? check.key
            let locVal = (locs[check.locale] as? [String: Any])?["stringUnit"].flatMap { ($0 as? [String: Any])?["value"] as? String } ?? ""
            XCTAssertFalse(locVal.isEmpty, "Empty \(check.locale) value for \(check.key)")
            XCTAssertNotEqual(locVal, enVal, "Untranslated \(check.locale) value '\(locVal)' for key '\(check.key)'")
        }

        let newAIAndErrorKeys = [
            "AI rate limit reached. Retry after %@ seconds.",
            "AI rate limit reached. Please try again later.",
            "AI service error (HTTP %lld)",
            "AI service temporarily unavailable.",
            "Report AI Output",
            "Inaccurate nutrition estimate",
            "Unsafe or inappropriate content",
            "Other issue",
            "Tell us what went wrong with this AI response so we can improve safety and accuracy.",
            "Report Submitted",
            "Thank you for your feedback. Please verify critical nutrition details manually."
        ]
        for key in newAIAndErrorKeys {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], "Missing key \(key)")
            let locs = try XCTUnwrap(entry["localizations"] as? [String: Any])
            for locale in ["en", "ru", "de", "es", "fr", "it", "pt-PT"] {
                let locVal = (locs[locale] as? [String: Any])?["stringUnit"].flatMap { ($0 as? [String: Any])?["value"] as? String } ?? ""
                XCTAssertFalse(locVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(locale) for \(key)")
            }
        }
    }

    func testWave4LocalizationAndWidgetAssetIntegrity() throws {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let catalogURL = projectRoot.appendingPathComponent("Localizable.xcstrings")
        let catalogData = try Data(contentsOf: catalogURL)
        let catalogJson = try XCTUnwrap(try JSONSerialization.jsonObject(with: catalogData) as? [String: Any])
        let strings = try XCTUnwrap(catalogJson["strings"] as? [String: Any])

        let translatedChecks: [(locale: String, key: String)] = [
            ("de", "SETUP"),
            ("de", "TOOLS"),
            ("de", "SCORE"),
            ("fr", "SCORE"),
            ("de", "LVL %lld"),
            ("de", "Snack"),
            ("es", "Snack"),
            ("es", "Smoothie"),
            ("fr", "GAMIFICATION & XP"),
            ("de", "Optional")
        ]
        for check in translatedChecks {
            let entry = try XCTUnwrap(strings[check.key] as? [String: Any], "Missing key \(check.key)")
            let locs = try XCTUnwrap(entry["localizations"] as? [String: Any])
            let enVal = (locs["en"] as? [String: Any])?["stringUnit"].flatMap { ($0 as? [String: Any])?["value"] as? String } ?? check.key
            let locVal = (locs[check.locale] as? [String: Any])?["stringUnit"].flatMap { ($0 as? [String: Any])?["value"] as? String } ?? ""
            XCTAssertFalse(locVal.isEmpty, "Empty \(check.locale) value for \(check.key)")
            XCTAssertNotEqual(locVal, enVal, "Untranslated \(check.locale) value '\(locVal)' for \(check.key)")
        }

        let wave4Keys = [
            "Dietary Fiber",
            "Total Sugars",
            "Net Carbs",
            "Custom Fast",
            "Custom %lldh",
            "Start Custom %lldh Fast",
            "Duration: %lld hours",
            "Custom fasting schedule.",
            "Edit Start Time",
            "Fasting History",
            "Break your fast gently with protein and whole foods.",
            "Copy Meal",
            "Copy to Today",
            "Copy to Tomorrow",
            "Copied %lld items to Today",
            "Copied %lld items to Tomorrow",
            "Copy Day",
            "Copy Day to Today",
            "Copy Day to Tomorrow",
            "Logged Activities",
            "Fixed per serving — nutrition applies as logged.",
            "Workouts & Activity",
            "Apple Watch Workouts",
            "Notifications Disabled in iOS Settings",
            "Enable notifications in Settings to receive meal, hydration, and weigh-in reminders.",
            "Camera capture timed out. Please try again.",
            "No internet connection. Please check your network and try again.",
            "The AI request timed out. Please try again.",
            "Network error while contacting AI service. Please try again.",
            "AI returned an unexpected format. Please try again.",
            "AI service is currently unavailable. Please try again.",
            "Log to Today's Diary (%lld kcal)",
            "Next glass in %lld min • Tap to remind",
            "Reminder set for %lld min",
            "Time to Hydrate 💧"
        ]
        for key in wave4Keys {
            let entry = try XCTUnwrap(strings[key] as? [String: Any], "Missing Wave 4 key \(key)")
            let locs = try XCTUnwrap(entry["localizations"] as? [String: Any])
            for locale in ["en", "ru", "de", "es", "fr", "it", "pt-PT"] {
                let locVal = (locs[locale] as? [String: Any])?["stringUnit"].flatMap { ($0 as? [String: Any])?["value"] as? String } ?? ""
                XCTAssertFalse(locVal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(locale) for \(key)")
            }
        }

        let ptRecipesURL = projectRoot.appendingPathComponent("FoodTracker/recipes_pt-PT.json")
        let ptRecipesText = try String(contentsOf: ptRecipesURL, encoding: .utf8)
        XCTAssertFalse(ptRecipesText.contains("Cetogênico"), "Brazilian spelling 'Cetogênico' found in recipes_pt-PT.json")

        let accentURLs = [
            projectRoot.appendingPathComponent("FoodTracker/Assets.xcassets/AccentColor.colorset/Contents.json"),
            projectRoot.appendingPathComponent("FoodTrackerWidgetExtension/Assets.xcassets/AccentColor.colorset/Contents.json")
        ]
        for accentURL in accentURLs {
            let accentData = try Data(contentsOf: accentURL)
            let accentJson = try XCTUnwrap(try JSONSerialization.jsonObject(with: accentData) as? [String: Any])
            let colors = try XCTUnwrap(accentJson["colors"] as? [[String: Any]])
            let colorEntry = try XCTUnwrap(colors.first?["color"] as? [String: Any])
            let components = try XCTUnwrap(colorEntry["components"] as? [String: String])
            XCTAssertFalse(components.isEmpty, "Missing AccentColor components in \(accentURL.path)")
        }

        let widgetPlistCatalogURL = projectRoot.appendingPathComponent("FoodTrackerWidgetExtension/InfoPlist.xcstrings")
        let widgetData = try Data(contentsOf: widgetPlistCatalogURL)
        let widgetJson = try XCTUnwrap(try JSONSerialization.jsonObject(with: widgetData) as? [String: Any])
        let widgetStrings = try XCTUnwrap(widgetJson["strings"] as? [String: Any])
        let displayName = try XCTUnwrap(widgetStrings["CFBundleDisplayName"] as? [String: Any])
        let widgetLocs = try XCTUnwrap(displayName["localizations"] as? [String: Any])
        for locale in ["en", "ru", "de", "es", "fr", "it", "pt-PT"] {
            let val = (widgetLocs[locale] as? [String: Any])?["stringUnit"].flatMap { ($0 as? [String: Any])?["value"] as? String } ?? ""
            XCTAssertFalse(val.isEmpty, "Missing CFBundleDisplayName localization for \(locale)")
        }
    }

    func testBeforeAfterStorageSavesAndSynchronouslyClears() {
        BeforeAfterStorage.clearAll()
        addTeardownBlock { BeforeAfterStorage.clearAll() }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8))
        let sampleImage = renderer.image { ctx in
            UIColor.systemPink.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }

        BeforeAfterStorage.saveImage(sampleImage, slot: "before")
        XCTAssertNotNil(BeforeAfterStorage.loadImage(slot: "before"))

        BeforeAfterStorage.clearAll()
        XCTAssertNil(BeforeAfterStorage.loadImage(slot: "before"))
        XCTAssertNil(BeforeAfterStorage.loadAnalysis())
    }

    func testPeekPendingWidgetWaterDoesNotClearUntilAcknowledged() {
        let suiteName = "test.widget.peek.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let today = Date()
        let key = WorkoutSyncManager.pendingHealthKitWaterEntriesKey(for: today)
        defaults.set([250.0, 300.0], forKey: key)

        let peeked = WorkoutSyncManager.shared.peekPendingWidgetWaterEntriesLiters(for: today, appGroupDefaults: defaults)
        XCTAssertEqual(peeked.count, 2)
        XCTAssertEqual(peeked[0], 0.25, accuracy: 0.001)
        XCTAssertEqual(peeked[1], 0.30, accuracy: 0.001)
        XCTAssertEqual(defaults.array(forKey: key) as? [Double], [250.0, 300.0])

        WorkoutSyncManager.shared.acknowledgePendingWidgetWaterEntries(syncedCount: 1, for: today, appGroupDefaults: defaults)
        let remaining = WorkoutSyncManager.shared.peekPendingWidgetWaterEntriesLiters(for: today, appGroupDefaults: defaults)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining[0], 0.30, accuracy: 0.001)
    }

    func testRemoveWaterAndReconcilePreservesExternalWorkoutTrackerWater() throws {
        let config = ModelConfiguration(schema: SharedModelContainer.sharedSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: SharedModelContainer.sharedSchema, configurations: [config])
        let context = ModelContext(container)

        let sharedSuite = "test.remove.shared.\(UUID().uuidString)"
        let syncSuite = "test.remove.sync.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: sharedSuite)!
        let syncDefaults = UserDefaults(suiteName: syncSuite)!
        defer {
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
            syncDefaults.removePersistentDomain(forName: syncSuite)
        }

        let today = Date()
        let summary = DailySummary.fetchOrCreate(for: today, in: context)
        let glass = Beverage(date: today, name: "Water", icon: "drop.fill", colorHex: "4CA3E6", caloriesPerGlass: 0, volumeMl: 250)
        context.insert(glass)
        summary.addBeverage(glass)
        try context.save()
        WorkoutSyncManager.shared.syncWater(0.25, for: today, sharedDefaults: sharedDefaults, appGroupDefaults: syncDefaults, localDefaults: syncDefaults)

        // WorkoutTracker logs +0.5 L externally -> shared is now 0.75 L.
        sharedDefaults.set(0.75, forKey: WorkoutSyncManager.waterLitersKey(for: today))

        // User undoes the 250 ml FoodTracker glass -> WorkoutTracker's 0.5 L must survive!
        let _ = WorkoutSyncManager.shared.removeWaterAndReconcile(
            glass,
            from: summary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: syncDefaults,
            localDefaults: syncDefaults
        )

        XCTAssertEqual(summary.totalPureWaterLiters, 0.50, accuracy: 0.01)
        XCTAssertEqual(sharedDefaults.double(forKey: WorkoutSyncManager.waterLitersKey(for: today)), 0.50, accuracy: 0.01)
    }

    func testClearLocalSyncMetadataPreventsReimportOfOldWorkoutWaterAfterWipe() throws {
        let config = ModelConfiguration(schema: SharedModelContainer.sharedSchema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: SharedModelContainer.sharedSchema, configurations: [config])
        let context = ModelContext(container)

        let sharedSuite = "test.wipe.shared.\(UUID().uuidString)"
        let syncSuite = "test.wipe.sync.\(UUID().uuidString)"
        let sharedDefaults = UserDefaults(suiteName: sharedSuite)!
        let syncDefaults = UserDefaults(suiteName: syncSuite)!
        defer {
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
            syncDefaults.removePersistentDomain(forName: syncSuite)
        }

        let today = Date()
        sharedDefaults.set(1.2, forKey: WorkoutSyncManager.waterLitersKey(for: today))

        WorkoutSyncManager.clearLocalSyncMetadata(defaults: syncDefaults, sharedDefaults: sharedDefaults, appGroupDefaults: syncDefaults)

        let freshSummary = DailySummary.fetchOrCreate(for: today, in: context)
        let outcome = WorkoutSyncManager.shared.reconcileWaterWithOutcome(
            for: freshSummary,
            in: context,
            sharedDefaults: sharedDefaults,
            appGroupDefaults: syncDefaults,
            localDefaults: syncDefaults
        )

        XCTAssertFalse(outcome.mutated)
        XCTAssertEqual(freshSummary.totalPureWaterLiters, 0.0, accuracy: 0.001)
    }

    func testStandardWaterGlassMlConsistency() {
        XCTAssertEqual(NutritionMath.standardWaterGlassMl(useMetric: true), 250.0, accuracy: 0.001)
        XCTAssertEqual(NutritionMath.standardWaterGlassMl(useMetric: false), 8.0 * 29.5735, accuracy: 0.001)
    }

    func testHydrationFlaskTicksScaleDynamicallyWithUserGoal() {
        let metricTicks = NutritionMath.hydrationFlaskTicks(goalLiters: 3.5, useMetric: true)
        XCTAssertEqual(metricTicks.map(\.label), ["3.5L", "2.8L", "2.1L", "1.4L", "0.7L"])

        let imperialTicks = NutritionMath.hydrationFlaskTicks(goalLiters: 2.5, useMetric: false)
        XCTAssertEqual(imperialTicks.map(\.label), ["85 oz", "68 oz", "51 oz", "34 oz", "17 oz"])

        let minClampedTicks = NutritionMath.hydrationFlaskTicks(goalLiters: 0.2, useMetric: true)
        XCTAssertEqual(minClampedTicks.first?.label, "0.5L")
    }

    func testEffectiveDailyCalorieGoalIncludesActiveCaloriesBurned() {
        XCTAssertEqual(NutritionMath.effectiveDailyCalorieGoal(baseGoal: 2000, activeCaloriesBurned: 450), 2450)
        XCTAssertEqual(NutritionMath.effectiveDailyCalorieGoal(baseGoal: 2000, activeCaloriesBurned: -50), 2000)
        XCTAssertEqual(NutritionMath.effectiveDailyCalorieGoal(baseGoal: 0, activeCaloriesBurned: 250), 251)

        XCTAssertEqual(AIWeeklyInsightCalculator.dailyCalorieExcess(eaten: 2200, baseGoal: 2000, activeCaloriesBurned: 450), 0)
        XCTAssertEqual(AIWeeklyInsightCalculator.dailyCalorieExcess(eaten: 2600, baseGoal: 2000, activeCaloriesBurned: 450), 150)
    }

    func testFoodSearchConsentPolicyAndMoreTabHealthDestination() {
        XCTAssertFalse(FoodSearchConsentPolicy.shouldOfferAIConsentPrompt(query: "ab", hasConsented: false, hasAnyResults: false, isSearching: false))
        XCTAssertFalse(FoodSearchConsentPolicy.shouldOfferAIConsentPrompt(query: "ramen", hasConsented: true, hasAnyResults: false, isSearching: false))
        XCTAssertFalse(FoodSearchConsentPolicy.shouldOfferAIConsentPrompt(query: "ramen", hasConsented: false, hasAnyResults: true, isSearching: false))
        XCTAssertFalse(FoodSearchConsentPolicy.shouldOfferAIConsentPrompt(query: "ramen", hasConsented: false, hasAnyResults: false, isSearching: true))
        XCTAssertTrue(FoodSearchConsentPolicy.shouldOfferAIConsentPrompt(query: "ramen", hasConsented: false, hasAnyResults: false, isSearching: false))

        XCTAssertEqual(MoreTabHealthLinkTarget.destination(hasUser: true), .appleHealthSettings)
        XCTAssertEqual(MoreTabHealthLinkTarget.destination(hasUser: false), .profileWrapper)
    }
}
