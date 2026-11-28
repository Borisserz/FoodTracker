import XCTest
@testable import FoodTracker

@MainActor
final class VersionManagerTests: XCTestCase {

    private final class MockVersionConfigProvider: VersionConfigProviding, @unchecked Sendable {
        var values: [String: String]

        init(values: [String: String]) {
            self.values = values
        }

        func stringValue(forKey key: String) async -> String {
            values[key] ?? ""
        }
    }

    func testSemanticVersionComparisonHandlesVaryingLengthsAndMultiDigitVersions() {
        XCTAssertTrue(VersionManager.isVersion("1.0.9", lessThan: "1.0.10"))
        XCTAssertTrue(VersionManager.isVersion("1.2", lessThan: "1.2.1"))
        XCTAssertFalse(VersionManager.isVersion("1.2.0", lessThan: "1.2"))
        XCTAssertFalse(VersionManager.isVersion("2.0.0", lessThan: "1.9.9"))
        XCTAssertFalse(VersionManager.isVersion("1.10.0", lessThan: "1.9.9"))
    }

    func testEvaluateRequirementPrioritizesHardUpdateOverSoftUpdate() {
        XCTAssertEqual(
            VersionManager.evaluateRequirement(current: "1.0.0", minimum: "1.1.0", recommended: "1.2.0"),
            .hardUpdate
        )
        XCTAssertEqual(
            VersionManager.evaluateRequirement(current: "1.1.5", minimum: "1.1.0", recommended: "1.2.0"),
            .softUpdate
        )
        XCTAssertEqual(
            VersionManager.evaluateRequirement(current: "1.2.0", minimum: "1.1.0", recommended: "1.2.0"),
            .noUpdate
        )
        XCTAssertEqual(
            VersionManager.evaluateRequirement(current: "1.0.0", minimum: "", recommended: ""),
            .noUpdate
        )
    }

    func testCheckVersionUpdatesRequirementFromInjectedConfigProvider() async {
        let manager = VersionManager.shared
        let originalRequirement = manager.updateRequirement
        defer { manager.updateRequirement = originalRequirement }

        let softProvider = MockVersionConfigProvider(values: [
            "food_minimum_ios_version": "1.0.0",
            "food_recommended_ios_version": "99.0.0"
        ])
        await manager.checkVersion(configProvider: softProvider, currentVersion: "1.5.0")
        XCTAssertEqual(manager.updateRequirement, .softUpdate)

        let hardProvider = MockVersionConfigProvider(values: [
            "food_minimum_ios_version": "2.0.0",
            "food_recommended_ios_version": "3.0.0"
        ])
        await manager.checkVersion(configProvider: hardProvider, currentVersion: "1.5.0")
        XCTAssertEqual(manager.updateRequirement, .hardUpdate)

        let okProvider = MockVersionConfigProvider(values: [
            "food_minimum_ios_version": "1.0.0",
            "food_recommended_ios_version": "1.5.0"
        ])
        await manager.checkVersion(configProvider: okProvider, currentVersion: "1.5.0")
        XCTAssertEqual(manager.updateRequirement, .noUpdate)
    }

    func testMalformedOrEmptyVersionsFailOpenAndWhitespacePaddedVersionsParse() {
        let malformedInputs = ["v2.0.0", "2.0.0-beta", "bad", " ", "", "1..2", "1. 2.0"]
        for malformed in malformedInputs {
            XCTAssertFalse(
                VersionManager.isVersion("1.0.0", lessThan: malformed),
                "Expected malformed remote version '\(malformed)' to fail-open"
            )
            XCTAssertFalse(
                VersionManager.isVersion(malformed, lessThan: "2.0.0"),
                "Expected malformed current version '\(malformed)' to fail-open"
            )
            XCTAssertEqual(
                VersionManager.evaluateRequirement(current: "1.0.0", minimum: malformed, recommended: malformed),
                .noUpdate,
                "Expected malformed remote versions '\(malformed)' to evaluate to .noUpdate"
            )
            XCTAssertEqual(
                VersionManager.evaluateRequirement(current: malformed, minimum: "2.0.0", recommended: "3.0.0"),
                .noUpdate,
                "Expected malformed current version '\(malformed)' to evaluate to .noUpdate"
            )
        }

        XCTAssertTrue(VersionManager.isVersion(" 1.2.0 ", lessThan: " 1.3.0\n"))
        XCTAssertFalse(VersionManager.isVersion(" 1.2.0 ", lessThan: "1.2.0"))
        XCTAssertEqual(
            VersionManager.evaluateRequirement(current: " 1.2.0 ", minimum: "1.1.0", recommended: " 1.5.0 "),
            .softUpdate
        )
    }
}
