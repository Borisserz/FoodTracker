import XCTest
@testable import FoodTracker

final class AppStateManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        UserDefaults.standard.removeObject(forKey: "isPremiumActivated")
    }

    func testInitialState() {
        let state = AppStateManager()
        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertTrue(state.isPremiumActivated)
        XCTAssertEqual(state.selectedTab, 0)
    }

    func testCompleteOnboarding() {
        let state = AppStateManager()
        state.completeOnboarding()
        
        XCTAssertTrue(state.hasCompletedOnboarding)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }
    
    func testActivatePremium() {
        let state = AppStateManager()
        state.activatePremium()
        
        XCTAssertTrue(state.isPremiumActivated)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "isPremiumActivated"))
    }
    
    func testLoadFromUserDefaults() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        let state = AppStateManager()
        XCTAssertTrue(state.hasCompletedOnboarding)
    }

    func testHandleWidgetDeepLinks() {
        let state = AppStateManager()

        XCTAssertTrue(state.handleWidgetURL(URL(string: "foodtracker://metabolic")!))
        XCTAssertEqual(state.selectedTab, 3)
        XCTAssertEqual(state.requestedWidgetAction, "metabolic")

        XCTAssertTrue(state.handleWidgetURL(URL(string: "foodtracker://hydration")!))
        XCTAssertEqual(state.selectedTab, 0)
        XCTAssertEqual(state.requestedWidgetAction, "hydration")

        XCTAssertTrue(state.handleWidgetURL(URL(string: "foodtracker://shopping")!))
        XCTAssertEqual(state.requestedWidgetAction, "shopping")

        XCTAssertTrue(state.handleWidgetURL(URL(string: "foodtracker://fasting")!))
        XCTAssertEqual(state.requestedWidgetAction, "fasting")

        XCTAssertFalse(state.handleWidgetURL(URL(string: "https://example.com/other")!))
    }
}
