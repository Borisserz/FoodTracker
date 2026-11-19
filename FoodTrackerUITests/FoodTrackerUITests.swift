import XCTest

final class FoodTrackerUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGuestOnboardingFlowEnforcesProtocolGateAndReachesMainTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingResetOnboarding", "-uiTestingDisableSpotlight"]
        app.launch()

        let guestButton = app.buttons["onboarding_guest_button"]
        XCTAssertTrue(guestButton.waitForExistence(timeout: 10.0), "Expected guest entry button on welcome screen")
        guestButton.tap()

        let stayGuestButton = app.buttons["onboarding_stay_guest_button"]
        XCTAssertTrue(stayGuestButton.waitForExistence(timeout: 5.0), "Expected stay guest confirmation button")
        stayGuestButton.tap()

        let stage0Next = app.buttons["onboarding_stage0_next"]
        XCTAssertTrue(stage0Next.waitForExistence(timeout: 5.0))
        stage0Next.tap()

        let stage1Next = app.buttons["onboarding_stage1_next"]
        XCTAssertTrue(stage1Next.waitForExistence(timeout: 5.0))
        stage1Next.tap()

        let stage2Next = app.buttons["onboarding_stage2_next"]
        XCTAssertTrue(stage2Next.waitForExistence(timeout: 5.0))
        XCTAssertFalse(stage2Next.isEnabled, "Lock Protocol CTA must stay disabled until an activity level is picked")

        app.swipeUp()
        let activeOption = app.buttons["onboarding_activity_active"]
        XCTAssertTrue(activeOption.waitForExistence(timeout: 5.0))
        if !activeOption.isHittable {
            app.swipeUp()
        }
        activeOption.tap()

        let stage2EnabledExpectation = NSPredicate(format: "enabled == true")
        expectation(for: stage2EnabledExpectation, evaluatedWith: stage2Next)
        waitForExpectations(timeout: 5.0)
        if !stage2Next.isHittable {
            app.swipeUp()
        }
        stage2Next.tap()

        let stage3Next = app.buttons["onboarding_stage3_next"]
        XCTAssertTrue(stage3Next.waitForExistence(timeout: 5.0))
        stage3Next.tap()

        let stage4Finish = app.buttons["onboarding_stage4_finish"]
        XCTAssertTrue(stage4Finish.waitForExistence(timeout: 5.0))
        let enabledExpectation = NSPredicate(format: "enabled == true")
        expectation(for: enabledExpectation, evaluatedWith: stage4Finish)
        waitForExpectations(timeout: 8.0)
        stage4Finish.tap()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 8.0))
        XCTAssertEqual(tabBar.buttons.count, 5)
    }

    func testMainTabNavigationSwitchesBetweenAllFiveTabs() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingSkipOnboarding", "-uiTestingDisableSpotlight"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10.0), "Main tab bar should appear when onboarding is skipped")
        XCTAssertEqual(tabBar.buttons.count, 5)

        for index in 0..<5 {
            let tabButton = tabBar.buttons.element(boundBy: index)
            XCTAssertTrue(tabButton.exists, "Expected tab button at index \(index)")
            tabButton.tap()
            XCTAssertTrue(tabButton.isSelected, "Expected tab at index \(index) to become selected")
        }
    }
}
