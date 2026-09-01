import SwiftUI
import SwiftData

// MARK: - More Tab Hub

struct MoreTabView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Query private var users: [User]
    @Query(sort: \WeightLog.date, order: .forward) private var weightLogs: [WeightLog]

    @State private var appearedItems: [Int] = []

    private var user: User? { users.first }
    private var currentWeight: Double { weightLogs.last?.weight ?? user?.weight ?? 0.0 }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.themeBg.ignoresSafeArea()

                // Decorative ambient blobs
                decorativeBackground

                ScrollView {
                    VStack(spacing: 20) {
                        // Header greeting
                        headerSection
                            .padding(.top, 8)

                        // Navigation cards
                        VStack(spacing: 16) {
                            ForEach(Array(moreItems.enumerated()), id: \.element.id) { index, item in
                                MoreNavCard(item: item)
                                    .opacity(appearedItems.contains(index) ? 1 : 0)
                                    .offset(y: appearedItems.contains(index) ? 0 : 24)
                                    .animation(
                                        .spring(response: 0.5, dampingFraction: 0.75)
                                            .delay(Double(index) * 0.08),
                                        value: appearedItems.contains(index)
                                    )
                            }
                        }
                        .padding(.horizontal)

                        // Visual Progress Section (Before/After Photo comparison)
                        BeforeAfterView()
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .opacity(appearedItems.count >= moreItems.count ? 1 : 0)
                            .animation(.easeIn(duration: 0.5).delay(0.25), value: appearedItems.count)

                        // Cross-Promo Banner
                        crossPromoBanner
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .opacity(appearedItems.count >= moreItems.count ? 1 : 0)
                            .animation(.easeIn(duration: 0.5).delay(0.3), value: appearedItems.count)

                        // App info footer
                        footerSection
                            .padding(.bottom, 32)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            // Stagger card entrance animations
            for i in 0..<moreItems.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                    withAnimation {
                        appearedItems.append(i)
                    }
                }
            }
        }
    }

    // MARK: - Data

    private var moreItems: [MoreItem] {
        [
            MoreItem(
                id: 0,
                title: "Goals & Progress",
                subtitle: weightLogs.isEmpty
                    ? "Set your weight goal"
                    : String(format: "Current: %.1f kg", currentWeight),
                icon: "target",
                gradient: [.themePink, .themeOrange],
                badge: nil,
                destination: AnyView(GoalsTabView())
            ),
            MoreItem(
                id: 1,
                title: "AI Coach",
                subtitle: "Your proactive nutritionist",
                icon: "sparkles",
                gradient: [Color(hex: 0x9B59B6), Color(hex: 0xF25C78)],
                badge: nil,
                destination: AnyView(AICoachDashboardView(selectedDate: Date()))
            ),
            MoreItem(
                id: 2,
                title: "Profile & Settings",
                subtitle: user.map { "Hello, \($0.name)!" } ?? "Edit your profile",
                icon: "person.crop.circle.fill",
                gradient: [Color(hex: 0x3498DB), Color(hex: 0x6BB8F2)],
                badge: nil,
                destination: AnyView(ProfileWrapperView())
            )
        ]
    }

    // MARK: - Subviews

    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(user?.name ?? "Champion")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(themeManager.current.primaryGradient)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<22: return "Good evening,"
        default:      return "Good night,"
        }
    }

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("FoodTracker")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("Version 1.0.0")
                .font(.caption2)
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var crossPromoBanner: some View {
        Button(action: {
            TrackingManager.shared.track(.crossPromoTapped(app: "workout_tracker"))
            if let url = URL(string: "https://apps.apple.com/app/id6774895106") {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 16) {
                // App Icon Placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [Color.themeOrange, Color.themePink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 60, height: 60)
                        .shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout Tracker")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Your ultimate fitness companion")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer(minLength: 0)
                
                // "GET" Button
                VStack(spacing: 3) {
                    Text("GET")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(LinearGradient(colors: [Color.themeOrange, Color.themePink], startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                        .shadow(color: Color.themePink.opacity(0.3), radius: 4, y: 2)
                    
                    Text("In-App Purchases")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.themeOrange.opacity(0.4), Color.themePink.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                }
                .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
            }
        }
        .buttonStyle(BounceButtonStyle())
    }

    @ViewBuilder
    private var decorativeBackground: some View {
        Circle()
            .fill(themeManager.current.primaryAccent.opacity(0.12))
            .frame(width: 360, height: 360)
            .blur(radius: 80)
            .offset(x: -120, y: -260)
            .allowsHitTesting(false)

        Circle()
            .fill(themeManager.current.secondaryAccent.opacity(0.08))
            .frame(width: 320, height: 320)
            .blur(radius: 90)
            .offset(x: 140, y: 220)
            .allowsHitTesting(false)
    }
}

// MARK: - Model

private struct MoreItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let badge: String?
    let destination: AnyView
}

// MARK: - Navigation Card

private struct MoreNavCard: View {
    let item: MoreItem
    @State private var isPressed = false

    var body: some View {
        NavigationLink(destination: item.destination) {
            HStack(spacing: 18) {

                // Icon container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: item.gradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                        .shadow(color: item.gradient.first?.opacity(0.4) ?? .clear, radius: 8, y: 4)

                    Image(systemName: item.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(item.gradient.first ?? .secondary)
                    .offset(x: isPressed ? 4 : 0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.25),
                                    .white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
            }
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false }
                }
        )
    }
}
