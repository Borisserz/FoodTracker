import SwiftUI
import UIKit
import Charts

class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

struct MacroBatteryView: View {
    let title: String; let current: Int; let total: Int; let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.caption).foregroundColor(.textGray).bold()
                Spacer()
                let textColor = color == .themeYellow ? Color.themeDarkYellow : color
                Text("\(current)/\(total)g").font(.caption.bold()).foregroundColor(textColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))

                    Capsule()
                        .fill(color)
                        .frame(width: min(geometry.size.width * CGFloat(current) / CGFloat(max(total, 1)), geometry.size.width))
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 10)
        }
    }
}

struct MacroSummaryView: View {
    let protein: Double; let fats: Double; let carbs: Double
    let targetProtein: Double; let targetFats: Double; let targetCarbs: Double

    var body: some View {
        HStack(spacing: 15) {
            MacroBatteryView(title: "Protein", current: Int(protein), total: Int(targetProtein), color: .themePeach)
            MacroBatteryView(title: "Fats", current: Int(fats), total: Int(targetFats), color: .themeYellow)
            MacroBatteryView(title: "Carbs", current: Int(carbs), total: Int(targetCarbs), color: .drinkWater)
        }
    }
}

struct MiniProgressView: View {
    let title: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).bold().foregroundColor(.textGray)

            ProgressView(value: min(max(progress, 0.0), 1.0)).tint(color)
        }
    }
}
struct FoodItemRow: View {
    let name: String
    let weight: String
    let calories: Int

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.themePink.opacity(0.05)).frame(width: 44, height: 44)
                Image(systemName: "fork.knife").foregroundColor(.themePink.opacity(0.6))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline).bold()
                Text(weight).font(.caption).foregroundColor(.textGray)
            }
            Spacer()
            Text("\(calories) kcal").font(.headline).foregroundColor(.themePink)
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color.white)
    }
}

struct EmptyStateView: View {
    let imageName: String
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: imageName).font(.system(size: 48)).foregroundColor(.gray.opacity(0.3))
            Text(title).font(.headline).foregroundColor(.gray)
            Text(description).font(.subheadline).foregroundColor(.textGray.opacity(0.7)).multilineTextAlignment(.center).padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
struct FoodGradeBadge: View {
    let grade: HealthGrade

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: grade.icon)
                .font(.system(size: 10, weight: .bold))
            Text(grade.title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundColor(grade.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(grade.color.opacity(0.15))
        .cornerRadius(8)
    }
}

enum EnergyTab: String, CaseIterable {
    case eaten = "Eaten"
    case burned = "Burned"
    case net = "Net"
}

struct DynamicEnergyDashboard: View {
    let summary: DailySummary
    let summaries: [DailySummary]
    let user: User?

    @State private var selectedTab: EnergyTab = .eaten

    @State private var eatenPage = 0
    @State private var burnedPage = 0
    @State private var netPage = 0

    var body: some View {
        VStack(spacing: 16) {

            HStack(spacing: 8) {
                ForEach(EnergyTab.allCases, id: \.self) { tab in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                    }) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: selectedTab == tab ? .bold : .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedTab == tab ? Color.themePink : Color.white)
                            .foregroundColor(selectedTab == tab ? .white : .gray)
                            .clipShape(Capsule())
                            .shadow(color: selectedTab == tab ? Color.themePink.opacity(0.3) : .black.opacity(0.02), radius: 4, y: 2)
                    }
                }
            }
            .padding(.horizontal, 20)

            Group {
                switch selectedTab {
                case .eaten:
                    VStack(spacing: 12) {
                        TabView(selection: $eatenPage) {
                            EatenRingCard(summary: summary, user: user).tag(0)
                            DetailedMacroRingsCard(summary: summary, user: user).tag(1)
                            MicronutrientsFocusCard(summary: summary).tag(2)
                            MealBreakdownCard(summary: summary).tag(3)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))

                        .frame(height: 440)

                        CustomPaginator(pageCount: 4, currentPage: eatenPage, color: .themePink)
                    }

                case .burned:
                                  VStack(spacing: 12) {
                                      TabView(selection: $burnedPage) {
                                          BurnedRingCard(summary: summary, user: user).tag(0)
                                          BurnedDetailsCard(summary: summary).tag(1)

                                          ActivityIntensityCard(summary: summary).tag(2)
                                          BurnedWeeklyTrendCard(summaries: summaries).tag(3)
                                      }
                                      .tabViewStyle(.page(indexDisplayMode: .never))
                                      .frame(height: 440)

                                      CustomPaginator(pageCount: 4, currentPage: burnedPage, color: .themeOrange)
                                  }

                              case .net:
                                  VStack(spacing: 12) {
                                      TabView(selection: $netPage) {
                                          NetRingCard(summary: summary, user: user).tag(0)
                                          NetDetailsCard(summary: summary).tag(1)

                                          WeeklyEnergyBankCard(summaries: summaries, user: user).tag(2)
                                          NetGoalImpactCard(summary: summary, user: user).tag(3)
                                      }
                                      .tabViewStyle(.page(indexDisplayMode: .never))
                                      .frame(height: 440)

                                      CustomPaginator(pageCount: 4, currentPage: netPage, color: .green)
                                  }
                              }
                          }
                          .animation(.easeInOut(duration: 0.3), value: selectedTab)
        }
    }
}

