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

    private func makeTestPlan(title: String = "16:8", fastingHours: Int = 16) -> FastingPlan {
        FastingPlan(
            category: .intermediate,
            title: title,
            description: "Test",
            icon: "timer",
            colorHex: "FF9500",
            isPopular: false,
            fastingHours: fastingHours,
            eatingHours: 24 - fastingHours,
            difficultyRating: 3,
            benefits: [],
            breakFastTip: "Water"
        )
    }

    func testStartFast() {
        let plan = makeTestPlan()
        manager.startFast(plan: plan)
        
        XCTAssertTrue(manager.isFasting)
        XCTAssertEqual(manager.targetHours, 16)
        XCTAssertEqual(manager.planName, "16:8")
        XCTAssertNotNil(manager.startTime)
    }

    func testEndFast() {
        let plan = makeTestPlan()
        manager.startFast(plan: plan)
        XCTAssertTrue(manager.isFasting)
        
        manager.endFast()
        XCTAssertFalse(manager.isFasting)
        XCTAssertNil(manager.startTime)
        XCTAssertEqual(manager.elapsedTime, 0)
        XCTAssertEqual(manager.progress, 0)
    }

    func testCurrentPhase() {
        let plan = makeTestPlan()
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
        let plan = makeTestPlan()
        manager.startFast(plan: plan)
        
        manager.elapsedTime = 15 * 3600 + 30 * 60 // 15h 30m
        // Target is 16h, so remaining is 30m
        XCTAssertEqual(manager.remainingTimeString, "0h 30m left")
        
        manager.elapsedTime = 16 * 3600 // 16h
        XCTAssertEqual(manager.remainingTimeString, "Goal Reached! 🎉")
    }

    func testFastingLifecycleNotifiesLiveActivityManager() {
        let mockLiveActivity = MockFastingLiveActivityManager()
        manager.liveActivityManager = mockLiveActivity
        defer { manager.liveActivityManager = FastingLiveActivityManager.shared }

        let plan = makeTestPlan(title: "18:6", fastingHours: 18)
        manager.startFast(plan: plan)

        XCTAssertEqual(mockLiveActivity.startedCalls.count, 1)
        XCTAssertEqual(mockLiveActivity.startedCalls.first?.planName, "18:6")
        XCTAssertEqual(mockLiveActivity.startedCalls.first?.targetHours, 18)
        XCTAssertGreaterThanOrEqual(mockLiveActivity.updatedCalls.count, 1)

        manager.endFast()
        XCTAssertEqual(mockLiveActivity.endCallCount, 1)
    }
}

@MainActor
private final class MockFastingLiveActivityManager: FastingLiveActivityManaging {
    struct StartCall {
        let planName: String
        let targetHours: Int
        let startTime: Date
    }
    struct UpdateCall {
        let currentStage: String
        let progressPct: Double
    }

    var startedCalls: [StartCall] = []
    var updatedCalls: [UpdateCall] = []
    var endCallCount: Int = 0

    func startActivity(planName: String, targetHours: Int, startTime: Date) {
        startedCalls.append(StartCall(planName: planName, targetHours: targetHours, startTime: startTime))
    }

    func updateActivity(currentStage: String, progressPct: Double) {
        updatedCalls.append(UpdateCall(currentStage: currentStage, progressPct: progressPct))
    }

    func endActivity() {
        endCallCount += 1
    }
}
