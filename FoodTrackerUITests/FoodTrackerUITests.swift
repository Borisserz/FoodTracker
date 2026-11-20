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

    func testQuickHydrationAddUpdatesFlaskOnHome() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingSkipOnboarding", "-uiTestingDisableSpotlight"]
        app.launch()

        let add250 = app.buttons["hydration_add_250ml_button"]
        if !add250.waitForExistence(timeout: 8.0) {
            app.swipeUp()
        }
        XCTAssertTrue(add250.waitForExistence(timeout: 5.0), "Expected +250ml hydration button")
        let volumeLabel = app.staticTexts["hydration_current_volume_label"]
        XCTAssertTrue(volumeLabel.waitForExistence(timeout: 5.0))
        let initialValue = Double(volumeLabel.label.replacingOccurrences(of: ",", with: ".")) ?? -1

        if !add250.isHittable {
            app.swipeUp()
        }
        add250.tap()

        let updatedPredicate = NSPredicate { _, _ in
            let current = Double(volumeLabel.label.replacingOccurrences(of: ",", with: ".")) ?? -1
            return current > initialValue + 0.1
        }
        expectation(for: updatedPredicate, evaluatedWith: volumeLabel)
        waitForExpectations(timeout: 5.0)
    }

    func testQuickAddMealFlowSavesFoodItemToDiary() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingSkipOnboarding", "-uiTestingDisableSpotlight"]
        app.launch()

        let fab = app.buttons["home_quick_add_fab"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10.0))
        fab.tap()

        let logMealButton = app.buttons["speed_dial_log_meal"]
        XCTAssertTrue(logMealButton.waitForExistence(timeout: 5.0))
        logMealButton.tap()

        let addFoodButton = app.buttons["add_meal_add_food_button"]
        if addFoodButton.waitForExistence(timeout: 3.0) {
            if !addFoodButton.isHittable { app.swipeUp() }
            addFoodButton.tap()
        } else {
            let addAnother = app.buttons["add_meal_add_another_button"]
            for _ in 0..<3 where !addAnother.waitForExistence(timeout: 1.5) {
                app.swipeUp()
            }
            XCTAssertTrue(addAnother.waitForExistence(timeout: 5.0))
            if !addAnother.isHittable { app.swipeUp() }
            addAnother.tap()
        }

        let firstRow = app.buttons["smart_add_food_row_0"]
        XCTAssertTrue(firstRow.waitForExistence(timeout: 8.0))
        firstRow.tap()

        let confirmFood = app.buttons["food_detail_confirm_button"]
        XCTAssertTrue(confirmFood.waitForExistence(timeout: 5.0))
        confirmFood.tap()

        let cartConfirm = app.buttons["smart_add_confirm_cart_button"]
        XCTAssertTrue(cartConfirm.waitForExistence(timeout: 5.0))
        cartConfirm.tap()

        let saveMeal = app.buttons["add_meal_save_button"]
        XCTAssertTrue(saveMeal.waitForExistence(timeout: 5.0))
        XCTAssertTrue(saveMeal.isEnabled)
        saveMeal.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 8.0))
    }

    func testSmartScannerOpensFromQuickAddAndDismissesSafely() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingSkipOnboarding", "-uiTestingDisableSpotlight"]
        app.launch()

        let fab = app.buttons["home_quick_add_fab"]
        XCTAssertTrue(fab.waitForExistence(timeout: 10.0))
        fab.tap()

        let scanButton = app.buttons["speed_dial_scan_barcode"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 5.0))
        scanButton.tap()

        let closeButton = app.buttons["scanner_close_button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 8.0))
        closeButton.tap()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5.0))
    }

    func testMoreTabProfileDeleteConfirmationCanBeCancelledSafely() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingSkipOnboarding", "-uiTestingDisableSpotlight"]
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10.0))
        tabBar.buttons.element(boundBy: 4).tap()

        let profileCard = app.buttons["more_profile_card"]
        if !profileCard.waitForExistence(timeout: 5.0) {
            app.swipeUp()
        }
        XCTAssertTrue(profileCard.waitForExistence(timeout: 5.0))
        profileCard.tap()

        let settingsButton = app.buttons["profile_settings_button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5.0))
        settingsButton.tap()

        let accountRow = app.buttons["settings_account_row"]
        XCTAssertTrue(accountRow.waitForExistence(timeout: 5.0))
        accountRow.tap()

        let deleteButton = app.buttons["profile_delete_account_button"]
        for _ in 0..<4 where !deleteButton.exists || !deleteButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5.0))
        deleteButton.tap()

        let destructiveButton = app.buttons["Delete Account"]
        XCTAssertTrue(destructiveButton.waitForExistence(timeout: 5.0))
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 2.0) {
            cancelButton.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.15)).tap()
        }

        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5.0))
    }
}