struct CustomPaginator: View {
    let pageCount: Int
    let currentPage: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? color : Color.gray.opacity(0.3))
                    .frame(width: currentPage == index ? 8 : 6, height: currentPage == index ? 8 : 6)
                    .animation(.spring(), value: currentPage)
            }
        }
    }
}

struct BurnedDetailsCard: View {
    let summary: DailySummary

    var appWorkoutCalories: Int {
        summary.workoutCalories
    }

    var stepCalories: Int {
        Int(Double(summary.stepsCount) * 0.04)
    }

    var appleFitnessCalories: Int {
        let remainder = summary.activeCaloriesBurned - appWorkoutCalories - stepCalories
        return max(0, remainder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Activity Sources")
                    .font(.headline)
                Spacer()
                Image(systemName: "figure.run.circle.fill")
                    .foregroundColor(.themeOrange)
                    .font(.title2)
            }

            VStack(spacing: 0) {

                ActivitySourceRow(
                    icon: "dumbbell.fill",
                    iconColor: .themeOrange,
                    title: "Workouts",
                    subtitle: "Workout Tracker",
                    calories: appWorkoutCalories
                )

                Divider().padding(.leading, 80)

                ActivitySourceRow(
                    icon: "applewatch",
                    iconColor: .themePink,
                    title: "Apple Fitness",
                    subtitle: "System & Other Apps",
                    calories: appleFitnessCalories
                )

                Divider().padding(.leading, 80)

                ActivitySourceRow(
                    icon: "figure.walk",
                    iconColor: .green,
                    title: "Daily Activity",
                    subtitle: "\(summary.stepsCount) steps",
                    calories: stepCalories
                )
            }
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.gray.opacity(0.08), lineWidth: 1))

            Spacer(minLength: 0)

            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 36, height: 36)
                    Image(systemName: "flame.fill").foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Every Movement Counts!")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("All your steps, gym sessions, and Apple Watch workouts are synced here perfectly.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
            }
            .padding(16)
            .background(LinearGradient(colors: [.themeOrange, .red.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(20)
            .shadow(color: Color.themeOrange.opacity(0.3), radius: 8, y: 4)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal, 16)
    }
}

struct BurnedWeeklyTrendCard: View {
    let summaries: [DailySummary]

    private var chartData: [(day: String, calories: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var data: [(String, Int)] = []
        let formatter = DateFormatter(); formatter.dateFormat = "EEE"

        for i in (0..<7).reversed() {
            let date = cal.date(byAdding: .day, value: -i, to: today)!
            let dayName = formatter.string(from: date)
            let dailySum = summaries.first(where: { cal.isDate($0.date, inSameDayAs: date) })
            data.append((dayName, dailySum?.activeCaloriesBurned ?? 0))
        }
        return data
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("7-Day Burn Trend")
                    .font(.headline)
                Spacer()
                Image(systemName: "chart.bar.xaxis")
                    .foregroundColor(.themeOrange)
                    .font(.title2)
            }

            Chart {
                ForEach(chartData, id: \.day) { point in
                    BarMark(
                        x: .value("Day", point.day),
                        y: .value("Calories", point.calories),
                        width: .fixed(20)
                    )
                    .foregroundStyle(LinearGradient(colors: [.themeOrange, .themePink], startPoint: .bottom, endPoint: .top))
                    .cornerRadius(6)
                }
            }
            .frame(height: 200)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel().foregroundStyle(Color.gray).font(.caption2.bold())
                }
            }

            Spacer(minLength: 0)

            let avg = chartData.map { $0.calories }.reduce(0, +) / 7
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Average")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(avg)")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.themeOrange)
                        Text("kcal")
                            .font(.subheadline.bold())
                            .foregroundColor(.gray)
                    }
                }
                Spacer()

                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 30))
                    .foregroundColor(.themeOrange.opacity(0.3))
            }
            .padding(16)
            .background(Color.themeOrange.opacity(0.05))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.themeOrange.opacity(0.1), lineWidth: 1))
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal, 20)
    }
}

