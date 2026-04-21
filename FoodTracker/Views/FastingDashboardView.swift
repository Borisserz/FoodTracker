import SwiftUI
enum FastingCategory: String, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case expert = "expert"

    var localizedName: String {
        switch self {
        case .beginner: return String(localized: "Beginner")
        case .intermediate: return String(localized: "Intermediate")
        case .expert: return String(localized: "Expert")
        }
    }
}

struct FastingBenefit: Hashable {
    let icon: String
    let text: String
}

struct FastingPlan: Identifiable, Hashable {
    let id = UUID()
    let category: FastingCategory
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isPopular: Bool
    var eatingFraction: Double { Double(eatingHours) / 24.0 }
    let fastingHours: Int
    let eatingHours: Int

    let difficultyRating: Int
    let benefits: [FastingBenefit]
    let breakFastTip: String

    static let allPlans: [FastingPlan] = [

        FastingPlan(category: .beginner, title: "12:12", description: String(localized: "Circadian rhythm fast. Great for beginners."), icon: "sun.and.horizon.fill", color: .cyan, isPopular: false, fastingHours: 12, eatingHours: 12,
                    difficultyRating: 1,
                    benefits: [FastingBenefit(icon: "moon.zzz.fill", text: String(localized: "Better Sleep")), FastingBenefit(icon: "brain.head.profile", text: String(localized: "Mental Clarity"))],
                    breakFastTip: String(localized: "A simple balanced breakfast like eggs and avocado is perfect.")),

        FastingPlan(category: .beginner, title: "14:10", description: String(localized: "Ease your way into fasting. Burns fat smoothly."), icon: "leaf.fill", color: .green, isPopular: false, fastingHours: 14, eatingHours: 10,
                    difficultyRating: 2,
                    benefits: [FastingBenefit(icon: "flame.fill", text: String(localized: "Light Fat Burn")), FastingBenefit(icon: "heart.fill", text: String(localized: "Heart Health"))],
                    breakFastTip: String(localized: "Oatmeal with berries or a protein smoothie will keep you energized.")),

        FastingPlan(category: .beginner, title: "16:8", description: String(localized: "The golden standard of fasting. Perfect for fat loss."), icon: "flame.fill", color: .themePink, isPopular: true, fastingHours: 16, eatingHours: 8,
                    difficultyRating: 3,
                    benefits: [FastingBenefit(icon: "flame.fill", text: String(localized: "Deep Fat Burn")), FastingBenefit(icon: "bolt.fill", text: String(localized: "Energy Boost")), FastingBenefit(icon: "arrow.down.right.circle.fill", text: String(localized: "Insulin Drop")), FastingBenefit(icon: "figure.walk", text: String(localized: "Weight Loss"))],
                    breakFastTip: String(localized: "Break it with lean protein (chicken/fish) and veggies. Avoid heavy carbs immediately.")),

        FastingPlan(category: .intermediate, title: "18:6", description: String(localized: "Less flexibility, for experienced users."), icon: "target", color: .themeOrange, isPopular: false, fastingHours: 18, eatingHours: 6,
                    difficultyRating: 3,
                    benefits: [FastingBenefit(icon: "flame.fill", text: String(localized: "Max Fat Burn")), FastingBenefit(icon: "drop.fill", text: String(localized: "Autophagy Starts"))],
                    breakFastTip: String(localized: "Start with a small portion of easily digestible food, wait 30 mins, then eat a full meal.")),

        FastingPlan(category: .intermediate, title: "20:4", description: String(localized: "The Warrior Diet. 1-2 meals in a tight window."), icon: "shield.fill", color: .red, isPopular: false, fastingHours: 20, eatingHours: 4,
                    difficultyRating: 4,
                    benefits: [FastingBenefit(icon: "shield.fill", text: String(localized: "Immunity Boost")), FastingBenefit(icon: "brain", text: String(localized: "Laser Focus"))],
                    breakFastTip: String(localized: "Bone broth or a light salad first. Your digestive system is asleep, wake it up gently.")),

        FastingPlan(category: .intermediate, title: "Alternate Day", description: String(localized: "One day on, one day off. Breaks plateaus."), icon: "arrow.triangle.2.circlepath", color: .indigo, isPopular: false, fastingHours: 24, eatingHours: 24,
                    difficultyRating: 4,
                    benefits: [FastingBenefit(icon: "chart.line.downtrend.xyaxis", text: String(localized: "Breaks Plateaus")), FastingBenefit(icon: "clock.arrow.2.circlepath", text: String(localized: "Anti-Aging"))],
                    breakFastTip: String(localized: "Focus heavily on hydration and electrolytes on your fasting days.")),

        FastingPlan(category: .expert, title: "23:1 (OMAD)", description: String(localized: "One Meal A Day. Extreme fat burn and repair."), icon: "crown.fill", color: .themeYellow, isPopular: false, fastingHours: 23, eatingHours: 1,
                    difficultyRating: 5,
                    benefits: [FastingBenefit(icon: "crown.fill", text: String(localized: "Ultimate Discipline")), FastingBenefit(icon: "cell.cell", text: String(localized: "Deep Autophagy")), FastingBenefit(icon: "flame.fill", text: String(localized: "Rapid Fat Loss"))],
                    breakFastTip: String(localized: "Eat a massive, nutrient-dense meal. Make sure to hit your daily protein and fat macros in this window!")),

        FastingPlan(category: .expert, title: "36-Hour", description: String(localized: "Monk Fast. Full day water fast for a reset."), icon: "drop.fill", color: .purple, isPopular: false, fastingHours: 36, eatingHours: 0,
                    difficultyRating: 5,
                    benefits: [FastingBenefit(icon: "arrow.triangle.2.circlepath", text: String(localized: "Full Reset")), FastingBenefit(icon: "cross.case.fill", text: String(localized: "Cellular Repair"))],
                    breakFastTip: String(localized: "DANGER: Do not break with heavy carbs. Start with bone broth, wait an hour, eat steamed veggies and fish.")),

        FastingPlan(category: .expert, title: "5:2 Diet", description: String(localized: "5 normal days, 2 days under 500 kcal."), icon: "calendar.badge.minus", color: .mint, isPopular: false, fastingHours: 48, eatingHours: 0,
                    difficultyRating: 4,
                    benefits: [FastingBenefit(icon: "calendar", text: String(localized: "Weekly Balance")), FastingBenefit(icon: "scale.3d", text: String(localized: "Steady Loss"))],
                    breakFastTip: String(localized: "On your 500 kcal days, focus entirely on lean protein and leafy greens to stay full."))
    ]
}

