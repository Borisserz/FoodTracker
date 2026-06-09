import SwiftUI
import Combine

struct OnboardingFeatureItem: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingFeaturesView: View {
    let onNext: () -> Void

    @State private var currentIndex = 0
    
    private let features: [OnboardingFeatureItem] = [
        OnboardingFeatureItem(
            iconName: "sparkles",
            title: "AI Nutrition Coach",
            description: "Chat with your personal AI coach powered by Gemini. Get macro advice, recipe generation, and daily verdicts.",
            color: .themePink
        ),
        OnboardingFeatureItem(
            iconName: "chart.pie.fill",
            title: "Deep Analytics",
            description: "Visualize your consistency, streaks, and macro trends over time with beautiful interactive charts.",
            color: .themeOrange
        ),
        OnboardingFeatureItem(
            iconName: "bolt.fill",
            title: "Smart Quick Add",
            description: "Log your calories in seconds. Build a custom database of your favorite foods and recipes for rapid tracking.",
            color: .themeYellow
        )
    ]

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08).ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentIndex) {
                    ForEach(0..<features.count, id: \.self) { index in
                        FeatureSlideView(item: features[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .animation(.easeInOut, value: currentIndex)
                
                OnboardingButton(title: currentIndex == features.count - 1 ? "Let's Go!" : "Next") {
                    if currentIndex < features.count - 1 {
                        withAnimation { currentIndex += 1 }
                    } else {
                        onNext()
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct FeatureSlideView: View {
    let item: OnboardingFeatureItem
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .blur(radius: 40)
                
                Image(systemName: item.iconName)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(item.color)
                    .scaleEffect(isVisible ? 1 : 0.5)
                    .opacity(isVisible ? 1 : 0)
            }
            
            VStack(spacing: 16) {
                Text(item.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .offset(y: isVisible ? 0 : 20)
                    .opacity(isVisible ? 1 : 0)
                
                Text(item.description)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 40)
                    .offset(y: isVisible ? 0 : 20)
                    .opacity(isVisible ? 1 : 0)
            }
            
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}
