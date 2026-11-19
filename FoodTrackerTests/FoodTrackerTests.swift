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
            "Height", "Age", "Local database"
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
