import Foundation
import ActivityKit

enum FastingLiveActivityUpdateDecision {
    static func shouldDispatch(
        currentStage: String,
        progressPct: Double,
        isCompleted: Bool,
        lastSentStage: String?,
        lastSentProgress: Double,
        lastSentCompleted: Bool
    ) -> Bool {
        if isCompleted != lastSentCompleted { return true }
        if currentStage != lastSentStage { return true }
        return abs(progressPct - lastSentProgress) >= 0.01
    }
}

@MainActor
protocol FastingLiveActivityManaging: AnyObject {
    func startActivity(planName: String, targetHours: Int, startTime: Date)
    func reattachActivity(planName: String, targetHours: Int, startTime: Date, currentStage: String, progressPct: Double)
    func updateActivity(currentStage: String, progressPct: Double)
    func endActivity()
    func endActivity(completed: Bool)
}

extension FastingLiveActivityManaging {
    func endActivity(completed: Bool) {
        endActivity()
    }
}

@Observable
final class FastingLiveActivityManager: FastingLiveActivityManaging {
    static let shared = FastingLiveActivityManager()

    @ObservationIgnored private var currentActivity: Activity<FastingAttributes>?
    @ObservationIgnored private var lastSentStage: String?
    @ObservationIgnored private var lastSentProgress: Double = -1.0
    @ObservationIgnored private var lastSentCompleted: Bool = false
    @ObservationIgnored private var requestGeneration: UInt64 = 0
    @ObservationIgnored private var pendingStartTask: Task<Void, Never>?
    @ObservationIgnored private var pendingOperationTask: Task<Void, Never>?

    private func enqueueOperation(_ work: @escaping @MainActor () async -> Void) {
        let prior = pendingOperationTask
        pendingOperationTask = Task { @MainActor in
            _ = await prior?.value
            await work()
        }
    }

    private init() {
        currentActivity = Activity<FastingAttributes>.activities.first(where: { $0.activityState == .active })
    }

    private func activeActivity() -> Activity<FastingAttributes>? {
        if let current = currentActivity,
           Activity<FastingAttributes>.activities.contains(where: { $0.id == current.id && $0.activityState == .active }) {
            return current
        }
        let rehydrated = Activity<FastingAttributes>.activities.first(where: { $0.activityState == .active })
        currentActivity = rehydrated
        return rehydrated
    }

    func startActivity(planName: String, targetHours: Int, startTime: Date) {
        requestNewActivity(
            planName: planName,
            targetHours: targetHours,
            startTime: startTime,
            initialStage: "Blood Sugar Normalizing",
            initialProgress: 0.0
        )
    }

    /// Reattaches to an already-running ActivityKit session across cold launches so progress/stage don't reset to zero.
    func reattachActivity(
        planName: String,
        targetHours: Int,
        startTime: Date,
        currentStage: String,
        progressPct: Double
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, targetHours > 0 else { return }
        let targetEndDate = startTime.addingTimeInterval(TimeInterval(targetHours * 3600))

        if let existing = activeActivity(),
           existing.attributes.planName == planName,
           abs(existing.attributes.targetEndDate.timeIntervalSince(targetEndDate)) < 60,
           existing.attributes.startDate != nil {
            currentActivity = existing
            lastSentStage = nil
            lastSentProgress = -1.0
            lastSentCompleted = false
            updateActivity(currentStage: currentStage, progressPct: progressPct)
            return
        }

        requestNewActivity(
            planName: planName,
            targetHours: targetHours,
            startTime: startTime,
            initialStage: currentStage,
            initialProgress: progressPct
        )
    }

