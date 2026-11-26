import SwiftUI

struct CircadianFastingClock: View {
    var protocolName: String = "16:8 window"
    var hoursFasted: Int = 12
    var scheduleText: String = "12:00 - 20:00"

    var body: some View {
        EditorialDarkCard(cornerRadius: 20, padding: 15) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fasting timer")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(LocalizedStringKey(protocolName))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                    Spacer()
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(EditorialPalette.warmAmber)
                }

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 7)

                    Circle()
                        .trim(from: 0.0, to: CGFloat(min(max(hoursFasted, 1), 16)) / 16.0)
                        .stroke(
                            EditorialPalette.warmAmber,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text(scheduleText)
                            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                        Text("Eating window")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(EditorialPalette.oat.opacity(0.72))
                    }
                }
                .frame(height: 102)
            }
        }
    }
}
