import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class AIPhotoConsentTests: XCTestCase {

    private var suiteName: String!
    private var isolatedDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AIPhotoConsentTests.\(UUID().uuidString)"
        isolatedDefaults = UserDefaults(suiteName: suiteName)!
        isolatedDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        isolatedDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testConsentDefaultsToFalseAndPersistsAcrossInstances() {
        let manager = AIPhotoConsentManager(defaults: isolatedDefaults)
        XCTAssertFalse(manager.hasConsented)

        manager.grantConsent()
        XCTAssertTrue(manager.hasConsented)
        XCTAssertTrue(isolatedDefaults.bool(forKey: AIPhotoConsentManager.defaultsKey))

        let reloaded = AIPhotoConsentManager(defaults: isolatedDefaults)
        XCTAssertTrue(reloaded.hasConsented)
    }

    func testRevokeConsentClearsPersistedFlag() {
        let manager = AIPhotoConsentManager(defaults: isolatedDefaults)
        manager.grantConsent()
        XCTAssertTrue(manager.hasConsented)

        manager.revokeConsent()
        XCTAssertFalse(manager.hasConsented)
        XCTAssertFalse(isolatedDefaults.bool(forKey: AIPhotoConsentManager.defaultsKey))
    }

    func testLocalDataResetServiceClearsConsentKeyAndSyncsManager() throws {
        let schema = SharedModelContainer.sharedSchema
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])

        let manager = AIPhotoConsentManager(defaults: isolatedDefaults)
        manager.grantConsent()
        XCTAssertTrue(isolatedDefaults.bool(forKey: AIPhotoConsentManager.defaultsKey))

        LocalDataResetService.wipeAllData(in: container.mainContext, defaults: isolatedDefaults)
        manager.syncFromDefaults()

        XCTAssertNil(isolatedDefaults.object(forKey: AIPhotoConsentManager.defaultsKey))
        XCTAssertFalse(manager.hasConsented)
    }

    func testMoodAdviceAutoFetchRequiresExplicitAIConsent() {
        XCTAssertFalse(AIMoodAdvicePopup.shouldAutoFetchAIAdvice(hasConsented: false))
        XCTAssertTrue(AIMoodAdvicePopup.shouldAutoFetchAIAdvice(hasConsented: true))
    }

    func testSmartAddFoodViewOffersAIConsentPromptOnlyWhenEmptyAndUnconsented() {
        XCTAssertTrue(
            SmartAddFoodView.shouldOfferAIConsentPrompt(
                query: "matcha",
                hasConsented: false,
                hasAnyResults: false,
                isSearching: false
            )
        )
        XCTAssertFalse(
            SmartAddFoodView.shouldOfferAIConsentPrompt(
                query: "matcha",
                hasConsented: true,
                hasAnyResults: false,
                isSearching: false
            )
        )
        XCTAssertFalse(
            SmartAddFoodView.shouldOfferAIConsentPrompt(
                query: "matcha",
                hasConsented: false,
                hasAnyResults: true,
                isSearching: false
            )
        )
        XCTAssertFalse(
            SmartAddFoodView.shouldOfferAIConsentPrompt(
                query: "matcha",
                hasConsented: false,
                hasAnyResults: false,
                isSearching: true
            )
        )
        XCTAssertFalse(
            SmartAddFoodView.shouldOfferAIConsentPrompt(
                query: "ab",
                hasConsented: false,
                hasAnyResults: false,
                isSearching: false
            )
        )
    }
}
