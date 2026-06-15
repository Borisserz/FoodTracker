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