    private func requestNewActivity(
        planName: String,
        targetHours: Int,
        startTime: Date,
        initialStage: String,
        initialProgress: Double
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled, targetHours > 0 else { return }

        let now = Date()
        let targetEndDate = startTime.addingTimeInterval(TimeInterval(targetHours * 3600))
        let attributes = FastingAttributes(
            planName: planName,
            targetEndDate: targetEndDate,
            startDate: startTime
        )
        let clampedProgress = min(max(initialProgress, 0.0), 1.0)
        let completed = FastingActivityTiming.isCompleted(now: now, targetEndDate: targetEndDate, progressPct: clampedProgress)
        let initialContentState = FastingAttributes.ContentState(
            currentStage: initialStage,
            progressPct: clampedProgress,
            isCompleted: completed
        )
        let staleDate = completed ? now.addingTimeInterval(3600) : targetEndDate
        let content = ActivityContent(
            state: initialContentState,
            staleDate: staleDate,
            relevanceScore: 100
        )

        // Ensure stale activities finish ending BEFORE requesting the new Live Activity so IDs don't race.
        pendingStartTask?.cancel()
        requestGeneration &+= 1
        let capturedGeneration = requestGeneration
        let existingActivities = Activity<FastingAttributes>.activities

        pendingStartTask = Task { @MainActor [weak self] in
            for existing in existingActivities {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            guard let self, !Task.isCancelled, self.requestGeneration == capturedGeneration else { return }
            do {
                self.currentActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                self.lastSentStage = initialStage
                self.lastSentProgress = clampedProgress
                self.lastSentCompleted = completed
                self.pendingStartTask = nil
                #if DEBUG
                print("Live Activity started successfully: \(self.currentActivity?.id ?? "")")
                #endif
            } catch {
                self.pendingStartTask = nil
                #if DEBUG
                print("Failed to start Live Activity: \(error.localizedDescription)")
                #endif
            }
        }
    }

    func updateActivity(currentStage: String, progressPct: Double) {
        guard pendingStartTask == nil, let activity = activeActivity() else { return }
        let now = Date()
        let targetEnd = activity.attributes.targetEndDate
        let isCompleted = FastingActivityTiming.isCompleted(now: now, targetEndDate: targetEnd, progressPct: progressPct)

        guard FastingLiveActivityUpdateDecision.shouldDispatch(
            currentStage: currentStage,
            progressPct: progressPct,
            isCompleted: isCompleted,
            lastSentStage: lastSentStage,
            lastSentProgress: lastSentProgress,
            lastSentCompleted: lastSentCompleted
        ) else {
            return
        }

        lastSentStage = currentStage
        lastSentProgress = progressPct
        lastSentCompleted = isCompleted

        let updatedState = FastingAttributes.ContentState(
            currentStage: currentStage,
            progressPct: progressPct,
            isCompleted: isCompleted
        )

        let staleDate = isCompleted ? now.addingTimeInterval(3600) : targetEnd
        let updatedContent = ActivityContent(
            state: updatedState,
            staleDate: staleDate,
            relevanceScore: 100
        )

        enqueueOperation {
            await activity.update(updatedContent)
        }
    }

    func endActivity() {
        endActivity(completed: true)
    }

    func endActivity(completed: Bool) {
        requestGeneration &+= 1
        pendingStartTask?.cancel()
        pendingStartTask = nil

        let capturedGeneration = requestGeneration
        let fallbackCurrent = currentActivity

        let finalState = FastingAttributes.ContentState(
            currentStage: completed ? "Completed" : "Ended",
            progressPct: completed ? 1.0 : 0.0,
            isCompleted: true
        )

        let finalContent = ActivityContent(
            state: finalState,
            staleDate: nil,
            relevanceScore: 0
        )
        let dismissalPolicy: ActivityUIDismissalPolicy = completed ? .default : .immediate

        currentActivity = nil
        lastSentStage = nil
        lastSentProgress = -1.0
        lastSentCompleted = false

        enqueueOperation { [weak self] in
            guard let self, self.requestGeneration == capturedGeneration else { return }
            let activitiesToEnd = Activity<FastingAttributes>.activities
            for activity in activitiesToEnd {
                await activity.end(finalContent, dismissalPolicy: dismissalPolicy)
            }
            if let fallbackCurrent, !activitiesToEnd.contains(where: { $0.id == fallbackCurrent.id }) {
                await fallbackCurrent.end(finalContent, dismissalPolicy: dismissalPolicy)
            }
        }
    }
}