struct FastingDashboardView: View {
    @State private var path = NavigationPath()

    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fasting Protocols")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)

                        Text("Choose a schedule to optimize your metabolism and reach your goals faster.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    ForEach(FastingCategory.allCases, id: \.self) { category in
                        FastingCategorySection(category: category)
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FastingCategorySection: View {
    let category: FastingCategory

    var plans: [FastingPlan] {
        FastingPlan.allPlans.filter { $0.category == category }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Text(category.localizedName)
                    .font(.title2).bold()

                Rectangle()
                    .fill(LinearGradient(colors: [.gray.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 2)
            }
            .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(plans) { plan in
                        NavigationLink(destination: PremiumFastingDetailView(plan: plan)) {
                            PremiumFastingCard(plan: plan)
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}

struct PremiumFastingCard: View {
    let plan: FastingPlan

    var body: some View {
        VStack(spacing: 0) {

            ZStack {
                LinearGradient(
                    colors: [plan.color, plan.color.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: plan.icon)
                    .font(.system(size: 70))
                    .foregroundStyle(.white.opacity(0.2))
                    .blur(radius: 2)
                    .offset(x: -10, y: 15)

                Image(systemName: plan.icon)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
            }
            .frame(height: 120)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(plan.title)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)

                    Spacer()

                    if plan.isPopular {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                            Text("POPULAR")
                        }
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(plan.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(plan.color.opacity(0.15))
                        .clipShape(Capsule())
                    } else if plan.category == .expert {
                        Text("EXPERT")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(plan.description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(width: 170, height: 230)
        .background(Color.white)
        .cornerRadius(28)
        .shadow(color: plan.color.opacity(0.15), radius: 15, y: 8)
    }
}

struct PremiumFastingDetailView: View {
    let plan: FastingPlan
    @Environment(\.dismiss) var dismiss

    @State private var animateRing = false

    var dynamicTimeline: [(hour: String, title: String, desc: String, color: Color)] {
        var events: [(String, String, String, Color)] = []
        events.append(("4h", "Blood Sugar Normalizes", "Insulin levels drop and your body stops storing fat.", .themeYellow))
        events.append(("8h", "Fat Burning Begins", "Glycogen stores are depleted. You switch to fat for fuel.", .themeOrange))
        if plan.fastingHours >= 12 { events.append(("12h", "Ketosis State", "Your liver starts producing ketones for brain energy.", .themePink)) }
        if plan.fastingHours >= 16 { events.append(("16h", "Autophagy Starts", "Cellular repair begins. Old cells are recycled.", .blue)) }
        if plan.fastingHours >= 24 { events.append(("24h", "Intestinal Stem Cells", "Gut repair begins. Inflammation drops drastically.", .green)) }
        return events
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.themeBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    GeometryReader { geo in
                        let minY = geo.frame(in: .global).minY
                        let isScrollingDown = minY > 0

                        ZStack(alignment: .bottomLeading) {
                            LinearGradient(
                                colors: [plan.color.opacity(0.8), plan.color.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(height: isScrollingDown ? 380 + minY : 380)
                            .offset(y: isScrollingDown ? -minY : 0)

                            Image(systemName: plan.icon)
                                .font(.system(size: 180))
                                .foregroundColor(.white.opacity(0.15))
                                .offset(x: 150, y: -20)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(plan.category.rawValue.uppercased())
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .tracking(2)

                                Text(plan.title)
                                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)

                                HStack(spacing: 4) {
                                    Text("Difficulty:").font(.caption.bold()).foregroundColor(.white.opacity(0.8))
                                    ForEach(0..<5) { i in
                                        Image(systemName: "flame.fill")
                                            .font(.caption)
                                            .foregroundColor(i < plan.difficultyRating ? .white : .white.opacity(0.3))
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(24)
                            .padding(.bottom, 60)
                            .offset(y: isScrollingDown ? -minY * 0.5 : 0)
                        }
                    }
                    .frame(height: 380)

                    VStack(spacing: 24) {

                        if plan.fastingHours > 0 && plan.fastingHours < 48 {
                            HStack(spacing: 20) {
                                ZStack {
                                    Circle().stroke(Color.gray.opacity(0.15), lineWidth: 12)
                                    Circle()
                                        .trim(from: 0, to: animateRing ? plan.eatingFraction : 0)
                                        .stroke(plan.color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                        .shadow(color: plan.color.opacity(0.4), radius: 5, y: 2)

                                    Image(systemName: "clock.fill")
                                        .font(.title)
                                        .foregroundColor(plan.color)
                                }
                                .frame(width: 80, height: 80)

                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 8, height: 8)
                                        Text("\(plan.fastingHours) Hours Fasting").font(.subheadline.bold())
                                    }
                                    HStack {
                                        Circle().fill(plan.color).frame(width: 8, height: 8)
                                        Text("\(plan.eatingHours) Hours Eating").font(.subheadline.bold())
                                    }
                                }
                                Spacer()
                            }
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(24)
                            .shadow(color: Color.black.opacity(0.05), radius: 15, y: 5)
                            .offset(y: -50)
                            .padding(.horizontal, 24)
                            .padding(.bottom, -30)
                        }

                        Text(plan.description)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .lineSpacing(6)
                            .foregroundColor(.primary.opacity(0.8))
                            .padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Key Benefits")
                                .font(.title3.bold())

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(plan.benefits, id: \.text) { benefit in
                                    HStack(spacing: 8) {
                                        Image(systemName: benefit.icon)
                                            .foregroundColor(plan.color)
                                        Text(benefit.text)
                                            .font(.caption.bold())
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color.white)
                                    .cornerRadius(16)
                                    .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        if plan.category == .beginner {
                            AllowedDrinksSection(color: plan.color)
                        } else if plan.category == .expert {
                            ExpertSafetyWarning(color: plan.color)
                        }

                        if plan.fastingHours >= 12 {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("What happens to your body?")
                                    .font(.title2).bold()
                                    .padding(.horizontal, 24)
                                    .padding(.top, 10)

                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(Array(dynamicTimeline.enumerated()), id: \.offset) { index, event in
                                        FastingTimelineRow(
                                            hour: event.hour,
                                            title: event.title,
                                            desc: event.desc,
                                            color: event.color,
                                            isFirst: index == 0,
                                            isLast: index == dynamicTimeline.count - 1
                                        )
                                    }
                                }
                                .padding(24)
                                .background(Color.white)
                                .cornerRadius(28)
                                .shadow(color: Color.black.opacity(0.03), radius: 15, y: 8)
                                .padding(.horizontal, 24)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.themeOrange)
                                Text("How to break this fast")
                                    .font(.headline)
                            }

                            Text(plan.breakFastTip)
                                .font(.subheadline)
                                .foregroundColor(.primary.opacity(0.8))
                                .lineSpacing(4)
                        }
                        .padding(20)
                        .background(Color.themeOrange.opacity(0.1))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.themeOrange.opacity(0.3), lineWidth: 1))
                        .padding(.horizontal, 24)

                        Spacer().frame(height: 120)
                    }
                    .background(Color.themeBg)
                }
            }
            .ignoresSafeArea(edges: .top)

            VStack {
                Spacer()
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .frame(height: 110)
                        .mask(LinearGradient(colors: [.white, .white, .clear], startPoint: .bottom, endPoint: .top))

                    Button(action: {
                        HapticManager.shared.impact(style: .heavy)

                        FastingManager.shared.startFast(plan: plan)

                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "timer")
                            Text("Start \(plan.title) Protocol")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(LinearGradient(colors: [plan.color.opacity(0.8), plan.color], startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(24)
                        .shadow(color: plan.color.opacity(0.4), radius: 10, y: 5)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 30)
                    }
                    .buttonStyle(BounceButtonStyle())
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .overlay(
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
            }
            .padding(.leading, 20)
            .padding(.top, 50),
            alignment: .topLeading
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 1.2, dampingFraction: 0.8)) {
                    animateRing = true
                }
            }
        }
    }
}

struct AllowedDrinksSection: View {
    let color: Color

    let drinks = [
        ("Water", "drop.fill", Color.cyan),
        ("Black Coffee", "cup.and.saucer.fill", Color.brown),
        ("Green Tea", "leaf.fill", Color.green)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Allowed During Fast")
                .font(.title3.bold())
                .padding(.horizontal, 24)

            HStack(spacing: 12) {
                ForEach(drinks, id: \.0) { drink in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle().fill(drink.2.opacity(0.15)).frame(width: 50, height: 50)
                            Image(systemName: drink.1).font(.title2).foregroundColor(drink.2)
                        }
                        Text(drink.0).font(.caption.bold()).foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
                }
            }
            .padding(.horizontal, 24)
        }
    }
}