struct NetDetailsCard: View {
    let summary: DailySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Balance Equation")
                    .font(.headline)
                Spacer()
                Image(systemName: "scale.3d")
                    .foregroundColor(.green)
                    .font(.title2)
            }

            HStack(spacing: 12) {
                EquationBlock(title: "Eaten", value: summary.totalCalories, color: .themePink, icon: "fork.knife")
                Text("–").font(.title.bold()).foregroundColor(.gray.opacity(0.3))
                EquationBlock(title: "Burned", value: summary.activeCaloriesBurned, color: .themeOrange, icon: "flame.fill")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Visual Balance").font(.caption.bold()).foregroundColor(.gray)
                    Spacer()
                    Text("Net: \(summary.netCalories) kcal").font(.caption.bold()).foregroundColor(summary.netCalories > 0 ? .primary : .green)
                }

                GeometryReader { geo in
                    let total = max(Double(summary.totalCalories + summary.activeCaloriesBurned), 1.0)
                    let eatenWidth = geo.size.width * (Double(summary.totalCalories) / total)
                    let burnedWidth = geo.size.width * (Double(summary.activeCaloriesBurned) / total)

                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.gray.opacity(0.1))

                        Capsule()
                            .fill(Color.themePink)
                            .frame(width: eatenWidth)

                        Capsule()
                            .fill(Color.themeOrange.opacity(0.8))
                            .frame(width: burnedWidth)
                            .offset(x: geo.size.width - burnedWidth)
                    }
                }
                .frame(height: 16)
            }
            .padding(.vertical, 10)

            Spacer(minLength: 0)

            HStack {
                Image(systemName: "info.circle.fill").foregroundColor(.gray.opacity(0.5))
                Text("Your body uses 'Burned' energy to process 'Eaten' food.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal, 20)
    }
}

struct EquationBlock: View {
    let title: String; let value: Int; let color: Color; let icon: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption2)
                Text(title).font(.caption.bold())
            }
            .foregroundColor(color)
            .textCase(.uppercase)

            Text("\(value)")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color.opacity(0.1))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.2), lineWidth: 1))
    }
}

struct NetGoalImpactCard: View {
    let summary: DailySummary
    let user: User?

    var body: some View {
        let goal = user?.dailyCaloriesGoal ?? 2400
        let deficit = goal - summary.netCalories

        let weeklyDeficit = deficit * 7
        let weightChange = Double(weeklyDeficit) / 7700.0

        let isLosing = deficit > 0
        let isMaintaining = deficit == 0
        let statusColor = isLosing ? Color.green : (isMaintaining ? Color.themeYellow : Color.red)

        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Weight Impact")
                    .font(.headline)
                Spacer()
                Image(systemName: "scalemass.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
            }

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: isLosing ? "arrow.down.right" : (isMaintaining ? "minus" : "arrow.up.right"))
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isLosing ? "Weight Loss Zone" : (isMaintaining ? "Maintenance" : "Weight Gain Zone"))
                        .font(.title3.bold())
                        .foregroundColor(.white)

                    Text(isLosing ? "You are in a calorie deficit." : "You are in a calorie surplus.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
            }
            .padding(20)
            .background(
                LinearGradient(colors: [statusColor, statusColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(24)
            .shadow(color: statusColor.opacity(0.3), radius: 10, y: 5)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text("Projected Result")
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(abs(weightChange), specifier: "%.2f")")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("kg")
                            .font(.title3.bold())
                            .foregroundColor(.gray)
                        Text(isLosing ? "lost per week" : "gained per week")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Text("If every day was exactly like today.")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color.white)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal, 20)
    }
}

struct EnergyEquationCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    let isNegative: Bool

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: icon).foregroundColor(color).font(.headline)
            }

            VStack(spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    if isNegative && value > 0 {
                        Text("-")
                            .font(.title3.bold())
                            .foregroundColor(color)
                    }
                    Text("\(value)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(color)
                        .contentTransition(.numericText())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 5)
    }
}
struct DetailedMacroRingsCard: View {
    let summary: DailySummary
    let user: User?

