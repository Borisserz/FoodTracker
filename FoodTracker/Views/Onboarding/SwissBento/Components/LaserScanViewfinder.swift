import SwiftUI

struct LaserScanViewfinder: View {
    var body: some View {
        EditorialPhotoBackdropCard(
            imageName: "onboarding_scan_studio",
            minHeight: 248,
            cornerRadius: 24,
            scrimBottomOpacity: 0.90,
            alignment: .topLeading
        ) {
            VStack(alignment: .leading, spacing: 0) {
                // Honest feature badge without fake percentages
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Photo or barcode")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(EditorialPalette.chipDark.opacity(0.86))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75)
                )

                Spacer(minLength: 48)

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Sample meal breakdown")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(EditorialPalette.oat.opacity(0.85))

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("Herb chicken, avocado and quinoa")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Spacer()

                            Text("\(540) kcal")
                                .font(.system(size: 17, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(EditorialPalette.oat)
                        }
                    }

                    HStack(spacing: 8) {
                        EditorialMetricChip(label: "Protein", value: String(localized: "\(44) g"), accent: EditorialPalette.oceanSlate)
                        EditorialMetricChip(label: "Fat", value: String(localized: "\(22) g"), accent: EditorialPalette.warmAmber)
                        EditorialMetricChip(label: "Carbs", value: String(localized: "\(38) g"), accent: EditorialPalette.oat)
                    }
                }
            }
        }
        .frame(height: 256)
    }
}
