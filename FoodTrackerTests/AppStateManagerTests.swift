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
}