    private var smartInsight: (title: String, text: String, icon: String, color: Color) {
        let p = summary.totalProtein; let targetP = user?.targetProtein ?? 150
        let f = summary.totalFats; let targetF = user?.targetFats ?? 70
        let c = summary.totalCarbs; let targetC = user?.targetCarbs ?? 250

        if summary.totalFoodCalories == 0 {
            return ("Fresh Start", "Log your first meal to see your macro balance.", "leaf.fill", .green)
        } else if p < targetP * 0.4 && summary.totalFoodCalories > 800 {
            return ("Protein Alert", "You are low on protein today. Try adding chicken, eggs, or tofu to your next meal.", "dumbbell.fill", .themePeach)
        } else if f > targetF {
            return ("High Fat", "You've exceeded your daily fat limit. Focus on lean proteins and veggies.", "exclamationmark.triangle.fill", .themeYellow)
        } else if c < targetC * 0.3 {
            return ("Low Energy?", "Your carbs are quite low. Complex carbs like oats or rice can boost your energy.", "bolt.fill", .drinkWater)
        } else {
            return ("Perfect Balance", "Your macros are looking great today! Keep it up.", "checkmark.seal.fill", .themePink)
        }
    }

    var body: some View {
        let targetP = user?.targetProtein ?? 150
        let targetF = user?.targetFats ?? 70
        let targetC = user?.targetCarbs ?? 250

        VStack(spacing: 24) {
            Text("Macronutrients")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 15) {
                IndividualMacroRing(title: "Carbs", current: summary.totalCarbs, target: targetC, color: .drinkWater)
                IndividualMacroRing(title: "Fat", current: summary.totalFats, target: targetF, color: .themeYellow)
                IndividualMacroRing(title: "Protein", current: summary.totalProtein, target: targetP, color: .themePeach)
            }
            .padding(.vertical, 4)

            let insight = smartInsight
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(insight.color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: insight.icon)
                        .foregroundColor(insight.color)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(insight.text)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(16)
            .background(Color.gray.opacity(0.04))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(insight.color.opacity(0.3), lineWidth: 1))

            Spacer(minLength: 0)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal)
    }
}
struct IndividualMacroRing: View {
    let title: String
    let current: Double
    let target: Double
    let color: Color

    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(color)

            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.4), radius: 3, x: 0, y: 0)

                VStack(spacing: 0) {
                    Text("\(Int(current))")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                    Text("/ \(Int(target))g")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 80, height: 80)

            Text("\(Int((current/max(target, 1)) * 100))%")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    progress = current / max(target, 1.0)
                }
            }
        }
    }
}
struct MicronutrientsFocusCard: View {
    let summary: DailySummary

    private var totalOmega3: Double { summary.meals.reduce(0) { $0 + $1.totalOmega3 } }
    private var totalMagnesium: Double { summary.meals.reduce(0) { $0 + $1.totalMagnesium } }
    private var totalCalcium: Double { summary.meals.reduce(0) { $0 + $1.totalCalcium } }
    private var totalIron: Double { summary.meals.reduce(0) { $0 + $1.totalIron } }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Health Focus")
                    .font(.headline)
                Spacer()
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.themePink)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                CompactMicroCard(title: "Omega-3", icon: "fish.fill", current: totalOmega3, target: 1.6, unit: "g", color: .themePink)
                CompactMicroCard(title: "Magnesium", icon: "bolt.heart.fill", current: totalMagnesium, target: 400, unit: "mg", color: .themeYellow)
                CompactMicroCard(title: "Calcium", icon: "bone.fill", current: totalCalcium, target: 1000, unit: "mg", color: .drinkWater)
                CompactMicroCard(title: "Iron", icon: "drop.fill", current: totalIron, target: 18, unit: "mg", color: .red.opacity(0.8))
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Boost your minerals")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text("Add spinach, nuts, or salmon to your next meal to easily hit these goals.")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            .padding(16)
            .background(
                LinearGradient(colors: [.themePink, .themeOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(16)
            .shadow(color: Color.themePink.opacity(0.3), radius: 8, y: 4)

            Spacer(minLength: 0)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal)
    }
}

struct CompactMicroCard: View {
    let title: String
    let icon: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color

