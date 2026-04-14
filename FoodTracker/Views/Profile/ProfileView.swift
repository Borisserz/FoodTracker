
import SwiftUI
import Charts
import SwiftData

// MARK: - Analytics View
struct AnalyticsView: View {
    @Query var dailySummaries: [DailySummary]
    
    var weeklyCalories: [(day: String, calories: Int)] {
        let calendar = Calendar.current
        let last7Days = (0..<7).compactMap { offset -> (day: String, calories: Int)? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date.now) else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            
            let calories = dailySummaries
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.totalCalories }
            
            return (day: formatter.string(from: date), calories: calories)
        }
        return last7Days.reversed()
    }
    
    var weeklyWeight: [(day: String, weight: Double)] {
        let calendar = Calendar.current
        let last7Days = (0..<7).compactMap { offset -> (day: String, weight: Double)? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date.now) else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            
            let weight = dailySummaries
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .compactMap { $0.weight }
                .first ?? 0
            
            return weight > 0 ? (day: formatter.string(from: date), weight: weight) : nil
        }
        return last7Days.reversed()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Weekly Analytics")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Calories")
                        .font(.headline)
                    Spacer()
                    Text("Avg: \(Int(weeklyCalories.map { $0.calories }.reduce(0, +) / max(1, weeklyCalories.count)))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if !weeklyCalories.isEmpty {
                    Chart {
                        ForEach(weeklyCalories, id: \.day) { item in
                            BarMark(
                                x: .value("Day", item.day),
                                y: .value("Calories", item.calories)
                            )
                            .foregroundStyle(Color.themePink)
                        }
                    }
                    .frame(height: 150)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                } else {
                    EmptyStateView(
                        imageName: "chart.bar.fill",
                        title: "No Data Yet",
                        description: "Start logging meals to see your calorie trends"
                    )
                    .frame(height: 150)
                }
            }
            .premiumCardStyle()
            
            if !weeklyWeight.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Weight Trend")
                            .font(.headline)
                        Spacer()
                        Text("Avg: \(String(format: "%.1f", weeklyWeight.map { $0.weight }.reduce(0, +) / Double(max(1, weeklyWeight.count)))) kg")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Chart {
                        ForEach(weeklyWeight, id: \.day) { item in
                            LineMark(
                                x: .value("Day", item.day),
                                y: .value("Weight", item.weight)
                            )
                            .foregroundStyle(Color.themeOrange)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            
                            PointMark(
                                x: .value("Day", item.day),
                                y: .value("Weight", item.weight)
                            )
                            .foregroundStyle(Color.themeOrange)
                        }
                    }
                    .frame(height: 150)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                }
                .premiumCardStyle()
            }
        }
    }
}

struct ProfileWrapperView: View {
    @Query private var users: [User]
    
    var body: some View {
        if let user = users.first {
            ProfileView(user: user)
        } else {
            EmptyStateView(imageName: "person.fill.xmark", title: "Error", description: "User data not found.")
        }
    }
}

