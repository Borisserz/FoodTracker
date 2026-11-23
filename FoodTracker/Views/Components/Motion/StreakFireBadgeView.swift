import SwiftUI

enum StreakBadgeCopy {
    static func label(days: Int) -> String {
        String(format: String(localized: String.LocalizationValue("%lld DAY STREAK")), days)
    }
}

// MARK: - Streak Badge (Apple HIG HUD Standard)
public struct StreakFireBadgeView: View {
    public let streakDays: Int

    public init(streakDays: Int) {
        self.streakDays = streakDays
    }

    public var body: some View {
        let title = StreakBadgeCopy.label(days: streakDays)
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.0))

            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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
        .accessibilityLabel(title)
    }
}
