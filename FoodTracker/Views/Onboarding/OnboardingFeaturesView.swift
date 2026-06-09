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
    @State private var motionManager = MotionManager.shared
    
    private let features: [OnboardingFeatureItem] = [
        OnboardingFeatureItem(
            iconName: "sparkles",
            title: "AI Nutrition Coach",
            description: "Chat with your personal AI coach. Get macro advice, daily verdicts, and personalized health guidance.",
            color: .themePink
        ),
        OnboardingFeatureItem(
            iconName: "camera.viewfinder",
            title: "Smart Food Vision",
            description: "Simply snap a photo of your meal or scan a barcode. Our AI instantly calculates your calories, protein, fats, and carbs.",
            color: .themeOrange
        ),
        OnboardingFeatureItem(
            iconName: "frying.pan.fill",
            title: "AI Chef Studio",
            description: "Input ingredients from your fridge and get diet-matched recipes. Plus, use your camera so the AI can monitor and guide your cooking process!",
            color: .themeYellow
        ),
        OnboardingFeatureItem(
            iconName: "person.crop.circle.badge.clock",
            title: "Visual Progress",
            description: "Upload Before & After photos to visually compare your transformation and let AI analyze your physical progress.",
            color: .green
        ),
        OnboardingFeatureItem(
            iconName: "chart.bar.xaxis",
            title: "Intelligent Analytics",
            description: "Deep insights into your consistency and habits, featuring an AI Hydration Coach that optimizes your water and pH balance.",
            color: .cyan
        )
    ]

    var body: some View {
        ZStack {
            // Deep space dark background
            Color(red: 0.02, green: 0.02, blue: 0.04).ignoresSafeArea()
            
            // Dynamic starry/glowing background
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(features[currentIndex].color.opacity(0.15))
                        .frame(width: geo.size.width * 1.5, height: geo.size.width * 1.5)
                        .blur(radius: 100)
                        .offset(
                            x: -geo.size.width * 0.2 + CGFloat(motionManager.roll * 50),
                            y: -geo.size.height * 0.2 + CGFloat(motionManager.pitch * 50)
                        )
                    
                    Circle()
                        .fill(features[currentIndex].color.opacity(0.1))
                        .frame(width: geo.size.width, height: geo.size.width)
                        .blur(radius: 80)
                        .offset(
                            x: geo.size.width * 0.4 - CGFloat(motionManager.roll * 40),
                            y: geo.size.height * 0.4 - CGFloat(motionManager.pitch * 40)
                        )
                }
                .animation(.easeInOut(duration: 0.8), value: currentIndex)
                .animation(.interactiveSpring(), value: motionManager.pitch)
            }
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                TabView(selection: $currentIndex) {
                    ForEach(0..<features.count, id: \.self) { index in
                        Parallax3DCard(item: features[index], motion: motionManager)
                            .padding(.horizontal, 32)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .frame(height: 520)
                
                Spacer()
                
                OnboardingButton(title: currentIndex == features.count - 1 ? "Get Started" : "Continue") {
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

private struct Parallax3DCard: View {
    let item: OnboardingFeatureItem
    let motion: MotionManager
    @State private var isVisible = false
    @State private var dragOffset: CGSize = .zero
    
    // Convert motion attitude to degrees for rotation, adding dragOffset for simulator support
    private var rollDegrees: Double {
        let baseRoll = max(-15, min(15, motion.roll * 180 / .pi))
        let dragRoll = Double(dragOffset.width) / 10.0
        return max(-20, min(20, baseRoll + dragRoll))
    }
    
    private var pitchDegrees: Double {
        let basePitch = max(-15, min(15, motion.pitch * 180 / .pi))
        let dragPitch = Double(dragOffset.height) / 10.0
        return max(-20, min(20, basePitch + dragPitch))
    }
    
    var body: some View {
        ZStack {
            // Base Card Layer
            RoundedRectangle(cornerRadius: 40)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .shadow(color: item.color.opacity(0.3), radius: 30, x: CGFloat(rollDegrees), y: CGFloat(pitchDegrees) + 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 40)
                        .stroke(LinearGradient(colors: [item.color.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
            
            // Content Layer
            VStack(spacing: 32) {
                // Floating Icon Layer
                ZStack {
                    Circle()
                        .fill(item.color.opacity(0.15))
                        .frame(width: 140, height: 140)
                        .blur(radius: 20)
                        .offset(x: CGFloat(-rollDegrees * 1.5), y: CGFloat(-pitchDegrees * 1.5))
                    
                    Image(systemName: item.iconName)
                        .font(.system(size: 64, weight: .ultraLight))
                        .foregroundStyle(item.color)
                        .shadow(color: item.color.opacity(0.8), radius: 15, x: 0, y: 0)
                        .symbolEffect(.pulse, options: .repeating, value: isVisible)
                        // Extra parallax for the icon
                        .offset(x: CGFloat(-rollDegrees * 2.5), y: CGFloat(-pitchDegrees * 2.5))
                }
                .padding(.top, 40)
                
                // Floating Text Layer
                VStack(spacing: 16) {
                    Text(item.title)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 5)
                        // Medium parallax for title
                        .offset(x: CGFloat(-rollDegrees * 1.0), y: CGFloat(-pitchDegrees * 1.0))
                    
                    Text(item.description)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 24)
                        // Subtle parallax for description
                        .offset(x: CGFloat(-rollDegrees * 0.5), y: CGFloat(-pitchDegrees * 0.5))
                }
                .padding(.bottom, 50)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 500)
        // Apply the core 3D rotation to the entire card
        .rotation3DEffect(
            .degrees(rollDegrees),
            axis: (x: 0.0, y: 1.0, z: 0.0),
            perspective: 0.5
        )
        .rotation3DEffect(
            .degrees(pitchDegrees),
            axis: (x: -1.0, y: 0.0, z: 0.0),
            perspective: 0.5
        )
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                        dragOffset = value.translation
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                        dragOffset = .zero
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                isVisible = true
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
}

#Preview {
    OnboardingFeaturesView(onNext: {})
}
