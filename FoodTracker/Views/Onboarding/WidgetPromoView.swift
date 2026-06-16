import SwiftUI

struct WidgetPromoView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Smooth appearance animation states
    @State private var animateCards = false
    @State private var animateText = false
    @State private var showTutorial = false
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: 0x1E1E24).ignoresSafeArea()
            
            // Decorative background blurs
            Circle()
                .fill(Color(hex: 0x4CA3E6).opacity(0.4))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -150, y: -200)
            
            Circle()
                .fill(Color(hex: 0xF2CF66).opacity(0.3))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: 150, y: 150)

            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Text("Unlock Superpowers")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .opacity(animateText ? 1 : 0)
                        .offset(y: animateText ? 0 : 20)
                    
                    Text("Add FoodTracker widgets to your Home Screen to track calories, hydration, and shopping lists without opening the app.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .opacity(animateText ? 1 : 0)
                        .offset(y: animateText ? 0 : 20)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Visual Showcase
                ZStack {
                    // Left Widget (Hydration)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(hex: 0x2A2A35))
                        .frame(width: 140, height: 140)
                        .overlay {
                            VStack(spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Hydration")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.7))
                                        Text("1.8 L")
                                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    Image(systemName: "drop.fill")
                                        .font(.title2)
                                        .foregroundStyle(
                                            LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 0.99), Color(red: 0.0, green: 0.5, blue: 0.99)], startPoint: .top, endPoint: .bottom)
                                        )
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                
                                // Premium Wave Progress
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.15))
                                    
                                    Capsule()
                                        .fill(
                                            LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 0.99), Color(red: 0.0, green: 0.5, blue: 0.99)], startPoint: .leading, endPoint: .trailing)
                                        )
                                        .frame(width: 80)
                                        .shadow(color: Color(red: 0.0, green: 0.5, blue: 0.99).opacity(0.4), radius: 5, y: 3)
                                }
                                .frame(height: 14)
                                .padding(.horizontal, 16)
                                
                                // Interactive AppIntent Button
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("250 ml")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(LinearGradient(colors: [Color(red: 0.0, green: 0.5, blue: 0.99), Color(red: 0.2, green: 0.8, blue: 0.99)], startPoint: .leading, endPoint: .trailing))
                                        .shadow(color: Color(red: 0.0, green: 0.5, blue: 0.99).opacity(0.3), radius: 4, y: 2)
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
                        .rotationEffect(.degrees(-10))
                        .offset(x: animateCards ? -70 : -20, y: animateCards ? -20 : 0)
                        .opacity(animateCards ? 1 : 0)
                    
                    // Right Widget (Sticky Note)
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 1.0, green: 0.95, blue: 0.6)) // Match real widget sticky yellow
                        .frame(width: 140, height: 140)
                        .overlay {
                            VStack(alignment: .leading, spacing: 8) {
                                // Tape
                                HStack {
                                    Spacer()
                                    Rectangle()
                                        .fill(Color.white.opacity(0.4))
                                        .frame(width: 40, height: 12)
                                        .rotationEffect(.degrees(-2))
                                        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                                    Spacer()
                                }
                                .padding(.top, -10)
                                
                                Text("To Buy")
                                    .font(.custom("Marker Felt", size: 20))
                                    .foregroundColor(.black.opacity(0.8))
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 2)
                                
                                Spacer()
                                Text("All done! 🎉")
                                    .font(.custom("Marker Felt", size: 16))
                                    .foregroundColor(.black.opacity(0.5))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                Spacer()
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 15)
                        .rotationEffect(.degrees(15))
                        .offset(x: animateCards ? 70 : 20, y: animateCards ? 10 : 0)
                        .opacity(animateCards ? 1 : 0)
                        
                    // Center Widget (Metabolic Score)
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(hex: 0x24242E))
                        .frame(width: 160, height: 160)
                        .overlay {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Metabolic")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                    Spacer()
                                    Image(systemName: "bolt.heart.fill")
                                        .foregroundColor(Color(red: 0.1, green: 0.8, blue: 0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                                
                                ZStack {
                                    Circle()
                                        .stroke(Color(red: 0.1, green: 0.8, blue: 0.3).opacity(0.15), lineWidth: 14)
                                    
                                    Circle()
                                        .trim(from: 0, to: 0.92)
                                        .stroke(
                                            AngularGradient(
                                                gradient: Gradient(colors: [Color(red: 0.1, green: 0.8, blue: 0.3).opacity(0.5), Color(red: 0.1, green: 0.8, blue: 0.3)]),
                                                center: .center,
                                                startAngle: .degrees(-90),
                                                endAngle: .degrees(270)
                                            ),
                                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .shadow(color: Color(red: 0.1, green: 0.8, blue: 0.3).opacity(0.4), radius: 8, x: 0, y: 2)
                                    
                                    VStack(spacing: -2) {
                                        Text("92")
                                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("SCORE")
                                            .font(.system(size: 9, weight: .black, design: .rounded))
                                            .foregroundColor(.white.opacity(0.5))
                                            .tracking(1.5)
                                    }
                                }
                                .padding(.horizontal, 24)
                                .padding(.bottom, 16)
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 20)
                        .offset(y: animateCards ? 40 : 10)
                        .opacity(animateCards ? 1 : 0)
                }
                
                Spacer()
                
                // Bottom Instructions & Buttons
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .foregroundColor(.white.opacity(0.6))
                        Text("Long press your Home Screen and tap '+' to add widgets.")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
                    
                    Button {
                        HapticManager.shared.impact(style: .medium)
                        withAnimation(.spring()) {
                            showTutorial = true
                        }
                    } label: {
                        Text("Add to Home Screen")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [Color(hex: 0x4CA3E6), Color(hex: 0x7A52E6)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: Color(hex: 0x4CA3E6).opacity(0.5), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 32)
                    .opacity(animateText ? 1 : 0)
                    .offset(y: animateText ? 0 : 20)
                    
                    Button {
                        PromoManager.shared.remindMeLater()
                        dismiss()
                    } label: {
                        Text("Remind me later")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.bottom, 16)
                    .opacity(animateText ? 1 : 0)
                }
            }
            
            // Tutorial Overlay
            if showTutorial {
                ZStack {
                    // Glassmorphic background
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                        .environment(\.colorScheme, .dark)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showTutorial = false }
                        }
                    
                    VStack(spacing: 0) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color(hex: 0x4CA3E6).opacity(0.3), Color(hex: 0x7A52E6).opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 80, height: 80)
                                    .blur(radius: 10)
                                
                                Image(systemName: "square.dashed.inset.filled")
                                    .font(.system(size: 44, weight: .light))
                                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0x4CA3E6), Color(hex: 0x7A52E6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .symbolEffect(.bounce, options: .repeating)
                            }
                            
                            VStack(spacing: 8) {
                                Text("Add to Home Screen")
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                
                                Text("Unlock your data at a glance")
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 24)
                        
                        // Steps
                        VStack(spacing: 12) {
                            TutorialStepRow(number: "1", icon: "iphone.homebutton", title: String(localized: "Go to Home Screen"), subtitle: String(localized: "Swipe up to exit the app"))
                            TutorialStepRow(number: "2", icon: "hand.tap.fill", title: String(localized: "Long press empty space"), subtitle: String(localized: "Wait until apps start jiggling"))
                            TutorialStepRow(number: "3", icon: "plus.circle.fill", title: String(localized: "Tap the '+' button"), subtitle: String(localized: "Usually at the top left corner"))
                            TutorialStepRow(number: "4", icon: "magnifyingglass", title: String(localized: "Search for FoodTracker"), subtitle: String(localized: "Add your favorite widget size"))
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer(minLength: 32)
                        
                        // Action Button
                        Button {
                            HapticManager.shared.notification(type: .success)
                            PromoManager.shared.markWidgetPromoAsSeen()
                            dismiss()
                        } label: {
                            Text("Got it! Let's go")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    LinearGradient(colors: [Color(hex: 0x4CA3E6), Color(hex: 0x7A52E6)], startPoint: .leading, endPoint: .trailing)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: Color(hex: 0x4CA3E6).opacity(0.4), radius: 15, x: 0, y: 8)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(Color(hex: 0x1E1E24).opacity(0.95))
                            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 20)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .stroke(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    )
                    .padding(20)
                }
                .zIndex(100)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .center)))
            }
        }
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 100, damping: 15).delay(0.1)) {
                animateCards = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.3)) {
                animateText = true
            }
        }
    }
}

struct TutorialStepRow: View {
    let number: String
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon & Number
            ZStack {
                Circle()
                    .fill(Color(hex: 0x2A2A35))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0x4CA3E6), Color(hex: 0x7A52E6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                
                // Floating Number Badge
                Text(number)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(Color(hex: 0x7A52E6))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(hex: 0x2A2A35), lineWidth: 2))
                    .offset(x: 18, y: -18)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
