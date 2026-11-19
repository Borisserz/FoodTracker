import Foundation
import ActivityKit

public struct FastingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentStage: String
        public var progressPct: Double
        public var isCompleted: Bool

        public init(currentStage: String, progressPct: Double, isCompleted: Bool = false) {
            self.currentStage = currentStage
            self.progressPct = progressPct
            self.isCompleted = isCompleted
        }

        private enum CodingKeys: String, CodingKey {
            case currentStage
            case progressPct
            case isCompleted
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.currentStage = try container.decode(String.self, forKey: .currentStage)
            self.progressPct = try container.decode(Double.self, forKey: .progressPct)
            self.isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
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

    public static func isCompleted(now: Date = Date(), targetEndDate: Date, progressPct: Double) -> Bool {
        now >= targetEndDate || progressPct >= 1.0
    }
}
