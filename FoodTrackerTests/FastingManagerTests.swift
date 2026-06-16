import XCTest
@testable import FoodTracker

@MainActor
final class FastingManagerTests: XCTestCase {
    var manager: FastingManager!

    override func setUpWithError() throws {
        // Clear UserDefaults before testing
        UserDefaults.standard.removeObject(forKey: "isFasting")
        UserDefaults.standard.removeObject(forKey: "fastingPlanName")
        UserDefaults.standard.removeObject(forKey: "fastingTargetHours")
        UserDefaults.standard.removeObject(forKey: "fastingStartTime")
        
        manager = FastingManager.shared
        // Reset state
        manager.endFast()
    }

    override func tearDownWithError() throws {
        manager.endFast()
        manager = nil
    }

    func testStartFast() {
        let plan = FastingPlan(title: "16:8", fastingHours: 16, info: "Test", icon: "timer")
        manager.startFast(plan: plan)
        
        XCTAssertTrue(manager.isFasting)
        XCTAssertEqual(manager.targetHours, 16)
        XCTAssertEqual(manager.planName, "16:8")
        XCTAssertNotNil(manager.startTime)
    }

    func testEndFast() {
        let plan = FastingPlan(title: "16:8", fastingHours: 16, info: "Test", icon: "timer")
        manager.startFast(plan: plan)
        XCTAssertTrue(manager.isFasting)
        
        manager.endFast()
        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.startTime)
        XCTAssertEqual(manager.elapsedTime, 0)
        XCTAssertEqual(manager.progress, 0)
    }

    func testCurrentPhase() {
        let plan = FastingPlan(title: "16:8", fastingHours: 16, info: "Test", icon: "timer")
        manager.startFast(plan: plan)
        
        // Simulate elapsed time
        manager.elapsedTime = 2 * 3600 // 2 hours
        XCTAssertEqual(manager.currentPhase.name, "Blood Sugar Normalizing")
        
        manager.elapsedTime = 6 * 3600 // 6 hours
        XCTAssertEqual(manager.currentPhase.name, "Digestion Mode")
        
        manager.elapsedTime = 10 * 3600 // 10 hours
        XCTAssertEqual(manager.currentPhase.name, "Fat Burning Begins")
        
        manager.elapsedTime = 14 * 3600 // 14 hours
        XCTAssertEqual(manager.currentPhase.name, "Ketosis State")
        
        manager.elapsedTime = 18 * 3600 // 18 hours
        XCTAssertEqual(manager.currentPhase.name, "Deep Autophagy")
    }

    func testRemainingTimeString() {
        let plan = FastingPlan(title: "16:8", fastingHours: 16, info: "Test", icon: "timer")
        manager.startFast(plan: plan)
        
        manager.elapsedTime = 15 * 3600 + 30 * 60 // 15h 30m
        // Target is 16h, so remaining is 30m
        XCTAssertEqual(manager.remainingTimeString, "0h 30m left")
        
        manager.elapsedTime = 16 * 3600 // 16h
        XCTAssertEqual(manager.remainingTimeString, "Goal Reached! 🎉")
    }
}
