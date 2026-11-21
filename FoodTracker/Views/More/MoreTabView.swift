import SwiftUI
import SwiftData

// MARK: - AI Coach Hub (Apple HIG HUD Standard with Boris Typed Navigation & ReduceMotion)

struct MoreTabView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query private var users: [User]
    @Query(sort: \WeightLog.date, order: .forward) private var weightLogs: [WeightLog]
    @AppStorage("useMetricSystem") private var useMetricSystem = true

    @State private var appearedItems: Set<Int> = []

    private var user: User? { users.first }
    private var currentWeight: Double { weightLogs.last?.weight ?? user?.weight ?? 0.0 }
    
    private var todaySummary: DailySummary? {
        let start = Calendar.current.startOfDay(for: Date())
        guard let end = Calendar.current.date(byAdding: .day, value: 1, to: start) else { return nil }
        var descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
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

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header Greeting
                        headerSection
                            .padding(.top, 4)

                        // 1. Proactive AI Coach Command Hero Card
                        aiCoachHeroCard
                            .padding(.horizontal)

                        // 2. Navigation Section (Goals, Full AI Lab, Profile)
                        VStack(spacing: 14) {
                            ForEach(Array(moreItems.enumerated()), id: \.element.id) { index, item in
                                MoreNavCard(item: item, reduceMotion: reduceMotion) {
                                    destinationView(for: item.destination)
                                }
                                .opacity(reduceMotion || appearedItems.contains(index) ? 1 : 0)
                                .offset(y: (reduceMotion || appearedItems.contains(index)) ? 0 : 20)
                                .animation(
                                    reduceMotion
                                        ? nil
                                        : .spring(response: 0.45, dampingFraction: 0.75)
                                            .delay(Double(index) * 0.06),
                                    value: appearedItems.contains(index)
                                )
                            }
                        }
                        .padding(.horizontal)

                        // 3. Visual Progress Section (Before/After Photo comparison)
                        BeforeAfterView()
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .opacity(reduceMotion || appearedItems.count >= moreItems.count ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeIn(duration: 0.4).delay(0.2), value: appearedItems.count)

                        // 4. Cross-Promo Companion Banner
                        crossPromoBanner
                            .padding(.horizontal)
                            .padding(.top, 4)
                            .opacity(reduceMotion || appearedItems.count >= moreItems.count ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeIn(duration: 0.4).delay(0.25), value: appearedItems.count)

                        // App Info Footer
                        footerSection
                            .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            guard appearedItems.isEmpty else { return }
            if reduceMotion {
                appearedItems = Set(moreItems.indices)
                return
            }
            for i in 0..<moreItems.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.06) {
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

    // MARK: - Proactive AI Coach Hero Card
    private var aiCoachHeroCard: some View {
        let summary = todaySummary
        let cals = summary?.totalCalories ?? 0
        let goal = user?.dailyCaloriesGoal ?? 2000
        let protein = summary?.totalProtein ?? 0
        let proteinGoal = user?.targetProtein ?? 0
        
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.65, green: 0.55, blue: 0.95).opacity(0.18))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color(red: 0.65, green: 0.55, blue: 0.95))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Daily Nutrition Insight"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    
                    Text(String(localized: "Proactive analysis of your diet & metabolism"))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
                
                Spacer()
            }
            
            // Micro Stats Chips
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(cals > goal ? Color.red : Color(red: 0.16, green: 0.72, blue: 0.50))
                        .frame(width: 6, height: 6)
                    Text("\(cals) / \(goal) kcal")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(red: 0.16, green: 0.72, blue: 0.50))
                        .frame(width: 6, height: 6)
                    Text("\(Int(protein)) / \(Int(proteinGoal))g Protein")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
                
                Spacer()
            }
            
            // 1-Tap Direct Chat Navigation Link
            NavigationLink(destination: AICoachChatView(
                userGoal: user?.dailyCaloriesGoal ?? 2000,
                consumed: summary?.totalCalories ?? 0,
                activeDiet: user?.activeDietPlan?.name ?? String(localized: "Balanced"),
                consumedProtein: summary?.totalProtein ?? 0,
                targetProtein: user?.targetProtein ?? 0,
                consumedFats: summary?.totalFats ?? 0,
                targetFats: user?.targetFats ?? 0,
                consumedCarbs: summary?.totalCarbs ?? 0,
                targetCarbs: user?.targetCarbs ?? 0,
                hydrationLiters: summary?.totalHydrationLiters ?? 0,
                activeCaloriesBurned: summary?.activeCaloriesBurned ?? 0
            )) {
                HStack {
                    Image(systemName: "message.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(String(localized: "Consult with AI Coach"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(themeManager.current.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(HUDSpringScaleButtonStyle(reduceMotion: reduceMotion))
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(themeManager.current.primaryAccent.opacity(0.22), lineWidth: 1.2)
                )
                .shadow(color: themeManager.current.primaryAccent.opacity(0.08), radius: 12, y: 4)
        }
    }

    // MARK: - Navigation Items Data
    private var moreItems: [MoreItem] {
        [
            MoreItem(
                id: 0,
                title: "Goals & Targets",
                subtitle: weightLogs.isEmpty
                    ? "Set your target weight & macros"
                    : String(localized: "Current: \(NutritionMath.formattedWeight(currentWeight, useMetric: useMetricSystem))"),
                icon: "target",
                color: Color(red: 0.95, green: 0.55, blue: 0.25),
                accessibilityId: "more_goals_card",
                destination: .goals
            ),
            MoreItem(
                id: 1,
                title: "AI Coach Dashboard",
                subtitle: "Full metabolic diagnostics & tips",
                icon: "waveform.path.ecg",
                color: Color(red: 0.65, green: 0.55, blue: 0.95),
                accessibilityId: "more_coach_card",
                destination: .aiCoach
            ),
            MoreItem(
                id: 2,
                title: "Profile & Settings",
                subtitle: user.map { String(localized: "Account of \($0.name)") } ?? "Preferences & HealthKit",
                icon: "person.crop.circle.fill",
                color: Color(red: 0.35, green: 0.65, blue: 0.95),
                accessibilityId: "more_profile_card",
                destination: .profile
            )
        ]
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(user?.name ?? "Champion")
                    .font(.system(size: 26, weight: .black, design: .rounded))
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

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 4) {
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

    // MARK: - Cross Promo
    private var crossPromoBanner: some View {
        Button(action: {
            TrackingManager.shared.track(.crossPromoTapped(app: "workout_tracker"))
            CrossAppLinkResolver.openWorkoutTracker()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.primary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Workout Tracker")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("Track sets, workouts & active burn")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer(minLength: 0)
                
                HStack(spacing: 4) {
                    Text("Open")
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .clipShape(Capsule())
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(HUDSpringScaleButtonStyle(reduceMotion: reduceMotion))
    }
}

// MARK: - Navigation Item Model & Card
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
    let color: Color
    let accessibilityId: String
    let destination: MoreDestination
}

private struct MoreNavCard<Destination: View>: View {
    let item: MoreItem
    var reduceMotion: Bool = false
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [item.color, item.color.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: item.color.opacity(0.35), radius: 8, y: 4)

                    Image(systemName: item.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(item.title))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(LocalizedStringKey(item.subtitle))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(item.color)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(item.color.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
            }
        }
        .buttonStyle(HUDSpringScaleButtonStyle(reduceMotion: reduceMotion))
        .accessibilityIdentifier(item.accessibilityId)
    }
}

private struct HUDSpringScaleButtonStyle: ButtonStyle {
    var reduceMotion: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1.0 : 0.96)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