    @State private var progress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.gray)
                Spacer()
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(current, specifier: "%.1f")")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                Text("/ \(Int(target)) \(unit)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: min(geo.size.width * CGFloat(progress), geo.size.width))
                }
            }
            .frame(height: 6)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gray.opacity(0.1), lineWidth: 1))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    progress = current / max(target, 1.0)
                }
            }
        }
    }
}
struct MicroProgressBar: View {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color

    @State private var progress: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(current, specifier: "%.1f") / \(Int(target)) \(unit)")
                    .font(.caption)
                    .foregroundColor(.primary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))

                    Capsule()
                        .fill(
                            LinearGradient(colors: [color.opacity(0.6), color], startPoint: .leading, endPoint: .trailing)
                        )
                        .frame(width: min(geo.size.width * CGFloat(progress), geo.size.width))
                        .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 0)
                }
            }
            .frame(height: 12)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    progress = current / max(target, 1.0)
                }
            }
        }
    }
}

struct MealBreakdownCard: View {
    let summary: DailySummary

    @State private var selectedMeal: String = "Breakfast"
    let mealsList = ["Breakfast", "Lunch", "Dinner", "Snack"]

    var body: some View {
        VStack(spacing: 20) {
            Text("Meals Breakdown")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                ForEach(mealsList, id: \.self) { meal in
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedMeal = meal
                        }
                    }) {
                        Text(meal)
                            .font(.system(size: 13, weight: selectedMeal == meal ? .bold : .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedMeal == meal ? Color.themePink : Color.gray.opacity(0.08))
                            .foregroundColor(selectedMeal == meal ? .white : .gray)
                            .clipShape(Capsule())
                            .shadow(color: selectedMeal == meal ? Color.themePink.opacity(0.3) : .clear, radius: 4, y: 2)
                    }
                }
            }

            let currentMealData = summary.meals.first(where: { $0.title == selectedMeal })

            VStack(spacing: 16) {
                MealMacroRow(title: "Calories", value: Double(currentMealData?.totalCalories ?? 0), unit: "kcal", color: .themePink)
                Divider()
                MealMacroRow(title: "Carbs", value: currentMealData?.totalCarbs ?? 0, unit: "g", color: .drinkWater)
                Divider()
                MealMacroRow(title: "Protein", value: currentMealData?.totalProtein ?? 0, unit: "g", color: .themePeach)
                Divider()
                MealMacroRow(title: "Fat", value: currentMealData?.totalFats ?? 0, unit: "g", color: .themeYellow)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.02), radius: 10, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.08), lineWidth: 1)
                    )
            )

            Spacer(minLength: 0)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal)
    }
}

struct MealMacroRow: View {
    let title: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            Spacer()
            Text("\(Int(value)) \(unit)")
                .font(.subheadline.bold())
                .foregroundColor(color)
                .contentTransition(.numericText())
        }
    }
}
struct EatenDetailsCarousel: View {
    let summary: DailySummary
    let user: User?
    @State private var selectedPage = 0

    var body: some View {
        VStack(spacing: 12) {
            TabView(selection: $selectedPage) {
                DetailedMacroRingsCard(summary: summary, user: user).tag(0)
                MicronutrientsFocusCard(summary: summary).tag(1)
                MealBreakdownCard(summary: summary).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 320)

            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(selectedPage == index ? Color.themePink : Color.gray.opacity(0.3))
                        .frame(width: selectedPage == index ? 8 : 6, height: selectedPage == index ? 8 : 6)
                        .animation(.spring(), value: selectedPage)
                }
            }
        }
    }
}

struct EatenRingCard: View {
    let summary: DailySummary
    let user: User?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Energy Summary").font(.headline).foregroundColor(.primary)
                Spacer()
                Image(systemName: "fork.knife").foregroundColor(.themePink).font(.title3)
            }

            EatenCaloriesRing(
                consumed: summary.totalCalories,
                target: user?.dailyCaloriesGoal ?? 2400,
                protein: summary.totalProtein,
                fats: summary.totalFats,
                carbs: summary.totalCarbs
            )

            Spacer(minLength: 0)

            MacroSummaryView(
                protein: summary.totalProtein,
                fats: summary.totalFats,
                carbs: summary.totalCarbs,
                targetProtein: user?.targetProtein ?? 150,
                targetFats: user?.targetFats ?? 70,
                targetCarbs: user?.targetCarbs ?? 250
            )
            .padding(.top, 8)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal, 20)
    }
}

struct BurnedRingCard: View {
    let summary: DailySummary
    let user: User?

