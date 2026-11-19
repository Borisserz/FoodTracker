import SwiftUI
import SwiftData

enum DailyXPQuestsEvaluator {
    enum QuestType {
        case steps
        case meals
        case water
    }

    static func isQuestSatisfied(_ quest: QuestType, summary: DailySummary?) -> Bool {
        guard let summary else { return false }
        switch quest {
        case .steps:
            return summary.stepsCount >= 10_000
        case .meals:
            return !(summary.meals ?? []).isEmpty
        case .water:
            return summary.totalHydrationLiters >= 2.499
        }
    }
}

// MARK: - Daily Quests & Gold Master XP Progress Card
struct DailyXPQuestsCardView: View {
    @Environment(\.modelContext) private var context
    @Bindable var user: User
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]

    @AppStorage("useMetricSystem") private var useMetricSystem: Bool = true

    private var todayKey: String {
        NutritionMath.dayKey(for: Date())
    }

    private var todaySummary: DailySummary? {
        summaries.first(where: { Calendar.current.isDateInToday($0.date) })
    }

    @AppStorage("dailyQuestClaimed_v1") private var questClaimedRaw: String = ""

    private var claimedQuestIDs: Set<String> {
        let prefix = "\(todayKey):"
        guard questClaimedRaw.hasPrefix(prefix) else { return [] }
        return Set(questClaimedRaw.dropFirst(prefix.count).split(separator: ",").map(String.init))
    }

    private func isClaimed(_ id: String) -> Bool {
        claimedQuestIDs.contains(id)
    }

    private func claimQuestXP(_ amount: Int, id: String, satisfied: Bool) {
        guard satisfied else {
            HapticManager.shared.notification(type: .warning)
            return
        }
        var claimed = claimedQuestIDs
        guard !claimed.contains(id) else { return }
        claimed.insert(id)
        questClaimedRaw = "\(todayKey):\(claimed.sorted().joined(separator: ","))"
        addXP(amount)
    }

    private var progressManager: NutritionProgressManager {
        NutritionProgressManager(user: user)
    }

    var currentXP: Int {
        user.totalXP
    }

    var nextLevelXP: Int {
        progressManager.xpToNextLevel
    }

    var xpProgressRatio: Double {
        max(progressManager.progressPercentage, 0.08)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Gold Master Rank Badge Header
            HStack(spacing: 16) {
                // Circular Gold Level Emblem
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 5)
                        .frame(width: 64, height: 64)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(xpProgressRatio))
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.84, blue: 0.1), Color(red: 1.0, green: 0.65, blue: 0.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 0) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.0))
                        
                        Text("LVL \(user.level)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.primary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("MASTER RANK")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.0))
                    
                    Text(user.name.isEmpty ? String(localized: "Athlete") : user.name)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.primary)
                    
                    HStack(spacing: 4) {
                        Text("\(currentXP)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.0))
                        Text("/ \(nextLevelXP) XP")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.secondary)
                    }
                }
                
                Spacer()
            }
            
            Divider()
            
            // Daily Quests Checklist
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("DAILY QUESTS")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                    
                    Spacer()
                    
                    Text("Up to +400 XP")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.0))
                }
                
                let stepsSatisfied = DailyXPQuestsEvaluator.isQuestSatisfied(.steps, summary: todaySummary)
                XPQuestRow(
                    icon: "figure.walk",
                    title: String(localized: "Walk 10,000 steps"),
                    xp: 150,
                    isSatisfied: stepsSatisfied,
                    isClaimed: isClaimed("steps")
                ) {
                    claimQuestXP(150, id: "steps", satisfied: stepsSatisfied)
                }
                
                let mealsSatisfied = DailyXPQuestsEvaluator.isQuestSatisfied(.meals, summary: todaySummary)
                XPQuestRow(
                    icon: "fork.knife",
                    title: String(localized: "Log all meals"),
                    xp: 100,
                    isSatisfied: mealsSatisfied,
                    isClaimed: isClaimed("meals")
                ) {
                    claimQuestXP(100, id: "meals", satisfied: mealsSatisfied)
                }
                
                let waterSatisfied = DailyXPQuestsEvaluator.isQuestSatisfied(.water, summary: todaySummary)
                XPQuestRow(
                    icon: "drop.fill",
                    title: useMetricSystem
                        ? String(localized: "Drink 2.5L of water")
                        : String(localized: "Drink 85 fl oz of water"),
                    xp: 150,
                    isSatisfied: waterSatisfied,
                    isClaimed: isClaimed("water")
                ) {
                    claimQuestXP(150, id: "water", satisfied: waterSatisfied)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color(red: 1.0, green: 0.82, blue: 0.0).opacity(0.25), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 15, y: 6)
        .onAppear {
            progressManager.syncLevel()
        }
    }
    
    private func addXP(_ amount: Int) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            let breakdown = NutritionXPBreakdown(
                baseXP: amount,
                proteinGoalXP: 0,
                calorieGoalXP: 0
            )
            let manager = NutritionProgressManager(user: user)
            manager.addXP(from: breakdown)
            try? context.save()
        }
    }
}

// MARK: - Quest Row
private struct XPQuestRow: View {
    let icon: String
    let title: String
    let xp: Int
    let isSatisfied: Bool
    let isClaimed: Bool
    let onClaim: () -> Void
    
    var body: some View {
        Button(action: onClaim) {
            HStack(spacing: 12) {
                Image(systemName: isClaimed ? "checkmark.circle.fill" : (isSatisfied ? "sparkles" : "circle"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isClaimed ? Color.green : (isSatisfied ? Color(red: 1.0, green: 0.72, blue: 0.0) : Color.secondary.opacity(0.4)))
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isClaimed ? Color.primary : Color.secondary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(isClaimed ? Color.secondary : Color.primary)
                    .strikethrough(isClaimed, color: Color.secondary)
                
                Spacer()
                
                Text(isClaimed ? "+\(xp) XP ✓" : (isSatisfied ? String(localized: "Claim +\(xp) XP") : "+\(xp) XP"))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(isClaimed ? Color.green : Color(red: 1.0, green: 0.72, blue: 0.0))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isClaimed ? Color.green.opacity(0.12) : Color(red: 1.0, green: 0.72, blue: 0.0).opacity(isSatisfied ? 0.22 : 0.12))
                    .clipShape(Capsule())
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(UIColor.tertiarySystemGroupedBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
