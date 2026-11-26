import SwiftUI

/// Explicit App Store privacy disclosure & consent modal shown before sending any photo to third-party AI vision providers.
struct AIPhotoConsentSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onAllow: () -> Void
    var onDecline: () -> Void

    @State private var didResolveConsent = false

    var body: some View {
        NavigationStack {
            ZStack {
                DynamicAuroraBackgroundView(pinnedPaletteIndex: 4)
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        EditorialPhotoBackdropCard(
                            imageName: "onboarding_scan_studio",
                            minHeight: 162,
                            cornerRadius: 20,
                            scrimBottomOpacity: 0.90,
                            alignment: .bottomLeading
                        ) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "hand.raised.app.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(EditorialPalette.oat)
                                    Text("AI Data & Photo Consent")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(EditorialPalette.oat)
                                }

                                Text("Only selected meal photos and nutrition details needed for your request are analyzed.")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: 235, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(height: 164)
                        .padding(.top, 8)

                        Text("Review how your photos and nutrition data are processed before using AI features.")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 14) {
                            ConsentInfoRow(
                                icon: "photo.on.rectangle.angled",
                                iconColor: EditorialPalette.oceanSlate,
                                title: "What is sent",
                                detail: "Only the downsampled photos you choose to scan and the nutrition goals, meals, mood notes, or chat prompts needed for your AI request."
                            )
                            Rectangle()
                                .fill(EditorialPalette.hairlineLight)
                                .frame(height: 0.5)
                            ConsentInfoRow(
                                icon: "network.badge.shield.half.filled",
                                iconColor: EditorialPalette.forest,
                                title: "Who processes it",
                                detail: "Data is sent over encrypted HTTPS via FoodTracker's proxy to OpenRouter and third-party AI providers to estimate nutrition and personalize feedback."
                            )
                            Rectangle()
                                .fill(EditorialPalette.hairlineLight)
                                .frame(height: 0.5)
                            ConsentInfoRow(
                                icon: "lock.shield.fill",
                                iconColor: EditorialPalette.emerald,
                                title: "Privacy & control",
                                detail: "Requests are processed transiently with provider data retention disabled, and you can revoke this consent anytime in Settings."
                            )
                        }
                        .padding(16)
                        .background(EditorialPalette.surfaceLight)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75)
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        didResolveConsent = true
                        AIPhotoConsentManager.shared.grantConsent()
                        dismiss()
                        onAllow()
                    } label: {
                        Text("Allow AI Analysis")
                    }
                    .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite, height: 52))

                    Button {
                        didResolveConsent = true
                        dismiss()
                        onDecline()
                    } label: {
                        Text("Not Now")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)
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
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(EditorialPalette.inkPrimary)
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.65))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkPrimary)
                Text(detail)
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
