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
            
            // Calories Chart
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
            
            // Weight Chart
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

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Bindable var user: User
    
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
                    
                    AnalyticsView()
                    
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
        }
    }
    
    private func updateGoals() {
        user.calculateGoals()
        try? context.save()
    }
}

struct ProfileMetric: View {
    let title: String; let value: String
    var body: some View {
        VStack {
            Text(title).font(.caption).foregroundColor(.gray)
            Text(value).font(.headline.bold())
        }
    }
}