struct ExpertSafetyWarning: View {
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.red)
                Text("Expert Protocol Warning")
                    .font(.headline)
                    .foregroundColor(.red)
            }

            Text("Extended fasting depletes essential minerals. You MUST consume electrolytes (Sodium, Potassium, Magnesium) dissolved in water to avoid headaches, cramps, and heart palpitations.")
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.9))
                .lineSpacing(4)

            HStack {
                Label("Sodium", systemImage: "n.circle.fill")
                Spacer()
                Label("Potassium", systemImage: "p.circle.fill")
                Spacer()
                Label("Magnesium", systemImage: "m.circle.fill")
            }
            .font(.caption.bold())
            .foregroundColor(.gray)
            .padding(.top, 8)
        }
        .padding(20)
        .background(Color.red.opacity(0.05))
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.red.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 24)
    }
}

struct FastingTimelineRow: View {
    let hour: String; let title: String; let desc: String; let color: Color
    var isFirst: Bool = false
    var isLast: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Rectangle().fill(isFirst ? Color.clear : Color.gray.opacity(0.2)).frame(width: 2, height: 16)
                ZStack {
                    Circle().fill(color.opacity(0.2)).frame(width: 24, height: 24)
                    Circle().fill(color).frame(width: 10, height: 10)
                }
                Rectangle().fill(isLast ? Color.clear : Color.gray.opacity(0.2)).frame(width: 2)
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(hour).font(.system(size: 16, weight: .black, design: .rounded)).foregroundColor(color)
                    Text(title).font(.headline).foregroundColor(.primary)
                }
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineSpacing(2)
                    .padding(.bottom, isLast ? 0 : 24)
            }
            .padding(.top, 14)
        }
    }
}

