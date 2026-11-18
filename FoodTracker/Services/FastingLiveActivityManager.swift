import Foundation
import ActivityKit

@MainActor
protocol FastingLiveActivityManaging: AnyObject {
    func startActivity(planName: String, targetHours: Int, startTime: Date)
    func reattachActivity(planName: String, targetHours: Int, startTime: Date, currentStage: String, progressPct: Double)
    func updateActivity(currentStage: String, progressPct: Double)
    func endActivity()
}

@Observable
final class FastingLiveActivityManager: FastingLiveActivityManaging {
    static let shared = FastingLiveActivityManager()
    
    @ObservationIgnored private var currentActivity: Activity<FastingAttributes>?
    @ObservationIgnored private var lastSentStage: String?
    @ObservationIgnored private var lastSentProgress: Double = -1.0
    
    private init() {
        currentActivity = Activity<FastingAttributes>.activities.first
    }

    private func activeActivity() -> Activity<FastingAttributes>? {
        if let current = currentActivity,
           Activity<FastingAttributes>.activities.contains(where: { $0.id == current.id }) {
            return current
        }
        let rehydrated = Activity<FastingAttributes>.activities.first
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
           abs(existing.attributes.targetEndDate.timeIntervalSince(targetEndDate)) < 60 {
            currentActivity = existing
            lastSentStage = nil
            lastSentProgress = -1.0
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

        let targetEndDate = startTime.addingTimeInterval(TimeInterval(targetHours * 3600))
        let attributes = FastingAttributes(
            planName: planName,
            targetEndDate: targetEndDate
        )
        let clampedProgress = min(max(initialProgress, 0.0), 1.0)
        let initialContentState = FastingAttributes.ContentState(
            currentStage: initialStage,
            progressPct: clampedProgress
        )
        let content = ActivityContent(
            state: initialContentState,
            staleDate: targetEndDate,
            relevanceScore: 100
        )

        // Ensure stale activities finish ending BEFORE requesting the new Live Activity so IDs don't race.
        let existingActivities = Activity<FastingAttributes>.activities
        Task { @MainActor [weak self] in
            for existing in existingActivities {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            guard let self else { return }
            do {
                self.currentActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
                self.lastSentStage = initialStage
                self.lastSentProgress = clampedProgress
                print("Live Activity started successfully: \(self.currentActivity?.id ?? "")")
            } catch {
                print("Failed to start Live Activity: \(error.localizedDescription)")
            }
        }
    }
    
    func updateActivity(currentStage: String, progressPct: Double) {
        guard let activity = activeActivity() else { return }
        // Avoid spamming ActivityKit every 1-second timer tick unless stage changed or progress moved >= 1%
        if currentStage == lastSentStage && abs(progressPct - lastSentProgress) < 0.01 {
            return
        }
        lastSentStage = currentStage
        lastSentProgress = progressPct
        
        let updatedState = FastingAttributes.ContentState(
            currentStage: currentStage,
            progressPct: progressPct
        )
        
        let updatedContent = ActivityContent(
            state: updatedState,
            staleDate: nil,
            relevanceScore: 100
        )
        
        Task {
            await activity.update(updatedContent)
        }
    }
    
    func endActivity() {
        let activitiesToEnd = Activity<FastingAttributes>.activities
        guard !activitiesToEnd.isEmpty || currentActivity != nil else { return }
        let fallbackCurrent = currentActivity

        let finalState = FastingAttributes.ContentState(
            currentStage: "Completed",
            progressPct: 1.0
        )
        
        let finalContent = ActivityContent(
            state: finalState,
            staleDate: nil,
            relevanceScore: 0
        )

        currentActivity = nil
        lastSentStage = nil
        lastSentProgress = -1.0

        Task {
            for activity in activitiesToEnd {
                await activity.end(finalContent, dismissalPolicy: .default)
            }
            if let fallbackCurrent, !activitiesToEnd.contains(where: { $0.id == fallbackCurrent.id }) {
                await fallbackCurrent.end(finalContent, dismissalPolicy: .default)
            }
        }
    }
}
