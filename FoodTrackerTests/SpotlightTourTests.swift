import XCTest
@testable import FoodTracker

final class SpotlightTourTests: XCTestCase {

    func testTabBarProbeMountsOnlyWhileTourActive() {
        XCTAssertFalse(SpotlightTourManager.shouldMeasureTabBar(isTourActive: false))
        XCTAssertTrue(SpotlightTourManager.shouldMeasureTabBar(isTourActive: true))
    }

    func testHomeScrollAnchorLeavesOverlayStepsUnscrolled() {
        XCTAssertNil(SpotlightStep.addMeal.homeScrollAnchorID)
        XCTAssertNil(SpotlightStep.aiChef.homeScrollAnchorID)
        XCTAssertEqual(SpotlightStep.streakFire.homeScrollAnchorID, "header_streak")
        XCTAssertEqual(SpotlightStep.macroRings.homeScrollAnchorID, "macro_rings")
        XCTAssertEqual(SpotlightStep.fastingWater.homeScrollAnchorID, "hydration_card")
    }

    func testGoalSheetRequiresExistingUser() {
        XCTAssertFalse(CoachGoalSheetPolicy.canOpen(hasUser: false))
        XCTAssertTrue(CoachGoalSheetPolicy.canOpen(hasUser: true))
    }
}
