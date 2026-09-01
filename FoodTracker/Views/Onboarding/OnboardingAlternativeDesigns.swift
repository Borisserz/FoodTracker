import SwiftUI

// MARK: - Option A: Cyberpunk Hologram
struct CyberGlassCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: 60, weight: .ultraLight))
                    .foregroundStyle(color)
                    .shadow(color: color, radius: 10)
                
                Text(title)
                    .font(.custom("Menlo-Bold", size: 28))
                    .foregroundStyle(.white)
                
                Text(description)
                    .font(.custom("Menlo", size: 14))
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, style: StrokeStyle(lineWidth: 1, dash: [10, 5]))
                    .shadow(color: color, radius: 5)
            )
            .padding(30)
        }
    }
}

// MARK: - Option B: Apple Clean HIG (Light Mode)
struct CleanHIGCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            Color(red: 0.96, green: 0.96, blue: 0.97).ignoresSafeArea()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: icon)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(color)
                }
                
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(.black)
                
                Text(description)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(white: 0.4))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal)
            }
            .padding(.vertical, 50)
            .padding(.horizontal, 20)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 20, y: 10)
            .padding(30)
        }
    }
}

// MARK: - Option C: Premium Neumorphism (Soft UI)
struct NeumorphicCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            Color(red: 0.89, green: 0.91, blue: 0.93).ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(color)
                    .padding(30)
                    .background(
                        Circle()
                            .fill(Color(red: 0.89, green: 0.91, blue: 0.93))
                            .shadow(color: Color.white, radius: 10, x: -10, y: -10)
                            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 10, y: 10)
                    )
                
                Text(title)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(white: 0.3))
                
                Text(description)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(white: 0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color(red: 0.89, green: 0.91, blue: 0.93))
                    .shadow(color: Color.white, radius: 15, x: -15, y: -15)
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 15, y: 15)
            )
            .padding(30)
        }
    }
}

// MARK: - Previews for Xcode
#Preview("Option A: Cyberpunk") {
    CyberGlassCard(title: "AI Nutrition Coach", description: "Chat with your personal AI coach. Get macro advice and daily verdicts.", icon: "sparkles", color: .pink)
}

#Preview("Option B: Clean HIG") {
    CleanHIGCard(title: "AI Nutrition Coach", description: "Chat with your personal AI coach. Get macro advice and daily verdicts.", icon: "sparkles", color: .pink)
}

#Preview("Option C: Neumorphism") {
    NeumorphicCard(title: "AI Nutrition Coach", description: "Chat with your personal AI coach. Get macro advice and daily verdicts.", icon: "sparkles", color: .pink)
}
