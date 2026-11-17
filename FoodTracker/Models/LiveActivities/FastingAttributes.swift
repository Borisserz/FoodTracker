import Foundation
import ActivityKit

public struct FastingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentStage: String
        public var progressPct: Double
        
        public init(currentStage: String, progressPct: Double) {
            self.currentStage = currentStage
            self.progressPct = progressPct
        }
    }
    
    public var planName: String
    public var targetEndDate: Date
    
    public init(planName: String, targetEndDate: Date) {
        self.planName = planName
        self.targetEndDate = targetEndDate
    }
}

public enum FastingActivityTiming {
    /// Returns a valid ascending range for countdown timers, or `nil` once the target end date has passed.
    public static func remainingInterval(now: Date = Date(), targetEndDate: Date) -> ClosedRange<Date>? {
        guard now < targetEndDate else { return nil }
        return now...targetEndDate
    }
}