// MARK: - MAIN PROFILE VIEW
struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Bindable var user: User
    @Query private var dailySummaries: [DailySummary]
    
    @State private var currentStreak: Int = 0
    @State private var showSettings = false // ИНТЕГРИРОВАННАЯ КНОПКА
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable().frame(width: 80, height: 80).foregroundColor(.gray.opacity(0.3))
                        
                        VStack(spacing: 4) {
                            Text(user.name).font(.title2).bold()
                            Text("Daily Goal: \(user.dailyCaloriesGoal) kcal").font(.subheadline).foregroundColor(.gray)
                        }
                        
                        HStack(spacing: 20) {
                            ProfileMetric(title: "Weight", value: "\(String(format: "%.1f", user.weight)) kg")
                            Divider()
                            ProfileMetric(title: "Height", value: "\(Int(user.height)) cm")
                            Divider()
                            ProfileMetric(title: "Age", value: "\(user.age)")
                        }
                        .padding(.vertical, 12).frame(maxWidth: .infinity)
                    }.premiumCardStyle()
                    
                    StreakCardView(streak: currentStreak)
                    AnalyticsView()
                    AchievementsSectionView(user: user)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Calibration Settings").font(.headline)
                        
                        VStack(spacing: 16) {
                            HStack {
                                Text("Weight")
                                Spacer()
                                Stepper("\(String(format: "%.1f", user.weight)) kg", value: $user.weight, in: 40...150, step: 0.1)
                                    .onChange(of: user.weight) { _,_ in updateGoals() }
                            }
                            HStack {
                                Text("Height")
                                Spacer()
                                Stepper("\(Int(user.height)) cm", value: $user.height, in: 140...220, step: 1)
                                    .onChange(of: user.height) { _,_ in updateGoals() }
                            }
                            HStack {
                                Text("Age")
                                Spacer()
                                Stepper("\(user.age)", value: $user.age, in: 10...100, step: 1)
                                    .onChange(of: user.age) { _,_ in updateGoals() }
                            }
                        }
                    }.premiumCardStyle()
                }
                .padding()
            }
            .background(Color.themeBg)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill").foregroundColor(.themePink)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(user: user)
            }
            .onAppear {
                currentStreak = calculateStreak()
                checkAchievements(streak: currentStreak)
            }
        }
    }
    
    private func calculateStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date.now)
        
        let activeDates = dailySummaries
            .filter { $0.totalCalories > 0 }
            .map { calendar.startOfDay(for: $0.date) }
            .sorted(by: >)
        
        guard let mostRecent = activeDates.first else { return 0 }
        
        let daysFromToday = calendar.dateComponents([.day], from: mostRecent, to: today).day ?? 0
        if daysFromToday > 1 { return 0 }
        
        var streak = 1
        var previousDate = mostRecent
        
        for i in 1..<activeDates.count {
            let currentDate = activeDates[i]
            let diff = calendar.dateComponents([.day], from: currentDate, to: previousDate).day ?? 0
            
            if diff == 1 {
                streak += 1
                previousDate = currentDate
            } else if diff == 0 {
                continue
            } else {
                break
            }
        }
        return streak
    }
    
    private func checkAchievements(streak: Int) {
        var hasNewAchievements = false
        
        func unlock(achievementID: String) {
            if !user.unlockedAchievements.contains(achievementID) {
                user.unlockedAchievements.append(achievementID)
                hasNewAchievements = true
            }
        }
        
        if dailySummaries.contains(where: { $0.totalCalories > 0 }) { unlock(achievementID: "first_log") }
        if streak >= 3 { unlock(achievementID: "streak_3") }
        if streak >= 7 { unlock(achievementID: "streak_7") }
        if dailySummaries.contains(where: { $0.totalHydrationLiters >= 2.5 }) { unlock(achievementID: "water_pro") }
        
        if hasNewAchievements { try? context.save() }
    }
    
    private func updateGoals() {
        user.calculateGoals()
        try? context.save()
    }
}

// MARK: - SETTINGS VIEW
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var user: User
    
    @State private var soundEnabled = true
    @State private var notificationsEnabled = true
    @State private var waterReminderInterval = 60
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Apple Health") {
                    Toggle("Enable HealthKit", isOn: $user.isHealthKitEnabled)
                        .onChange(of: user.isHealthKitEnabled) { oldValue, newValue in
                            if newValue {
                                Task {
                                    do {
                                        try await HealthKitManager.shared.requestAuthorization()
                                        try? context.save()
                                    } catch {
                                        user.isHealthKitEnabled = false
                                        print("HealthKit Error: \(error.localizedDescription)")
                                    }
                                }
                            } else {
                                try? context.save()
                            }
                        }
                }
                
                Section("Notifications") {
                    Toggle("Sound", isOn: $soundEnabled)
                    Toggle("Notifications", isOn: $notificationsEnabled)
                    
                    Stepper(value: $waterReminderInterval, in: 30...240, step: 15) {
                        Text("Water Reminder Every \(waterReminderInterval)m")
                    }
                }
                
                Section("About") {
                    HStack { Text("Version"); Spacer(); Text("1.0.0").foregroundColor(.gray) }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(.themePink)
                }
            }
        }
    }
}

// MARK: - STREAK CARD VIEW
struct StreakCardView: View {
    let streak: Int
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.themeOrange.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "flame.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        streak > 0
                            ? LinearGradient(colors: [.themeOrange, .red], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.gray.opacity(0.5), .gray], startPoint: .top, endPoint: .bottom)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(streak) Day Streak!")
                    .font(.title3)
                    .bold()
                
                Text(streak > 0 ? "Keep it up! You're doing great." : "Start logging meals to build your streak.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .premiumCardStyle()
    }
}

// MARK: - ACHIEVEMENTS SECTION VIEW
struct AchievementsSectionView: View {
    let user: User
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements")
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            GeometryReader { mainGeo in
                let screenWidth = mainGeo.size.width
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(Achievement.all) { achievement in
                            let isUnlocked = user.unlockedAchievements.contains(achievement.id)
                            
                            GeometryReader { geo in
                                let minX = geo.frame(in: .global).minX
                                
                                HoloAchievementCard(
                                    achievement: achievement,
                                    isUnlocked: isUnlocked,
                                    minX: minX,
                                    screenWidth: screenWidth
                                )
                            }
                            .frame(width: 120, height: 160)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 20)
                }
                .scrollClipDisabled()
            }
            .frame(height: 200)
        }
        .premiumCardStyle()
    }
}

// MARK: - PROFILE METRIC VIEW
struct ProfileMetric: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.gray)
            Text(value).font(.headline.bold())
        }
    }
}
