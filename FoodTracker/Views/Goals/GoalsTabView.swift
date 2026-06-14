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
    @State private var bgPhase = 0.0
    
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
    
    private var goalColors: [Color] {
        switch goalType.lowercased() {
        case "lose": return [.themePink, .purple]
        case "gain": return [.cyan, .blue]
        default: return [.green, .mint]
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBg.ignoresSafeArea()
                
                // Animated background glow blobs
                ZStack {
                    Circle()
                        .fill(goalColors[0].opacity(0.12))
                        .frame(width: 320, height: 320)
                        .blur(radius: 80)
                        .offset(x: bgPhase == 0 ? -100 : -50, y: bgPhase == 0 ? -180 : -100)
                    
                    Circle()
                        .fill(goalColors[1].opacity(0.12))
                        .frame(width: 350, height: 350)
                        .blur(radius: 85)
                        .offset(x: bgPhase == 0 ? 120 : 60, y: bgPhase == 0 ? 200 : 120)
                }
                .ignoresSafeArea()
                .onAppear {
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        bgPhase = 1.0
                    }
                }
                
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
                        
                        // Before & After Photo Comparison
                        BeforeAfterView()
                        
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
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(themeManager.current.primaryAccent)
                    }
                }
            }
            .sheet(isPresented: $showAddWeightSheet) {
                AddWeightLogSheet(currentWeight: currentWeight)
                    .presentationDetents([.medium])
                    .presentationCornerRadius(32)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSetGoalSheet) {
                if let u = user {
                    SetGoalSheet(user: u)
                        .presentationDetents([.fraction(0.8)])
                        .presentationCornerRadius(32)
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Weight")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", currentWeight))
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Text("kg")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    HapticManager.shared.impact(style: .medium)
                    showAddWeightSheet = true
                }) {
                    ZStack {
                        Circle()
                            .fill(themeManager.current.primaryGradient)
                            .frame(width: 50, height: 50)
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.35), radius: 8, x: 0, y: 4)
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                    }
                }
            }
            
            if let target = targetWeight {
                HStack {
                    Image(systemName: iconForGoal(goalType))
                        .foregroundColor(themeManager.current.primaryAccent)
                    Text("Target: \(String(format: "%.1f", target)) kg")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(themeManager.current.primaryAccent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(themeManager.current.primaryAccent.opacity(0.08))
                .cornerRadius(12)
            } else {
                Button(action: { showSetGoalSheet = true }) {
                    HStack {
                        Image(systemName: "target")
                        Text("Set a Goal")
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(themeManager.current.primaryAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(themeManager.current.primaryAccent.opacity(0.08))
                    .cornerRadius(12)
                }
            }
            
            if let bmi = currentBMI {
                Divider().padding(.vertical, 4)
                BMIMeterView(bmi: bmi)
            }
        }
        .padding(20)
        .background(
            ZStack {
                Color.primary.opacity(0.01)
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
            }
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private var progressCard: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.06), lineWidth: 10)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: progressPercentage)
                        .stroke(themeManager.current.primaryGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: progressPercentage)
                    
                    Text("\(Int(progressPercentage * 100))%")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Journey Progress")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    
                    if progressPercentage >= 1.0 {
                        Text("Goal Reached! 🎉")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        let diff = abs(currentWeight - (targetWeight ?? 0))
                        Text("\(String(format: "%.1f", diff)) kg left to \(goalType)")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            if let startWeight = user?.weight, let target = targetWeight {
                Divider().padding(.vertical, 4)
                
                WeightFlaskView(
                    startWeight: startWeight,
                    currentWeight: currentWeight,
                    targetWeight: target,
                    progress: progressPercentage,
                    themeColor: themeManager.current.primaryAccent
                )
            }
        }
        .padding(20)
        .background(
            ZStack {
                Color.primary.opacity(0.01)
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
            }
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weight History")
                .font(.system(.headline, design: .rounded, weight: .bold))
            
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
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .foregroundStyle(Color.green.opacity(0.7))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Target: \(String(format: "%.1f", target)) kg")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.08))
                                    .cornerRadius(4)
                            }
                    }
                    
                    ForEach(weightLogs) { log in
                        AreaMark(
                            x: .value("Date", log.date),
                            yStart: .value("Min", (weightLogs.map { $0.weight }.min() ?? 50) - 5),
                            yEnd: .value("Weight", log.weight)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [themeManager.current.primaryAccent.opacity(0.18), themeManager.current.primaryAccent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        LineMark(
                            x: .value("Date", log.date),
                            y: .value("Weight", log.weight)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(themeManager.current.primaryGradient)
                        .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        
                        PointMark(
                            x: .value("Date", log.date),
                            y: .value("Weight", log.weight)
                        )
                        .foregroundStyle(themeManager.current.primaryAccent)
                        .symbolSize(60)
                    }
                }
                .chartYScale(domain: [(weightLogs.map { $0.weight }.min() ?? 50) - 2, (weightLogs.map { $0.weight }.max() ?? 100) + 2])
                .frame(height: 200)
                .padding(.vertical)
            }
        }
        .padding(20)
        .background(
            ZStack {
                Color.primary.opacity(0.01)
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
            }
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    private func iconForGoal(_ goal: String) -> String {
        switch goal {
        case "lose": return "arrow.down.right.circle.fill"
        case "gain": return "arrow.up.right.circle.fill"
        default: return "equal.circle.fill"
        }
    }
    
    private var recentLogsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Entries")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .padding(.leading, 4)
            
            ForEach(weightLogs.reversed().prefix(5)) { log in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.date, format: .dateTime.day().month().year())
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                        Text(log.date, format: .dateTime.hour().minute())
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    Text(String(format: "%.1f kg", log.weight))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(themeManager.current.primaryAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(themeManager.current.primaryAccent.opacity(0.06))
                        .cornerRadius(10)
                }
                .padding(16)
                .background(
                    ZStack {
                        Color.primary.opacity(0.01)
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                    }
                )
                .cornerRadius(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.04)
                                ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
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
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            Circle()
                .fill(themeManager.current.primaryAccent.opacity(0.1))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(y: -120)
            
            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Text("Log Weight")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                
                VStack(spacing: 20) {
                    HStack {
                        Text("Weight")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        Spacer()
                        
                        HStack(spacing: 4) {
                            TextField("kg", value: $weight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                                .font(.system(.title3, design: .rounded, weight: .bold))
                                .foregroundColor(themeManager.current.primaryAccent)
                            Text("kg")
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(10)
                    }
                    
                    // Slider for Weight selection
                    VStack(spacing: 6) {
                        Slider(value: $weight, in: 30...200, step: 0.1)
                            .tint(themeManager.current.primaryAccent)
                        
                        HStack {
                            Text("30 kg")
                            Spacer()
                            Text(String(format: "%.1f kg", weight))
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundColor(themeManager.current.primaryAccent)
                            Spacer()
                            Text("200 kg")
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .font(.system(.body, design: .rounded, weight: .bold))
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(20)
                    }
                    
                    Button(action: { saveLog() }) {
                        Text("Save Entry")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(themeManager.current.primaryGradient)
                            .cornerRadius(20)
                            .shimmer()
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.35), radius: 8, y: 4)
                    }
                    .buttonStyle(BounceButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
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
    @State private var height: Double
    
    let goalTypes = ["lose", "maintain", "gain"]
    
    init(user: User) {
        self.user = user
        _targetWeight = State(initialValue: user.targetWeight ?? user.weight)
        _goalType = State(initialValue: user.weightGoalType ?? "lose")
        _height = State(initialValue: user.height > 0 ? user.height : 170.0)
    }
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            Circle()
                .fill(themeManager.current.primaryAccent.opacity(0.1))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(y: -120)
            
            VStack(spacing: 20) {
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)
                
                Text("Set Your Goal")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Custom Goal Picker cards
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goal Direction")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 4)
                            
                            HStack(spacing: 12) {
                                ForEach(goalTypes, id: \.self) { type in
                                    let isSelected = goalType == type
                                    Button(action: {
                                        HapticManager.shared.impact(style: .light)
                                        goalType = type
                                        if type == "maintain" {
                                            targetWeight = user.weight
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: iconForGoalType(type))
                                                .font(.system(size: 20, weight: .bold))
                                            Text(type.capitalized)
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(isSelected ? themeManager.current.primaryGradient : LinearGradient(colors: [Color.primary.opacity(0.04), Color.primary.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .cornerRadius(16)
                                        .shadow(color: isSelected ? themeManager.current.primaryAccent.opacity(0.3) : .clear, radius: 6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // Height Card
                        VStack(spacing: 16) {
                            HStack {
                                Text("Your Height")
                                    .font(.system(.caption, design: .rounded, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Spacer()
                                
                                HStack(spacing: 4) {
                                    TextField("cm", value: $height, format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 60)
                                        .font(.system(.title3, design: .rounded, weight: .bold))
                                        .foregroundColor(themeManager.current.primaryAccent)
                                    Text("cm")
                                        .font(.system(.body, design: .rounded, weight: .bold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(10)
                            }
                            
                            // Height slider
                            VStack(spacing: 6) {
                                Slider(value: $height, in: 100...250, step: 1)
                                    .tint(themeManager.current.primaryAccent)
                                
                                HStack {
                                    Text("100 cm")
                                    Spacer()
                                    Text("\(Int(height)) cm")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundColor(themeManager.current.primaryAccent)
                                    Spacer()
                                    Text("250 cm")
                                }
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        
                        // Target Weight Card (only visible if goalType is not maintain)
                        if goalType != "maintain" {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Target Weight")
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    Spacer()
                                    
                                    HStack(spacing: 4) {
                                        TextField("kg", value: $targetWeight, format: .number)
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 70)
                                            .font(.system(.title3, design: .rounded, weight: .bold))
                                            .foregroundColor(themeManager.current.primaryAccent)
                                        Text("kg")
                                            .font(.system(.body, design: .rounded, weight: .bold))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(10)
                                }
                                
                                // Slider for Weight selection
                                VStack(spacing: 6) {
                                    Slider(value: $targetWeight, in: 30...200, step: 0.1)
                                        .tint(themeManager.current.primaryAccent)
                                    
                                    HStack {
                                        Text("30 kg")
                                        Spacer()
                                        Text(String(format: "%.1f kg", targetWeight))
                                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                                            .foregroundColor(themeManager.current.primaryAccent)
                                        Spacer()
                                        Text("200 kg")
                                    }
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                                }
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .cornerRadius(24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(20)
                    }
                    
                    Button(action: { saveGoal() }) {
                        Text("Save Goal")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(themeManager.current.primaryGradient)
                            .cornerRadius(20)
                            .shimmer()
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.35), radius: 8, y: 4)
                    }
                    .buttonStyle(BounceButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func iconForGoalType(_ type: String) -> String {
        switch type {
        case "lose": return "arrow.down.right.circle.fill"
        case "gain": return "arrow.up.right.circle.fill"
        default: return "equal.circle.fill"
        }
    }
    
    private func saveGoal() {
        user.weightGoalType = goalType
        if goalType == "maintain" {
            user.targetWeight = user.weight
        } else {
            user.targetWeight = targetWeight
        }
        user.height = height
        user.calculateGoals()
        try? context.save()
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
}

// MARK: - Redesign Custom View Helpers

struct BMIMeterView: View {
    let bmi: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BMI Classification")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                Text(bmiCategoryString(bmi))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(bmiCategoryColor(bmi))
            }
            
            GeometryReader { geo in
                let width = geo.size.width
                let position = bmiPointerPosition(bmi, totalWidth: width)
                
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        Color.blue.opacity(0.7)
                            .frame(width: width * 0.22)
                        Color.green.opacity(0.7)
                            .frame(width: width * 0.35)
                        Color.orange.opacity(0.7)
                            .frame(width: width * 0.22)
                        Color.red.opacity(0.7)
                            .frame(width: width * 0.21)
                    }
                    .frame(height: 8)
                    .cornerRadius(4)
                    
                    Circle()
                        .fill(Color.primary)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .offset(x: position - 7)
                        .shadow(radius: 2)
                }
            }
            .frame(height: 14)
        }
    }
    
    private func bmiCategoryString(_ bmi: Double) -> String {
        if bmi < 18.5 { return "Underweight" }
        else if bmi < 25 { return "Normal Weight" }
        else if bmi < 30 { return "Overweight" }
        else { return "Obese" }
    }
    
    private func bmiCategoryColor(_ bmi: Double) -> Color {
        if bmi < 18.5 { return .blue }
        else if bmi < 25 { return .green }
        else if bmi < 30 { return .orange }
        else { return .red }
    }
    
    private func bmiPointerPosition(_ bmi: Double, totalWidth: CGFloat) -> CGFloat {
        let minBmi = 15.0
        let maxBmi = 35.0
        let clampedBmi = min(max(bmi, minBmi), maxBmi)
        let percent = (clampedBmi - minBmi) / (maxBmi - minBmi)
        return CGFloat(percent) * totalWidth
    }
}

struct HorizontalFlaskShape: Shape {
    let neckLength: CGFloat
    let neckHeight: CGFloat
    let tubeHeight: CGFloat
    let bulbDiameter: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let width = rect.width
        let height = rect.height
        
        let centerY = height / 2
        let bulbCenterX = width - bulbDiameter / 2
        
        let r = bulbDiameter / 2
        let h = tubeHeight / 2
        let dx = sqrt(max(r*r - h*h, 0.0))
        let intersectX = bulbCenterX - dx
        
        let lipWidth: CGFloat = 4
        let lipHeight: CGFloat = neckHeight + 4
        
        // Start at top-left of the lip: (0, centerY - lipHeight/2)
        path.move(to: CGPoint(x: 0, y: centerY - lipHeight/2))
        
        // Outer face of the lip: go down to (0, centerY + lipHeight/2)
        path.addLine(to: CGPoint(x: 0, y: centerY + lipHeight/2))
        
        // Bottom-left corner of the lip: (lipWidth, centerY + lipHeight/2)
        path.addLine(to: CGPoint(x: lipWidth, y: centerY + lipHeight/2))
        
        // Step into the neck: (lipWidth, centerY + neckHeight/2)
        path.addLine(to: CGPoint(x: lipWidth, y: centerY + neckHeight/2))
        
        // Neck bottom line: to (lipWidth + neckLength, centerY + neckHeight/2)
        let neckEndX = lipWidth + neckLength
        path.addLine(to: CGPoint(x: neckEndX, y: centerY + neckHeight/2))
        
        // Expand/flare to tube height: (neckEndX, centerY + tubeHeight/2)
        path.addLine(to: CGPoint(x: neckEndX, y: centerY + tubeHeight/2))
        
        // Tube bottom line: to the intersection point with the bulb
        path.addLine(to: CGPoint(x: intersectX, y: centerY + tubeHeight/2))
        
        // Arc of the bulb: from intersectX (bottom) around the right side to intersectX (top)
        let startAngle = atan2(h, -dx)
        let endAngle = atan2(-h, -dx)
        
        path.addArc(center: CGPoint(x: bulbCenterX, y: centerY),
                    radius: r,
                    startAngle: Angle(radians: Double(startAngle)),
                    endAngle: Angle(radians: Double(endAngle)),
                    clockwise: false)
        
        // Tube top line: back to neckEndX
        path.addLine(to: CGPoint(x: neckEndX, y: centerY - tubeHeight/2))
        
        // Flare back to neck: (neckEndX, centerY - neckHeight/2)
        path.addLine(to: CGPoint(x: neckEndX, y: centerY - neckHeight/2))
        
        // Neck top line: back to lipWidth
        path.addLine(to: CGPoint(x: lipWidth, y: centerY - neckHeight/2))
        
        // Step to lip top: (lipWidth, centerY - lipHeight/2)
        path.addLine(to: CGPoint(x: lipWidth, y: centerY - lipHeight/2))
        
        // Close path
        path.closeSubpath()
        
        return path
    }
}

struct BubblesLayer: View {
    let fillWidth: CGFloat
    let containerHeight: CGFloat
    
    var body: some View {
        ZStack {
            ForEach(0..<6) { i in
                BubbleView(index: i, fillWidth: fillWidth, containerHeight: containerHeight)
            }
        }
    }
}

struct BubbleView: View {
    let index: Int
    let fillWidth: CGFloat
    let containerHeight: CGFloat
    
    @State private var bubbleY: CGFloat = 0.0
    @State private var bubbleX: CGFloat = 0.0
    @State private var bubbleOpacity: Double = 0.0
    @State private var bubbleScale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(bubbleOpacity))
            .scaleEffect(bubbleScale)
            .frame(width: CGFloat((index % 3 == 0) ? 4 : (index % 2 == 0) ? 3 : 2))
            .position(x: bubbleX, y: bubbleY)
            .onAppear {
                animateBubble()
            }
    }
    
    private func animateBubble() {
        let initialX = CGFloat.random(in: 24...max(28, fillWidth - 12))
        let initialY = containerHeight / 2 + CGFloat.random(in: 1...6)
        
        bubbleX = initialX
        bubbleY = initialY
        bubbleOpacity = Double.random(in: 0.2...0.6)
        bubbleScale = 0.8
        
        let duration = Double.random(in: 1.8...3.2)
        let driftX = CGFloat.random(in: -10...10)
        let targetY = containerHeight / 2 - CGFloat.random(in: 3...8)
        
        withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: false)) {
            bubbleX = initialX + driftX
            bubbleY = targetY
            bubbleOpacity = 0.0
            bubbleScale = 1.3
        }
    }
}

struct WeightFlaskView: View {
    let startWeight: Double
    let currentWeight: Double
    let targetWeight: Double
    let progress: Double
    let themeColor: Color
    
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                
                // Define dimensions
                let neckLength: CGFloat = 20
                let neckHeight: CGFloat = 16
                let tubeHeight: CGFloat = 22
                let bulbDiameter: CGFloat = 48
                
                let centerY = height / 2
                let bulbCenterX = width - bulbDiameter / 2
                
                // Calculations for intersection of tube with bulb
                let r = bulbDiameter / 2
                let h = tubeHeight / 2
                let dx = sqrt(max(r*r - h*h, 0.0))
                let intersectX = bulbCenterX - dx
                let neckEndX = 4 + neckLength
                
                // Calculated progress positioning for fluid fill and badge
                let fillableLength = intersectX - 4 // From lip to bulb intersection
                let fillWidth = max(min(fillableLength * CGFloat(progress), fillableLength), 0)
                
                ZStack(alignment: .leading) {
                    // 1. Wood-cork stopper on the left mouth
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.65, green: 0.45, blue: 0.30),
                                    Color(red: 0.50, green: 0.32, blue: 0.18),
                                    Color(red: 0.38, green: 0.24, blue: 0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 12, height: neckHeight + 2)
                        .offset(x: -4, y: centerY - (neckHeight + 2)/2)
                        .shadow(color: Color.black.opacity(0.15), radius: 2, x: -1, y: 1)
                    
                    // 2. Glass container background
                    HorizontalFlaskShape(
                        neckLength: neckLength,
                        neckHeight: neckHeight,
                        tubeHeight: tubeHeight,
                        bulbDiameter: bulbDiameter
                    )
                    .fill(Color.primary.opacity(0.04))
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    
                    // 3. Scale / graduation ticks along the tube
                    Path { path in
                        let tickCount = 5
                        for i in 1..<tickCount {
                            let ratio = CGFloat(i) / CGFloat(tickCount)
                            let tickX = neckEndX + (intersectX - neckEndX) * ratio
                            path.move(to: CGPoint(x: tickX, y: centerY + tubeHeight/2 - 4))
                            path.addLine(to: CGPoint(x: tickX, y: centerY + tubeHeight/2))
                        }
                    }
                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                    
                    // 4. Fluid overlay (masked with flask shape)
                    if progress > 0 {
                        ZStack(alignment: .leading) {
                            // Fluid body
                            Rectangle()
                                .fill(themeManager.current.primaryGradient)
                                .frame(width: fillWidth + 4, height: height)
                                .shadow(color: themeManager.current.primaryAccent.opacity(0.4), radius: 8, x: 0, y: 3)
                            
                            // Bubble animation container
                            BubblesLayer(fillWidth: fillWidth + 4, containerHeight: height)
                        }
                        .mask(
                            HorizontalFlaskShape(
                                neckLength: neckLength,
                                neckHeight: neckHeight,
                                tubeHeight: tubeHeight,
                                bulbDiameter: bulbDiameter
                            )
                        )
                        .animation(.spring(response: 0.9, dampingFraction: 0.75), value: progress)
                    }
                    
                    // 5. Outer Glass Stroke & Reflection highlights
                    HorizontalFlaskShape(
                        neckLength: neckLength,
                        neckHeight: neckHeight,
                        tubeHeight: tubeHeight,
                        bulbDiameter: bulbDiameter
                    )
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.primary.opacity(0.12),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    
                    // Glass shine highlight inside the tube (a thin specular stroke)
                    Path { path in
                        path.move(to: CGPoint(x: neckEndX + 4, y: centerY - tubeHeight/2 + 2))
                        path.addLine(to: CGPoint(x: intersectX - 4, y: centerY - tubeHeight/2 + 2))
                    }
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    
                    // 6. Finish indicator inside the bulb (checkmark seal if done, checkered flag otherwise)
                    ZStack {
                        Circle()
                            .fill(progress >= 1.0 ? Color.green.opacity(0.2) : Color.primary.opacity(0.03))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: progress >= 1.0 ? "checkmark.seal.fill" : "flag.checkered")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(progress >= 1.0 ? .green : .secondary.opacity(0.6))
                    }
                    .offset(x: bulbCenterX - 14, y: centerY - 14)
                    
                    // 7. Dynamic sliding Current Weight badge (floats above liquid level)
                    if progress > 0 {
                        let badgeWidth: CGFloat = 56
                        let badgeX = neckEndX + (bulbCenterX - neckEndX) * CGFloat(progress) - badgeWidth/2
                        
                        VStack(spacing: 0) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(themeManager.current.primaryGradient, lineWidth: 1.5)
                                    )
                                
                                Text(String(format: "%.1f kg", currentWeight))
                                    .font(.system(size: 9, weight: .black, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            .frame(width: badgeWidth, height: 24)
                            
                            // Tiny pointer
                            Image(systemName: "triangle.fill")
                                .font(.system(size: 5))
                                .foregroundColor(themeManager.current.primaryAccent)
                                .rotationEffect(.degrees(180))
                                .offset(y: -1)
                        }
                        .offset(x: badgeX, y: centerY - tubeHeight/2 - 30)
                    }
                    
                    // 8. Hanging Start Weight label
                    VStack(spacing: 1) {
                        // Small hanging string
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1, height: 12)
                        
                        VStack(spacing: 0) {
                            Text("START")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f kg", startWeight))
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                        )
                    }
                    .offset(x: neckEndX - 10, y: centerY + tubeHeight/2)
                    
                    // 9. Hanging Goal Weight label
                    VStack(spacing: 1) {
                        // Small hanging string
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1, height: 12)
                        
                        VStack(spacing: 0) {
                            Text("GOAL")
                                .font(.system(size: 7, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f kg", targetWeight))
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                        )
                    }
                    .offset(x: bulbCenterX - 22, y: centerY + tubeHeight/2)
                }
            }
            .frame(height: 100)
        }
    }
}


