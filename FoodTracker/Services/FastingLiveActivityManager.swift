import Foundation
import ActivityKit

@MainActor
protocol FastingLiveActivityManaging: AnyObject {
    func startActivity(planName: String, targetHours: Int, startTime: Date)
    func updateActivity(currentStage: String, progressPct: Double)
    func endActivity()
}

@Observable
final class FastingLiveActivityManager: FastingLiveActivityManaging {
    static let shared = FastingLiveActivityManager()
    
    @ObservationIgnored private var currentActivity: Activity<FastingAttributes>?
    @ObservationIgnored private var lastSentStage: String?
    @ObservationIgnored private var lastSentProgress: Double = -1.0
    
    private init() {}
    
    func startActivity(planName: String, targetHours: Int, startTime: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let targetEndDate = startTime.addingTimeInterval(TimeInterval(targetHours * 3600))
        
        let attributes = FastingAttributes(
            planName: planName,
            targetEndDate: targetEndDate
        )
        
        let initialContentState = FastingAttributes.ContentState(
            currentStage: "Anabolic",
            progressPct: 0.0
        )
        
        let content = ActivityContent(
            state: initialContentState,
            staleDate: nil,
            relevanceScore: 100
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            lastSentStage = "Anabolic"
            lastSentProgress = 0.0
            print("Live Activity started successfully: \(currentActivity?.id ?? "")")
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func updateActivity(currentStage: String, progressPct: Double) {
        guard let activity = currentActivity else { return }
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
        guard let activity = currentActivity else { return }
        
        let finalState = FastingAttributes.ContentState(
            currentStage: "Completed",
            progressPct: 1.0
        )
        
        let finalContent = ActivityContent(
            state: finalState,
            staleDate: nil,
            relevanceScore: 0
        )
        
        Task {
            await activity.end(finalContent, dismissalPolicy: .default)
            currentActivity = nil
            lastSentStage = nil
            lastSentProgress = -1.0
        }
    }
}
