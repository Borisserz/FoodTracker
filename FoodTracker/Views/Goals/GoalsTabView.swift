import SwiftUI
import SwiftData
import Charts

struct GoalsTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    
    @Query private var users: [User]
    @Query(sort: \WeightLog.date, order: .forward) private var weightLogs: [WeightLog]
    
    @State private var showAddWeightSheet = false
    @State private var showSetGoalSheet = false
    
    var user: User? { users.first }
    
    var currentWeight: Double {
        weightLogs.last?.weight ?? user?.weight ?? 0.0
    }
    
    var targetWeight: Double? {
        user?.targetWeight
    }
    
    var goalType: String {
        user?.weightGoalType ?? "maintain"
    }
    
    var progressPercentage: Double {
        guard let target = targetWeight, let startWeight = user?.weight else { return 0 }
        
        let totalToChange = abs(target - startWeight)
        let changed = abs(currentWeight - startWeight)
        
        if totalToChange == 0 { return 1.0 }
        let progress = changed / totalToChange
        return min(max(progress, 0.0), 1.0)
    }
    
    var currentBMI: Double? {
        guard let heightCm = user?.height, heightCm > 0 else { return nil }
        let heightM = heightCm / 100.0
        return currentWeight / (heightM * heightM)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Current Status Card
                        statusCard
                        
                        // Progress Ring Card
                        if targetWeight != nil {
                            progressCard
                        }
                        
                        // Chart Card
                        if !weightLogs.isEmpty {
                            chartCard
                        }
                        
                        // Recent Logs
                        recentLogsList
                        
                        // Before & After Photo Comparison has been moved to AI Coach tab
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Goals & Progress")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSetGoalSheet = true }) {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(themeManager.current.primaryAccent)
                    }
                }
            }
            .sheet(isPresented: $showAddWeightSheet) {
                AddWeightLogSheet(currentWeight: currentWeight)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showSetGoalSheet) {
                if let u = user {
                    SetGoalSheet(user: u)
                        .presentationDetents([.medium])
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var statusCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Weight")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", currentWeight))
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Text("kg")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                
                if let target = targetWeight {
                    HStack {
                        Image(systemName: iconForGoal(goalType))
                            .foregroundColor(themeManager.current.primaryAccent)
                        Text("Target: \(String(format: "%.1f", target)) kg")
                            .font(.subheadline.bold())
                            .foregroundColor(themeManager.current.primaryAccent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeManager.current.primaryAccent.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Button(action: { showSetGoalSheet = true }) {
                        HStack {
                            Image(systemName: "target")
                            Text("Set a Goal")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(themeManager.current.primaryAccent)
                    }
                }
                
                if let bmi = currentBMI {
                    Text("BMI: \(String(format: "%.1f", bmi))")
                        .font(.caption.bold())
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
            
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                showAddWeightSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(themeManager.current.primaryGradient)
                    .clipShape(Circle())
                    .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 8, y: 4)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
    }
    
    private var progressCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .trim(from: 0, to: progressPercentage)
                    .stroke(themeManager.current.primaryGradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progressPercentage)
                
                Text("\(Int(progressPercentage * 100))%")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Journey Progress")
                    .font(.headline)
                
                if progressPercentage >= 1.0 {
                    Text("Goal Reached! 🎉")
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else {
                    let diff = abs(currentWeight - (targetWeight ?? 0))
                    Text("\(String(format: "%.1f", diff)) kg left to \(goalType)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
    }
    
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weight History")
                .font(.headline)
            
            if weightLogs.count < 2 {
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("Add more weight entries to see your trend over time.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(16)
            } else {
                Chart {
                    if let target = targetWeight {
                        RuleMark(y: .value("Target", target))
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                            .foregroundStyle(Color.green.opacity(0.8))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Target")
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                            }
                    }
                    
                    ForEach(weightLogs) { log in
                        LineMark(
                            x: .value("Date", log.date),
                            y: .value("Weight", log.weight)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(themeManager.current.primaryGradient)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        
                        PointMark(
                            x: .value("Date", log.date),
                            y: .value("Weight", log.weight)
                        )
                        .foregroundStyle(themeManager.current.primaryAccent)
                        .symbolSize(40)
                    }
                }
                .chartYScale(domain: [(weightLogs.map { $0.weight }.min() ?? 50) - 2, (weightLogs.map { $0.weight }.max() ?? 100) + 2])
                .frame(height: 200)
                .padding(.vertical)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
    }
    
    private func iconForGoal(_ goal: String) -> String {
        switch goal {
        case "lose": return "arrow.down.right.circle.fill"
        case "gain": return "arrow.up.right.circle.fill"
        default: return "equal.circle.fill"
        }
    }
    
    private var recentLogsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Entries")
                .font(.headline)
                .padding(.leading, 4)
            
            ForEach(weightLogs.reversed().prefix(5)) { log in
                HStack {
                    VStack(alignment: .leading) {
                        Text(log.date, format: .dateTime.day().month().year())
                            .font(.subheadline.bold())
                        Text(log.date, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text(String(format: "%.1f kg", log.weight))
                        .font(.headline)
                        .foregroundColor(themeManager.current.primaryAccent)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.02), radius: 5, y: 2)
            }
        }
    }
}

// MARK: - Sheets

struct AddWeightLogSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var weight: Double
    @State private var date: Date = Date()
    
    init(currentWeight: Double) {
        _weight = State(initialValue: currentWeight > 0 ? currentWeight : 70.0)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Weight Entry")) {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("kg", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(themeManager.current.primaryAccent)
                            .font(.headline)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLog()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.current.primaryAccent)
                }
            }
        }
    }
    
    private func saveLog() {
        let log = WeightLog(date: date, weight: weight)
        context.insert(log)
        try? context.save()
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
}

struct SetGoalSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    let user: User
    
    @State private var targetWeight: Double
    @State private var goalType: String
    
    let goalTypes = ["lose", "maintain", "gain"]
    
    init(user: User) {
        self.user = user
        _targetWeight = State(initialValue: user.targetWeight ?? user.weight)
        _goalType = State(initialValue: user.weightGoalType ?? "lose")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Goal Direction")) {
                    Picker("Goal Type", selection: $goalType) {
                        ForEach(goalTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if goalType != "maintain" {
                    Section(header: Text("Target Weight")) {
                        HStack {
                            Text("Target")
                            Spacer()
                            TextField("kg", value: $targetWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(themeManager.current.primaryAccent)
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("Set Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoal()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.current.primaryAccent)
                }
            }
        }
    }
    
    private func saveGoal() {
        user.weightGoalType = goalType
        if goalType == "maintain" {
            user.targetWeight = user.weight
        } else {
            user.targetWeight = targetWeight
        }
        try? context.save()
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
}
