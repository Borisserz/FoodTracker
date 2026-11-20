import SwiftUI
import SwiftData
import Charts

struct GoalsTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ThemeManager.self) private var themeManager
    
    @Query private var users: [User]
    @Query(sort: \WeightLog.date, order: .forward) private var weightLogs: [WeightLog]
    
    @State private var showAddWeightSheet = false
    @State private var showSetGoalSheet = false
    @State private var bgPhase = 0.0
    @AppStorage("useMetricSystem") private var useMetricSystem = true
    
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
    
    static func computeProgressPercentage(
        goalType: String,
        startWeight: Double,
        currentWeight: Double,
        targetWeight: Double
    ) -> Double {
        if goalType.lowercased() == "maintain" {
            let delta = abs(currentWeight - targetWeight)
            if delta <= 1.0 { return 1.0 }
            return max(0.0, 1.0 - (delta - 1.0) / 4.0)
        }

        let totalDelta = targetWeight - startWeight
        if abs(totalDelta) < 0.01 {
            return abs(currentWeight - targetWeight) <= 1.0 ? 1.0 : 0.0
        }

        let currentDelta = currentWeight - startWeight
        let progress = currentDelta / totalDelta
        return min(max(progress, 0.0), 1.0)
    }

    var progressPercentage: Double {
        guard let target = targetWeight else { return 0 }
        let startWeight = weightLogs.first?.weight ?? user?.weight
        guard let startWeight else { return 0 }
        return Self.computeProgressPercentage(
            goalType: goalType,
            startWeight: startWeight,
            currentWeight: currentWeight,
            targetWeight: target
        )
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
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                        bgPhase = 1.0
                    }
                }
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Metabolic Engine & Goal Archetypes
                        if let u = user {
                            MetabolicTDEEGaugeView(user: u, currentWeight: currentWeight, targetWeight: targetWeight)
                        }
                        
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

                        NutritionMethodologyDisclaimerView(
                            citations: [.bmrAndTdee, .bmi, .dietaryGuidelines]
                        )

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Goals & Progress")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        ensureUserAndOpenGoalSheet()
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(themeManager.current.primaryAccent)
                    }
                    .accessibilityLabel("Goal Settings")
                }
            }
            .sheet(isPresented: $showAddWeightSheet) {
                AddWeightLogSheet(currentWeight: currentWeight)
                    .presentationDetents([.fraction(0.68), .large])
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

    private func ensureUserAndOpenGoalSheet() {
        if user == nil {
            let fallbackUser = User(name: "Champion", weight: currentWeight > 0 ? currentWeight : 70.0, height: 175.0, age: 28, gender: "Male")
            context.insert(fallbackUser)
            try? context.save()
        }
        showSetGoalSheet = true
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
                        Text(String(format: "%.1f", NutritionMath.displayWeight(currentWeight, useMetric: useMetricSystem)))
                            .font(.system(size: 40, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                        Text(NutritionMath.weightUnit(useMetric: useMetricSystem))
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
                    Text("Target: \(NutritionMath.formattedWeight(target, useMetric: useMetricSystem))")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundColor(themeManager.current.primaryAccent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(themeManager.current.primaryAccent.opacity(0.08))
                .cornerRadius(12)
            } else {
                Button(action: { ensureUserAndOpenGoalSheet() }) {
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
                        let goalLabel: String = {
                            switch goalType.lowercased() {
                            case "lose": return String(localized: "Lose Weight")
                            case "gain": return String(localized: "Gain Weight")
                            default: return String(localized: "Maintain Weight")
                            }
                        }()
                        Text("\(NutritionMath.formattedWeight(diff, useMetric: useMetricSystem)) • \(goalLabel)")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
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
                let displayedWeights = weightLogs.map { NutritionMath.displayWeight($0.weight, useMetric: useMetricSystem) }
                let minWeight = displayedWeights.min() ?? NutritionMath.displayWeight(50, useMetric: useMetricSystem)
                let maxWeight = displayedWeights.max() ?? NutritionMath.displayWeight(100, useMetric: useMetricSystem)
                let margin = useMetricSystem ? 2.0 : 5.0
                let areaFloor = minWeight - (useMetricSystem ? 5.0 : 10.0)

                Chart {
                    if let target = targetWeight {
                        let displayedTarget = NutritionMath.displayWeight(target, useMetric: useMetricSystem)
                        RuleMark(y: .value("Target", displayedTarget))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .foregroundStyle(Color.green.opacity(0.7))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Target: \(NutritionMath.formattedWeight(target, useMetric: useMetricSystem))")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.08))
                                    .cornerRadius(4)
                            }
                    }
                    
                    ForEach(weightLogs) { log in
                        let displayedValue = NutritionMath.displayWeight(log.weight, useMetric: useMetricSystem)
                        AreaMark(
                            x: .value("Date", log.date),
                            yStart: .value("Min", areaFloor),
                            yEnd: .value("Weight", displayedValue)
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
                            y: .value("Weight", displayedValue)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(themeManager.current.primaryGradient)
                        .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round))
                        
                        PointMark(
                            x: .value("Date", log.date),
                            y: .value("Weight", displayedValue)
                        )
                        .foregroundStyle(themeManager.current.primaryAccent)
                        .symbolSize(60)
                    }
                }
                .chartYScale(domain: [minWeight - margin, maxWeight + margin])
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
                    
                    Text(NutritionMath.formattedWeight(log.weight, useMetric: useMetricSystem))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(themeManager.current.primaryAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(themeManager.current.primaryAccent.opacity(0.06))
                        .cornerRadius(10)

                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.snappy) {
                            NutritionMath.deleteWeightLog(log, for: user, in: context)
                        }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.75))
                            .padding(8)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Delete Entry"))
                }
                .contextMenu {
                    Button(role: .destructive) {
                        HapticManager.shared.impact(style: .light)
                        withAnimation(.snappy) {
                            NutritionMath.deleteWeightLog(log, for: user, in: context)
                        }
                    } label: {
                        Label("Delete Entry", systemImage: "trash")
                    }
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
    @Query private var users: [User]
    @AppStorage("useMetricSystem") private var useMetricSystem = true
    
    @State private var weight: Double
    @State private var date: Date = Date()
    
    init(currentWeight: Double) {
        _weight = State(initialValue: currentWeight > 0 ? currentWeight : 70.0)
    }

    private var weightDisplayBinding: Binding<Double> {
        $weight.weightDisplayBinding(useMetric: useMetricSystem)
    }

    private var weightRange: ClosedRange<Double> {
        useMetricSystem ? 30.0...200.0 : 66.0...441.0
    }

    private var weightStep: Double {
        useMetricSystem ? 0.1 : 0.5
    }
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            Circle()
                .fill(themeManager.current.primaryAccent.opacity(0.1))
                .frame(width: 250, height: 250)
                .blur(radius: 50)
                .offset(y: -120)
            
            ScrollView(showsIndicators: false) {
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
                                TextField(NutritionMath.weightUnit(useMetric: useMetricSystem), value: weightDisplayBinding, format: .number.precision(.fractionLength(0...1)))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 70)
                                    .font(.system(.title3, design: .rounded, weight: .bold))
                                    .foregroundColor(themeManager.current.primaryAccent)
                                Text(NutritionMath.weightUnit(useMetric: useMetricSystem))
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
                            Slider(value: weightDisplayBinding, in: weightRange, step: weightStep)
                                .tint(themeManager.current.primaryAccent)
                            
                            HStack {
                                Text(NutritionMath.formattedWeight(30.0, useMetric: useMetricSystem))
                                Spacer()
                                Text(NutritionMath.formattedWeight(weight, useMetric: useMetricSystem))
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundColor(themeManager.current.primaryAccent)
                                Spacer()
                                Text(NutritionMath.formattedWeight(200.0, useMetric: useMetricSystem))
                            }
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        }
                        
                        DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
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
    }
    
    private func saveLog() {
        NutritionMath.recordWeight(weight, date: date, for: users.first, in: context)
        HapticManager.shared.notification(type: .success)
        dismiss()
    }
}