    var body: some View {
        let burnTarget = Int(Double(user?.dailyCaloriesGoal ?? 2000) * 0.25)

        VStack(spacing: 16) {
            HStack {
                Text("Active Calories").font(.headline).foregroundColor(.primary)
                Spacer()
                Image(systemName: "flame.fill").foregroundColor(.themeOrange).font(.title3)
            }

            Spacer(minLength: 0)

            BurnedCaloriesRing(
                burned: summary.activeCaloriesBurned,
                targetBurn: max(burnTarget, 300)
            )

            Spacer(minLength: 0)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal, 20)
    }
}

struct NetRingCard: View {
    let summary: DailySummary
    let user: User?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Energy Balance").font(.headline).foregroundColor(.primary)
                Spacer()
                Image(systemName: "scale.3d").foregroundColor(.green).font(.title3)
            }

            Spacer(minLength: 0)

            NetCaloriesRing(
                net: summary.netCalories,
                target: user?.dailyCaloriesGoal ?? 2400
            )

            Spacer(minLength: 0)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal, 20)
    }
}
struct WeeklyEnergyBankCard: View {
    let summaries: [DailySummary]
    let user: User?

    var body: some View {
        let goal = user?.dailyCaloriesGoal ?? 2000
        let last7Days = summaries.prefix(7)
        let totalNet = last7Days.reduce(0) { $0 + $1.netCalories }
        let totalGoal = goal * last7Days.count
        let bankBalance = totalGoal - totalNet

        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Weekly Energy Bank").font(.headline)
                Spacer()
                Image(systemName: "banknote.fill").foregroundColor(.green)
            }

            VStack(spacing: 8) {
                Text("Accumulated Deficit")
                    .font(.caption.bold()).foregroundColor(.gray).textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(bankBalance)")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(bankBalance >= 0 ? .green : .red)
                    Text("kcal").font(.title3.bold()).foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(bankBalance >= 0 ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
            .cornerRadius(24)

            HStack {
                Image(systemName: bankBalance >= 0 ? "arrow.down.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(bankBalance >= 0 ? .green : .red)
                Text(bankBalance >= 0
                     ? "You've saved enough for a 0.5kg weight loss!"
                     : "You've accumulated a surplus this week.")
                    .font(.subheadline).foregroundColor(.gray)
            }

            Spacer(minLength: 0)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal, 20)
    }
}

struct ActivityIntensityCard: View {
    let summary: DailySummary

    var stepCals: Double { Double(summary.stepsCount) * 0.04 }
    var workoutCals: Double { Double(summary.workoutCalories) }
    var appleCals: Double {
        max(0, Double(summary.activeCaloriesBurned) - workoutCals - stepCals)
    }
    var totalActive: Double { Double(max(summary.activeCaloriesBurned, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Burn Intensity").font(.headline)

            HStack(alignment: .bottom, spacing: 20) {
                IntensityBar(title: "Steps", value: stepCals, total: totalActive, color: .green)
                IntensityBar(title: "Apple", value: appleCals, total: totalActive, color: .themePink)
                IntensityBar(title: "Workout", value: workoutCals, total: totalActive, color: .themeOrange)
            }
            .frame(height: 150)
            .padding(.vertical, 10)

            Divider()

            HStack {
                VStack(alignment: .leading) {
                    Text("Main Source").font(.caption).foregroundColor(.gray)

                    let maxVal = max(stepCals, max(appleCals, workoutCals))
                    let sourceName = maxVal == workoutCals ? "Custom Workouts" : (maxVal == appleCals ? "Apple Fitness" : "Daily Walking")

                    Text(sourceName)
                        .font(.headline).foregroundColor(.primary)
                }
                Spacer()
                Text("\(Int((max(stepCals, max(appleCals, workoutCals))/totalActive)*100))% of Total")
                    .font(.caption.bold())
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            Spacer(minLength: 0)
        }
        .ultraPremiumCardStyle()
        .padding(.horizontal, 20)
    }
}

struct IntensityBar: View {
    let title: String; let value: Double; let total: Double; let color: Color
    var body: some View {
        VStack {
            Text("\(Int(value))").font(.caption.bold()).foregroundColor(color)
            GeometryReader { geo in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.gradient)
                        .frame(height: geo.size.height * CGFloat(value / max(total, 1)))
                }
            }
            Text(title).font(.caption2).foregroundColor(.gray)
        }
    }
}
