import SwiftUI

struct AIMoodAdvicePopup: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) var dismiss
    
    let moodEmoji: String
    let moodName: String
    let onChatWithCoach: () -> Void
    
    var aiAdviceTitle: String {
        switch moodEmoji {
        case "🚀": return String(localized: "Riding the Wave!")
        case "😊": return String(localized: "Keep It Up!")
        case "😐": return String(localized: "Finding Balance")
        case "🥲": return String(localized: "Need a Boost?")
        case "😫": return String(localized: "Let's De-stress")
        default: return String(localized: "AI Coach Insights")
        }
    }
    
    var aiAdviceMessage: String {
        switch moodEmoji {
        case "🚀": return String(localized: "You're full of energy! This is a great time to tackle a heavy workout. Make sure you're getting enough protein to support that drive.")
        case "😊": return String(localized: "Feeling good? A balanced plate will keep your mood stable. Stay hydrated and stick to your plan.")
        case "😐": return String(localized: "It's a neutral day. Sometimes taking a quick 10-minute walk or drinking a glass of cold water can naturally elevate your baseline.")
        case "🥲": return String(localized: "I see you're feeling a bit down. A small, healthy snack with complex carbs (like a banana or oats) can trigger a natural serotonin release!")
        case "😫": return String(localized: "Stress can cause cortisol spikes which leads to cravings. Try drinking some herbal tea and taking deep breaths. I'm here if you want to talk.")
        default: return String(localized: "Your mood impacts your digestion and cravings. Tracking it helps us find patterns over time.")
        }
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
            .padding(.top, 40)
            
            VStack(spacing: 12) {
                Text(aiAdviceTitle)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                
                Text(aiAdviceMessage)
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    dismiss()
                    // Use structured concurrency instead of Dispatch for the small delay
                    // so the transition to chat is cleaner and doesn't risk re-triggering the advice sheet.
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        await MainActor.run {
                            onChatWithCoach()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "message.fill")
                        Text(LocalizedStringKey("Chat with AI Coach"))
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
                    Text(LocalizedStringKey("Got it"))
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Color.themeBg.ignoresSafeArea())
    }
}
