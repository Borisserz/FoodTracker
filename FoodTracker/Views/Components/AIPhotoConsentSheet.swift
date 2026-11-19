import SwiftUI

/// Explicit App Store privacy disclosure & consent modal shown before sending any photo to third-party AI vision providers.
struct AIPhotoConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager

    var onAllow: () -> Void
    var onDecline: () -> Void

    @State private var didResolveConsent = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    ZStack {
                        Circle()
                            .fill(themeManager.current.primaryAccent.opacity(0.14))
                            .frame(width: 76, height: 76)
                        Image(systemName: "hand.raised.app.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(themeManager.current.primaryAccent)
                    }
                    .padding(.top, 12)

                    VStack(spacing: 8) {
                        Text("AI Photo Analysis Consent")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Review how your photos are processed before using AI visual analysis.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ConsentInfoRow(
                            icon: "photo.on.rectangle.angled",
                            iconColor: .blue,
                            title: "What is sent",
                            detail: "Only the downsampled photo you capture or pick for meal, menu, cooking-step, or progress analysis."
                        )
                        Divider()
                        ConsentInfoRow(
                            icon: "network.badge.shield.half.filled",
                            iconColor: themeManager.current.primaryAccent,
                            title: "Who processes it",
                            detail: "Photos are sent over encrypted HTTPS via FoodTracker's proxy to OpenRouter and third-party AI vision models to estimate nutrition and provide feedback."
                        )
                        Divider()
                        ConsentInfoRow(
                            icon: "lock.shield.fill",
                            iconColor: .green,
                            title: "Privacy & control",
                            detail: "Photos are processed transiently with provider data retention disabled, and you can revoke this consent anytime in Settings."
                        )
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        didResolveConsent = true
                        AIPhotoConsentManager.shared.grantConsent()
                        dismiss()
                        onAllow()
                    } label: {
                        Text("Allow & Analyze")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(themeManager.current.primaryAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(BounceButtonStyle())

                    Button {
                        didResolveConsent = true
                        dismiss()
                        onDecline()
                    } label: {
                        Text("Not Now")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        didResolveConsent = true
                        dismiss()
                        onDecline()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onDisappear {
            if !didResolveConsent {
                onDecline()
            }
        }
    }
}

private struct ConsentInfoRow: View {
    let icon: String
    let iconColor: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