struct ActiveFastingCard: View {
    var manager = FastingManager.shared
    @State private var showEndAlert = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Fast: \(manager.planName)")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        Image(systemName: manager.currentPhase.icon)
                        Text(manager.currentPhase.name)
                    }
                    .font(.caption.bold())
                    .foregroundColor(manager.currentPhase.color)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(manager.currentPhase.color.opacity(0.15))
                    .clipShape(Capsule())
                }
                Spacer()

                ZStack {
                    Circle().stroke(Color.gray.opacity(0.15), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: manager.progress)
                        .stroke(manager.currentPhase.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: manager.progress)

                    Text("\(Int(manager.progress * 100))%")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .frame(width: 50, height: 50)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(manager.elapsedTimeString)
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())
                Spacer()
            }

            HStack {
                Text(manager.remainingTimeString)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Spacer()

                Button(action: { showEndAlert = true }) {
                    Text("End Fast")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.red)
                        .clipShape(Capsule())
                        .shadow(color: .red.opacity(0.3), radius: 5, y: 2)
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: manager.currentPhase.color.opacity(0.15), radius: 15, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(manager.currentPhase.color.opacity(0.3), lineWidth: 2)
                .opacity(manager.progress >= 1.0 ? 1 : 0)
                .animation(.easeInOut(duration: 1).repeatForever(), value: manager.progress >= 1.0)
        )
        .alert("End Fast?", isPresented: $showEndAlert) {
            Button("Cancel", role: .cancel) { }
            Button("End Fast", role: .destructive) {
                manager.endFast()
            }
        } message: {
            Text("Are you sure you want to break your fast? You've done great so far!")
        }
    }
}
