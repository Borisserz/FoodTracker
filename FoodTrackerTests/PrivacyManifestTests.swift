import XCTest
@testable import FoodTracker

final class PrivacyManifestTests: XCTestCase {

    func testPrivacyManifestUsesValidPhotosAndFitnessKeys() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let collected = try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let types = collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }

        XCTAssertTrue(types.contains("NSPrivacyCollectedDataTypePhotosOrVideos"))
        XCTAssertFalse(types.contains("NSPrivacyCollectedDataTypePhotosorVideos"))
        XCTAssertTrue(types.contains("NSPrivacyCollectedDataTypeFitness"))
        XCTAssertTrue(types.contains("NSPrivacyCollectedDataTypeDeviceID"))
    }

    func testPrivacyManifestDeclaresFileTimestampRequiredReasonAPI() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let apiTypes = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let fileTimestampEntry = apiTypes.first { ($0["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategoryFileTimestamp" }
        let reasons = fileTimestampEntry?["NSPrivacyAccessedAPITypeReasons"] as? [String] ?? []
        XCTAssertTrue(reasons.contains("C617.1"))
    }

    func testInfoPlistDoesNotDeclareUnusedRemoteNotificationBackgroundMode() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        XCTAssertFalse(modes.contains("remote-notification"))
    }

    func testLegalURLsEncodeValidFilenames() {
        XCTAssertEqual(
            Constants.Legal.supportURL.absoluteString,
            "https://borisserz.github.io/workouttracker-privacy/Support%20-%20FoodTracker.html"
        )
        XCTAssertEqual(
            Constants.Legal.privacyPolicyURL.absoluteString,
            "https://borisserz.github.io/workouttracker-privacy/Privacy%20Policy%20-%20FoodTracker.html"
        )
        XCTAssertEqual(
            Constants.Legal.eulaURL.absoluteString,
            "https://borisserz.github.io/workouttracker-privacy/Terms%20of%20Use%20-%20FoodTracker.html"
        )
    }

    func testPrivacyManifestDoesNotDeclareUnusedPerformanceData() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let collected = try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let types = collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        XCTAssertFalse(types.contains("NSPrivacyCollectedDataTypePerformanceData"))
    }
}
