import SwiftUI

enum MoodAdviceBaseline {
    static func advice(forEmoji moodEmoji: String, moodName: String) -> (title: String, message: String) {
        switch moodEmoji {
        case "☀️":
            return (
                String(localized: "Radiating Great Energy!"),
                String(localized: "A great day is the best momentum—keep your meals balanced with lean protein and fiber so your energy stays steady through the evening.")
            )
        case "🍩":
            return (
                String(localized: "Enjoy & Reset Gently"),
                String(localized: "One treat doesn't undo your progress. Drink a glass of water, enjoy a protein-forward next meal, and skip any guilt.")
            )
        case "🍔":
            return (
                String(localized: "Compassion Over Guilt"),
                String(localized: "Heavy cravings happen. Don't starve yourself afterward—hydrate well, take an easy walk, and return calmly to your next balanced meal.")
            )
        case "🥲":
            return (
                String(localized: "Need a Boost?"),
                String(localized: "Tough moments drain energy. Warm herbal tea, hydration, and a comforting protein + complex-carb meal can help steady your mood.")
            )
        case "🏋️":
            return (
                String(localized: "Fuel That Recovery!"),
                String(localized: "Awesome workout energy! Prioritize 25–35g of protein and fluids over the next couple of hours so your muscles recover well.")
            )
        case "🧘‍♀️":
            return (
                String(localized: "Calm & Centered"),
                String(localized: "Low-stress days support great digestion and recovery. Keep sipping water and enjoy unhurried, nourishing meals.")
            )
        case "🤢":
            return (
                String(localized: "Rest & Gentle Hydration"),
                String(localized: "Listen to your body when feeling unwell. Focus on small sips of water or broth and simple, easy-to-digest foods—goals can wait.")
            )
        case "🚀":
            return (
                String(localized: "Riding the Wave!"),
                String(localized: "You're full of energy! Great time for an active session—just back it up with solid protein and hydration.")
            )
        case "😊":
            return (
                String(localized: "Keep It Up!"),
                String(localized: "Feeling good? A balanced plate will keep your mood steady. Stay hydrated and stick to your plan.")
            )
        case "😐":
            return (
                String(localized: "Finding Balance"),
                String(localized: "A quiet day is totally fine. A short 10-minute walk and a glass of water can naturally lift your energy.")
            )
        case "😫":
            return (
                String(localized: "Let's De-stress"),
                String(localized: "Stress raises cortisol and cravings. Try warm tea, slow breathing, and a steady meal—I'm here if you want to chat.")
            )
        default:
            let localizedMood = String(localized: String.LocalizationValue(moodName))
            return (
                String(localized: "AI Coach Insights"),
                String(localized: "Noticing how '\(localizedMood)' connects with meals and hydration helps build sustainable habits over time.")
            )
        }
    }
}

struct AIMoodAdvicePopup: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) var dismiss

    let moodEmoji: String
    let moodName: String
    var dayNote: String = ""
    var consumedCalories: Int = 0
    var goalCalories: Int = 2000
    var waterLiters: Double = 0
    var activeDiet: String = "Balanced"
    let onChatWithCoach: () -> Void

    @State private var dynamicAdvice: MoodAdviceDTO? = nil
    @State private var isLoadingAI = false
    @State private var showAIConsentSheet = false

    static func shouldAutoFetchAIAdvice(hasConsented: Bool) -> Bool {
        hasConsented
    }

    private var baseline: (title: String, message: String) {
        MoodAdviceBaseline.advice(forEmoji: moodEmoji, moodName: moodName)
    }

    var aiAdviceTitle: String {
        dynamicAdvice?.title ?? baseline.title
    }

    var aiAdviceMessage: String {
        dynamicAdvice?.message ?? baseline.message
    }

    var body: some View {
        ZStack {
            DynamicAuroraBackgroundView(pinnedPaletteIndex: 4)
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                // Editorial Dark Medallion
                ZStack {
                    Circle()
                        .fill(EditorialPalette.cardDark)
                        .frame(width: 96, height: 96)
                        .overlay(
                            Circle()
                                .strokeBorder(EditorialPalette.cardBorderDarkFocused, lineWidth: 1)
                        )

                    Text(moodEmoji)
                        .font(.system(size: 46))

                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(EditorialPalette.oat)
                        .padding(6)
                        .background(EditorialPalette.chipDark)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(EditorialPalette.cardBorderDark, lineWidth: 1))
                        .offset(x: 34, y: -32)
                }
                .padding(.top, 28)

                VStack(spacing: 10) {
                    if isLoadingAI {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.75)
                            Text("Personalizing AI advice...")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(EditorialPalette.inkPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(EditorialPalette.surfaceLight)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75))
                    } else if dynamicAdvice != nil {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(EditorialPalette.oat)
                            Text("Personalized AI Insight")
                                .foregroundStyle(.white)
                        }
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(EditorialPalette.cardDark)
                        .clipShape(Capsule())
                    }

                    Text(aiAdviceTitle)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(EditorialPalette.inkPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    EditorialLightCard(cornerRadius: 18, padding: 16) {
                        Text(aiAdviceMessage)
                            .font(.system(size: 14.5, weight: .regular, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkSecondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 20)

                    if !isLoadingAI && dynamicAdvice == nil && !AIPhotoConsentManager.shared.hasConsented {
                        Button {
                            showAIConsentSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(EditorialPalette.oat)
                                Text("Personalize with AI")
                                    .foregroundStyle(.white)
                            }
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(EditorialPalette.cardDark)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: aiAdviceMessage)

                Spacer()

                NutritionMethodologyDisclaimerView(citations: [.dietaryGuidelines], compact: true)
                    .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    Button(action: {
                        dismiss()
                        Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            await MainActor.run {
                                onChatWithCoach()
                            }
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                            Text("Chat with AI Coach")
                        }
                    }
                    .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite, height: 52))

                    Button(action: { dismiss() }) {
                        Text("Got it")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 22)
            }
        }
        .sheet(isPresented: $showAIConsentSheet) {
            AIPhotoConsentSheet(
                onAllow: {
                    Task { await fetchPersonalizedAdvice() }
                },
                onDecline: {}
            )
        }
        .task {
            guard Self.shouldAutoFetchAIAdvice(hasConsented: AIPhotoConsentManager.shared.hasConsented) else {
                return
            }
            await fetchPersonalizedAdvice()
        }
    }

    @MainActor
    private func fetchPersonalizedAdvice() async {
        guard !isLoadingAI else { return }
        isLoadingAI = true
        let result = await AINutritionService.shared.getMoodAdvice(
            moodEmoji: moodEmoji,
            moodName: moodName,
            note: dayNote,
            consumedCalories: consumedCalories,
            goalCalories: goalCalories,
            waterLiters: waterLiters,
            activeDiet: activeDiet
        )
        self.dynamicAdvice = result
        self.isLoadingAI = false
    }
}