struct SetGoalSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @AppStorage("useMetricSystem") private var useMetricSystem = true
    
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

    private var heightDisplayBinding: Binding<Double> {
        $height.heightDisplayBinding(useMetric: useMetricSystem)
    }

    private var heightRange: ClosedRange<Double> {
        useMetricSystem ? 100.0...250.0 : 39.0...98.0
    }

    private var weightDisplayBinding: Binding<Double> {
        $targetWeight.weightDisplayBinding(useMetric: useMetricSystem)
    }

    private var weightRange: ClosedRange<Double> {
        useMetricSystem ? 30.0...200.0 : 66.0...441.0
    }

    private var weightStep: Double {
        useMetricSystem ? 0.1 : 0.5
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
                                            Text(LocalizedStringKey(type.capitalized))
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
                                    TextField(NutritionMath.heightUnit(useMetric: useMetricSystem), value: heightDisplayBinding, format: .number)
                                        .keyboardType(.numberPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 60)
                                        .font(.system(.title3, design: .rounded, weight: .bold))
                                        .foregroundColor(themeManager.current.primaryAccent)
                                    Text(NutritionMath.heightUnit(useMetric: useMetricSystem))
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
                                Slider(value: heightDisplayBinding, in: heightRange, step: 1)
                                    .tint(themeManager.current.primaryAccent)
                                
                                HStack {
                                    Text(NutritionMath.formattedHeight(cm: 100, useMetric: useMetricSystem))
                                    Spacer()
                                    Text(NutritionMath.formattedHeight(cm: height, useMetric: useMetricSystem))
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                        .foregroundColor(themeManager.current.primaryAccent)
                                    Spacer()
                                    Text(NutritionMath.formattedHeight(cm: 250, useMetric: useMetricSystem))
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
                                        TextField(NutritionMath.weightUnit(useMetric: useMetricSystem), value: weightDisplayBinding, format: .number.precision(.fractionLength(0...1)))
                                            .keyboardType(.decimalPad)
                                            .multilineTextAlignment(.trailing)
                                            .frame(width: 70)
                                            .font(.system(.title3, design: .rounded, weight: .bold))
                                            .foregroundColor(themeManager.current.primaryAccent)
                                        Text(NutritionMath.weightUnit(useMetric: useMetricSystem))
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
                                    Slider(value: weightDisplayBinding, in: weightRange, step: weightStep)
                                        .tint(themeManager.current.primaryAccent)
                                    
                                    HStack {
                                        Text(NutritionMath.formattedWeight(30.0, useMetric: useMetricSystem))
                                        Spacer()
                                        Text(NutritionMath.formattedWeight(targetWeight, useMetric: useMetricSystem))
                                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                                            .foregroundColor(themeManager.current.primaryAccent)
                                        Spacer()
                                        Text(NutritionMath.formattedWeight(200.0, useMetric: useMetricSystem))
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
        let previousCalories = user.dailyCaloriesGoal
        user.weightGoalType = goalType
        let goalName: String
        switch goalType {
        case "lose": goalName = "Lose Weight"
        case "gain": goalName = "Build Muscle"
        default: goalName = "Maintain Weight"
        }
        user.targetWeight = MetabolicBlueprintCalculator.sanitizedTargetWeight(
            for: goalName,
            weight: user.weight,
            targetWeight: targetWeight
        )
        user.height = height
        user.calculateGoals()
        user.recalculateMacrosPreservingRatios(fromPreviousCalories: previousCalories)
        try? context.save()
        WidgetReloader.reloadAll()
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
    
    private func bmiCategoryString(_ bmi: Double) -> LocalizedStringKey {
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
