import Foundation
import ActivityKit

@Observable
final class FastingLiveActivityManager {
    static let shared = FastingLiveActivityManager()
    
    private var currentActivity: Activity<FastingAttributes>?
    
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
            print("Live Activity started successfully: \(currentActivity?.id ?? "")")
        } catch {
            print("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }
    
    func updateActivity(currentStage: String, progressPct: Double) {
        guard let activity = currentActivity else { return }
        
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
        }
    }
}
