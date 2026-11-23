import SwiftUI

// MARK: - Streak Badge (Apple HIG HUD Standard)
public struct StreakFireBadgeView: View {
    public let streakDays: Int
    
    public init(streakDays: Int) {
        self.streakDays = streakDays
    }
    
    private var streakText: String {
        let format = NSLocalizedString("%d day streak", comment: "Streak badge text")
        return String.localizedStringWithFormat(format, streakDays)
    }
    
    public var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.0))
            
            Text("\(streakDays)d streak")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.primary.opacity(0.9))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color(red: 1.0, green: 0.58, blue: 0.0).opacity(0.25), lineWidth: 1.0)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(streakText)
    }
}
