import SwiftUI

// MARK: - Daily Quests & Gold Master XP Progress Card
struct DailyXPQuestsCardView: View {
    @Bindable var user: User
    
    @State private var quest1Done = true
    @State private var quest2Done = false
    @State private var quest3Done = false
    
    var currentXP: Int {
        user.totalXP
    }
    
    var nextLevelXP: Int {
        user.level * 1000
    }
    
    var xpProgressRatio: Double {
        let currentInLevel = currentXP % 1000
        return min(max(Double(currentInLevel) / 1000.0, 0.08), 1.0)
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
                    
                    Text("\(user.name.isEmpty ? "Атлет" : user.name)")
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
                    Text("КВЕСТЫ ДНЯ")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.secondary)
                    
                    Spacer()
                    
                    Text("Бонус до +400 XP")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.72, blue: 0.0))
                }
                
                XPQuestRow(
                    icon: "figure.walk",
                    title: "Пройти 10,000 шагов",
                    xp: 150,
                    isDone: $quest1Done
                ) {
                    addXP(150)
                }
                
                XPQuestRow(
                    icon: "fork.knife",
                    title: "Записать все приёмы пищи",
                    xp: 100,
                    isDone: $quest2Done
                ) {
                    addXP(100)
                }
                
                XPQuestRow(
                    icon: "drop.fill",
                    title: "Выпить 2.5L воды",
                    xp: 150,
                    isDone: $quest3Done
                ) {
                    addXP(150)
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
    }
    
    private func addXP(_ amount: Int) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            user.totalXP += amount
            if user.totalXP >= nextLevelXP {
                user.level += 1
            }
        }
    }
}

// MARK: - Quest Row
private struct XPQuestRow: View {
    let icon: String
    let title: String
    let xp: Int
    @Binding var isDone: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: {
            isDone.toggle()
            if isDone {
                onToggle()
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isDone ? Color.green : Color.secondary.opacity(0.4))
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(isDone ? Color.primary : Color.secondary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(isDone ? Color.secondary : Color.primary)
                    .strikethrough(isDone, color: Color.secondary)
                
                Spacer()
                
                Text("+\(xp) XP")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(isDone ? Color.green : Color(red: 1.0, green: 0.72, blue: 0.0))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isDone ? Color.green.opacity(0.12) : Color(red: 1.0, green: 0.72, blue: 0.0).opacity(0.12))
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
