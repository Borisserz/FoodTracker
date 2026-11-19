import XCTest
import SwiftData
import HealthKit
@testable import FoodTracker

@MainActor
final class AuthManagerTests: XCTestCase {
    func testDeleteCurrentUserThrowsNotSignedInWhenProviderReturnsNil() async {
        let manager = AuthManager()
        do {
            try await manager.deleteCurrentUser(userProvider: { nil })
            XCTFail("Expected AccountDeletionError.notSignedIn")
        } catch let error as AccountDeletionError {
            if case .notSignedIn = error {
                // expected
            } else {
                XCTFail("Unexpected AccountDeletionError case: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testRunDeletionSequenceExecutesReauthDeleteThenRevokeInOrder() async throws {
        var events: [String] = []
        try await AuthManager.runDeletionSequence(
            reauthenticate: {
                events.append("reauth")
                return "apple_code_123"
            },
            deleteAccount: {
                events.append("delete")
            },
            revokeAppleToken: { code in
                events.append("revoke:\(code)")
            }
        )
        XCTAssertEqual(events, ["reauth", "delete", "revoke:apple_code_123"])
    }

    func testRunDeletionSequenceDoesNotRevokeAppleTokenWhenDeletionFails() async {
        var revokeCalled = false
        do {
            try await AuthManager.runDeletionSequence(
                reauthenticate: { "apple_code_123" },
                deleteAccount: { throw AccountDeletionError.serverCleanupFailed(statusCode: 503) },
                revokeAppleToken: { _ in revokeCalled = true }
            )
            XCTFail("Expected serverCleanupFailed to propagate")
        } catch {
            XCTAssertFalse(revokeCalled, "Apple token must NOT be revoked when server deletion fails")
        }
    }

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
