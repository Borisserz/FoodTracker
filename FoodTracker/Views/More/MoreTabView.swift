import SwiftUI
import SwiftData

// MARK: - More Tab Hub

struct MoreTabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var themeManager
    @Query private var users: [User]
    @Query(sort: \WeightLog.date, order: .forward) private var weightLogs: [WeightLog]
    @AppStorage("useMetricSystem") private var useMetricSystem = true

    @State private var appearedItems: Set<Int> = []

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
                                MoreNavCard(item: item, reduceMotion: reduceMotion) {
                                    destinationView(for: item.destination)
                                }
                                .opacity(reduceMotion || appearedItems.contains(index) ? 1 : 0)
                                .offset(y: (reduceMotion || appearedItems.contains(index)) ? 0 : 24)
                                .animation(
                                    reduceMotion
                                        ? nil
                                        : .spring(response: 0.5, dampingFraction: 0.75)
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
                            .opacity(reduceMotion || appearedItems.count >= moreItems.count ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeIn(duration: 0.5).delay(0.25), value: appearedItems.count)

                        // Cross-Promo Banner
                        crossPromoBanner
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .opacity(reduceMotion || appearedItems.count >= moreItems.count ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeIn(duration: 0.5).delay(0.3), value: appearedItems.count)

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
            guard appearedItems.isEmpty else { return }
            if reduceMotion {
                appearedItems = Set(moreItems.indices)
                return
            }
            // Stagger card entrance animations
            for i in 0..<moreItems.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                    withAnimation {
                        _ = appearedItems.insert(i)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for destination: MoreDestination) -> some View {
        switch destination {
        case .goals:
            GoalsTabView()
        case .aiCoach:
            AICoachDashboardView(selectedDate: Date())
        case .profile:
            ProfileWrapperView()
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
                    : String(localized: "Current: \(NutritionMath.formattedWeight(currentWeight, useMetric: useMetricSystem))"),
                icon: "target",
                gradient: [.themePink, .themeOrange],
                badge: nil,
                accessibilityId: "more_goals_card",
                destination: .goals
            ),
            MoreItem(
                id: 1,
                title: "AI Coach",
                subtitle: "Your proactive nutritionist",
                icon: "sparkles",
                gradient: [Color(hex: 0x9B59B6), Color(hex: 0xF25C78)],
                badge: nil,
                accessibilityId: "more_coach_card",
                destination: .aiCoach
            ),
            MoreItem(
                id: 2,
                title: "Profile & Settings",
                subtitle: user.map { String(localized: "Hello, \($0.name)!") } ?? "Edit your profile",
                icon: "person.crop.circle.fill",
                gradient: [Color(hex: 0x3498DB), Color(hex: 0x6BB8F2)],
                badge: nil,
                accessibilityId: "more_profile_card",
                destination: .profile
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
        case 5..<12:  return String(localized: "Good morning,")
        case 12..<17: return String(localized: "Good afternoon,")
        case 17..<22: return String(localized: "Good evening,")
        default:      return String(localized: "Good night,")
        }
    }

    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("FoodTracker")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(.caption2)
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var crossPromoBanner: some View {
        Button(action: {
            TrackingManager.shared.track(.crossPromoTapped(app: "workout_tracker"))
            CrossAppLinkResolver.openWorkoutTracker()
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
                
                // Companion app CTA button
                HStack(spacing: 5) {
                    Text("Open")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(LinearGradient(colors: [Color.themeOrange, Color.themePink], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: Color.themePink.opacity(0.3), radius: 4, y: 2)
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

private enum MoreDestination: Hashable {
    case goals
    case aiCoach
    case profile
}

private struct MoreItem: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let badge: String?
    let accessibilityId: String
    let destination: MoreDestination
}

// MARK: - Navigation Card

private struct MoreCardButtonStyle: ButtonStyle {
    var reduceMotion: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1.0 : 0.96)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct MoreNavCard<Destination: View>: View {
    let item: MoreItem
    var reduceMotion: Bool = false
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
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
                    Text(LocalizedStringKey(item.title))
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(LocalizedStringKey(item.subtitle))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(item.gradient.first ?? .secondary)
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
        }
        .buttonStyle(MoreCardButtonStyle(reduceMotion: reduceMotion))
        .accessibilityIdentifier(item.accessibilityId)
    }
}
