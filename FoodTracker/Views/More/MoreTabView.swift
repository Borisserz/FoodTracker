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
                id: 3,
                title: "Visual Progress Analysis",
                subtitle: "Compare photos & track changes",
                icon: "photo.on.rectangle.angled",
                gradient: [.purple, .themePink],
                badge: "AI",
                destination: AnyView(AIVisualProgressView())
            ),
            MoreItem(
                id: 1,
                title: "AI Coach",
                subtitle: "Your proactive nutritionist",
                icon: "sparkles",
                gradient: [Color(hex: 0x9B59B6), Color(hex: 0xF25C78)],
                badge: "AI",
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
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
            Text(user?.name ?? "")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
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
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
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
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LinearGradient(colors: [Color.themeOrange, Color.themePink], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.themePink.opacity(0.4), radius: 8, y: 4)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout Tracker")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Your ultimate fitness companion")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 0)
                
                // "GET" Button
                VStack {
                    Text("GET")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.themeOrange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.themeOrange.opacity(0.15))
                        .clipShape(Capsule())
                    
                    Text("In-App Purchases")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
                
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [.themeOrange.opacity(0.5), .themePink.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
            }
        }
        .buttonStyle(BounceButtonStyle())
    }

    @ViewBuilder
    private var decorativeBackground: some View {
        Circle()
            .fill(Color.themePink.opacity(0.10))
            .frame(width: 340, height: 340)
            .blur(radius: 70)
            .offset(x: -130, y: -280)
            .allowsHitTesting(false)

        Circle()
            .fill(Color.themeOrange.opacity(0.08))
            .frame(width: 300, height: 300)
            .blur(radius: 80)
            .offset(x: 160, y: 260)
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
                        .frame(width: 56, height: 56)
                        .shadow(color: item.gradient.first?.opacity(0.35) ?? .clear, radius: 10, y: 4)

                    Image(systemName: item.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)

                    // AI badge
                    if let badge = item.badge {
                        Text(badge)
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.3))
                            .clipShape(.capsule)
                            .offset(x: 18, y: -18)
                    }
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(item.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 4)
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.12)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressed = false }
                }
        )
    }
}
