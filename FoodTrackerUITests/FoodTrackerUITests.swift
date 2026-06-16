import XCTest

final class FoodTrackerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        // At minimum, we should verify the app launched without crashing
        // and we see some UI element. For instance, the TabBar if logged in,
        // or a Login/Onboarding screen if not.
        
        // Wait for the app to load
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5.0))
        
        // Check for tab bar which is usually present
        // let tabBar = app.tabBars.firstMatch
        // if tabBar.exists {
        //     XCTAssertTrue(tabBar.buttons["Home"].exists || tabBar.buttons.count > 0)
        // }
    }
}
