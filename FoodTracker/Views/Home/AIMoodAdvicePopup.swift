import SwiftUI

struct AIMoodAdvicePopup: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.dismiss) var dismiss
    
    let moodEmoji: String
    let moodName: String
    let onChatWithCoach: () -> Void
    
    var aiAdviceTitle: String {
        switch moodEmoji {
        case "🚀": return "Riding the Wave!"
        case "😊": return "Keep It Up!"
        case "😐": return "Finding Balance"
        case "🥲": return "Need a Boost?"
        case "😫": return "Let's De-stress"
        default: return "AI Coach Insights"
        }
    }
    
    var aiAdviceMessage: String {
        switch moodEmoji {
        case "🚀": return "You're full of energy! This is a great time to tackle a heavy workout. Make sure you're getting enough protein to support that drive."
        case "😊": return "Feeling good? A balanced plate will keep your mood stable. Stay hydrated and stick to your plan."
        case "😐": return "It's a neutral day. Sometimes taking a quick 10-minute walk or drinking a glass of cold water can naturally elevate your baseline."
        case "🥲": return "I see you're feeling a bit down. A small, healthy snack with complex carbs (like a banana or oats) can trigger a natural serotonin release!"
        case "😫": return "Stress can cause cortisol spikes which leads to cravings. Try drinking some herbal tea and taking deep breaths. I'm here if you want to talk."
        default: return "Your mood impacts your digestion and cravings. Tracking it helps us find patterns over time!"
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onChatWithCoach()
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
    }
}
