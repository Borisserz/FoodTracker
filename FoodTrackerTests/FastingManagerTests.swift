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

    func testFastingCalculationsGuardZeroTargetHoursAndCountdownRange() {
        let invalidRange = FastingActivityTiming.remainingInterval(
            now: Date().addingTimeInterval(60),
            targetEndDate: Date()
        )
        XCTAssertNil(invalidRange)

        let validEnd = Date().addingTimeInterval(3600)
        let validRange = FastingActivityTiming.remainingInterval(
            now: Date(),
            targetEndDate: validEnd
        )
        XCTAssertNotNil(validRange)

        let planZero = makeTestPlan(title: "Broken", fastingHours: 0)
        manager.startFast(plan: planZero)
        XCTAssertFalse(manager.progress.isNaN)
        XCTAssertEqual(manager.progress, 0)
    }

    func testColdStartRestoreReattachesLiveActivityWithCurrentStageAndProgress() {
        let mockLiveActivity = MockFastingLiveActivityManager()
        manager.liveActivityManager = mockLiveActivity
        defer { manager.liveActivityManager = FastingLiveActivityManager.shared }

        let sixHoursAgo = Date().addingTimeInterval(-6 * 3600)
        UserDefaults.standard.set(true, forKey: "isFasting")
        UserDefaults.standard.set("16:8", forKey: "fastingPlanName")
        UserDefaults.standard.set(16, forKey: "fastingTargetHours")
        UserDefaults.standard.set(sixHoursAgo.timeIntervalSince1970, forKey: "fastingStartTime")

        manager.restorePersistedState()

        XCTAssertTrue(manager.isFasting)
        XCTAssertEqual(mockLiveActivity.startedCalls.count, 0)
        XCTAssertEqual(mockLiveActivity.reattachedCalls.count, 1)
        XCTAssertEqual(mockLiveActivity.reattachedCalls.first?.currentStage, "Digestion Mode")
        XCTAssertEqual(mockLiveActivity.reattachedCalls.first?.progressPct ?? 0, 6.0 / 16.0, accuracy: 0.02)
    }

    func testFastingTimerLoopContinuesInOvertimeWhenStillFasting() {
        XCTAssertTrue(FastingManager.shouldContinueTimerLoop(isFasting: true, targetHours: 16, progress: 0.5))
        XCTAssertTrue(FastingManager.shouldContinueTimerLoop(isFasting: true, targetHours: 16, progress: 1.0))
        XCTAssertFalse(FastingManager.shouldContinueTimerLoop(isFasting: false, targetHours: 16, progress: 0.5))
        XCTAssertFalse(FastingManager.shouldContinueTimerLoop(isFasting: true, targetHours: 0, progress: 0.5))
    }

    func testFastingActivityTimingCompletionAndBackwardCompatibleDecoding() throws {
        let now = Date()
        XCTAssertFalse(FastingActivityTiming.isCompleted(now: now, targetEndDate: now.addingTimeInterval(60), progressPct: 0.9))
        XCTAssertTrue(FastingActivityTiming.isCompleted(now: now, targetEndDate: now.addingTimeInterval(-1), progressPct: 0.99))
        XCTAssertTrue(FastingActivityTiming.isCompleted(now: now, targetEndDate: now.addingTimeInterval(60), progressPct: 1.0))

        // Legacy ContentState payload without `isCompleted` should decode cleanly as `false`.
        let legacyJSON = Data("{\"currentStage\":\"Ketosis State\",\"progressPct\":0.8}".utf8)
        let decoded = try JSONDecoder().decode(FastingAttributes.ContentState.self, from: legacyJSON)
        XCTAssertEqual(decoded.currentStage, "Ketosis State")
        XCTAssertEqual(decoded.progressPct, 0.8, accuracy: 0.001)
        XCTAssertFalse(decoded.isCompleted)
    }

    func testFastingLiveActivityUpdateDecisionDispatchesWhenCompletionFlipsAtProgressOne() {
        XCTAssertFalse(
            FastingLiveActivityUpdateDecision.shouldDispatch(
                currentStage: "Deep Autophagy",
                progressPct: 1.0,
                isCompleted: true,
                lastSentStage: "Deep Autophagy",
                lastSentProgress: 1.0,
                lastSentCompleted: true
            )
        )
        XCTAssertTrue(
            FastingLiveActivityUpdateDecision.shouldDispatch(
                currentStage: "Deep Autophagy",
                progressPct: 1.0,
                isCompleted: true,
                lastSentStage: "Deep Autophagy",
                lastSentProgress: 1.0,
                lastSentCompleted: false
            )
        )
    }

    func testNotificationGenerationGuardRejectsStaleAuthorizationCallbacks() {
        XCTAssertTrue(FastingManager.shouldApplyScheduledNotifications(capturedGeneration: 3, currentGeneration: 3, isFasting: true))
        XCTAssertFalse(FastingManager.shouldApplyScheduledNotifications(capturedGeneration: 2, currentGeneration: 3, isFasting: true))
        XCTAssertFalse(FastingManager.shouldApplyScheduledNotifications(capturedGeneration: 3, currentGeneration: 3, isFasting: false))
    }
}

@MainActor
private final class MockFastingLiveActivityManager: FastingLiveActivityManaging {
    struct StartCall {
        let planName: String
        let targetHours: Int
        let startTime: Date
    }
    struct ReattachCall {
        let planName: String
        let targetHours: Int
        let startTime: Date
        let currentStage: String
        let progressPct: Double
    }
    struct UpdateCall {
        let currentStage: String
        let progressPct: Double
    }

    var startedCalls: [StartCall] = []
    var reattachedCalls: [ReattachCall] = []
    var updatedCalls: [UpdateCall] = []
    var endCallCount: Int = 0

    func startActivity(planName: String, targetHours: Int, startTime: Date) {
        startedCalls.append(StartCall(planName: planName, targetHours: targetHours, startTime: startTime))
    }

    func reattachActivity(
        planName: String,
        targetHours: Int,
        startTime: Date,
        currentStage: String,
        progressPct: Double
    ) {
        reattachedCalls.append(
            ReattachCall(
                planName: planName,
                targetHours: targetHours,
                startTime: startTime,
                currentStage: currentStage,
                progressPct: progressPct
            )
        )
    }

    func updateActivity(currentStage: String, progressPct: Double) {
        updatedCalls.append(UpdateCall(currentStage: currentStage, progressPct: progressPct))
    }

    func endActivity() {
        endCallCount += 1
    }
}
