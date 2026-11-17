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
            return (
                String(localized: "AI Coach Insights"),
                String(localized: "Noticing how '\(moodName)' connects with meals and hydration helps build sustainable habits over time.")
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
    @State private var isLoadingAI = true

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
        VStack(spacing: 24) {

            // Glowing AI Emoji
            ZStack {
                Circle()
                    .fill(themeManager.current.primaryGradient)
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                    .opacity(0.5)

                Text(moodEmoji)
                    .font(.system(size: 60))

                Image(systemName: "sparkles")
                    .font(.title)
                    .foregroundColor(themeManager.current.primaryAccent)
                    .offset(x: 35, y: -35)
            }
            .padding(.top, 36)

            VStack(spacing: 10) {
                if isLoadingAI {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.75)
                        Text("Personalizing AI advice...")
                            .font(.caption.bold())
                            .foregroundColor(themeManager.current.primaryAccent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(themeManager.current.primaryAccent.opacity(0.1))
                    .clipShape(Capsule())
                } else if dynamicAdvice != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Personalized AI Insight")
                    }
                    .font(.caption2.bold())
                    .foregroundColor(themeManager.current.primaryAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(themeManager.current.primaryAccent.opacity(0.1))
                    .clipShape(Capsule())
                }

                Text(aiAdviceTitle)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(aiAdviceMessage)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .animation(.easeInOut(duration: 0.25), value: aiAdviceMessage)

            Spacer()

            VStack(spacing: 16) {
                Button(action: {
                    dismiss()
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        await MainActor.run {
                            onChatWithCoach()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Chat with AI Coach")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeManager.current.primaryGradient)
                    .cornerRadius(16)
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.3), radius: 10, y: 5)
                }

                Button(action: { dismiss() }) {
                    Text("Got it")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.themeBg.ignoresSafeArea())
        .task {
            let result = await AINutritionService.shared.getMoodAdvice(
                moodEmoji: moodEmoji,
                moodName: moodName,
                note: dayNote,
                consumedCalories: consumedCalories,
                goalCalories: goalCalories,
                waterLiters: waterLiters,
                activeDiet: activeDiet
            )
            await MainActor.run {
                self.dynamicAdvice = result
                self.isLoadingAI = false
            }
        }
    }
}
