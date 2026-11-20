import SwiftUI
import SwiftData
import HealthKit

struct QuickActivityAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    
    let summary: DailySummary
    
    @State private var selectedActivity: ActivityOption?
    @State private var durationMinutes: Double = 30
    @State private var caloriesBurned: Double = 300
    @State private var isSaving: Bool = false
    
    struct ActivityOption: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let icon: String
        let hkType: HKWorkoutActivityType
        let metValue: Double // Metabolic Equivalent of Task for calorie estimation
    }
    
    let activities: [ActivityOption] = [
        ActivityOption(name: "Running", icon: "figure.run", hkType: .running, metValue: 9.8),
        ActivityOption(name: "Cycling", icon: "figure.outdoor.cycle", hkType: .cycling, metValue: 7.5),
        ActivityOption(name: "Swimming", icon: "figure.pool.swim", hkType: .swimming, metValue: 6.0),
        ActivityOption(name: "Walking", icon: "figure.walk", hkType: .walking, metValue: 3.5),
        ActivityOption(name: "Yoga", icon: "figure.mind.and.body", hkType: .yoga, metValue: 3.0),
        ActivityOption(name: "Gym", icon: "dumbbell.fill", hkType: .traditionalStrengthTraining, metValue: 5.0)
    ]
    
    var userWeightKg: Double {
        users.first?.weight ?? 70.0
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Log Activity")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    // Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(activities) { activity in
                            Button {
                                withAnimation(.spring()) {
                                    selectedActivity = activity
                                    updateCalories()
                                }
                            } label: {
                                VStack(spacing: 12) {
                                    Image(systemName: activity.icon)
                                        .font(.system(size: 32))
                                        .foregroundStyle(selectedActivity == activity ? .white : .primary)
                                    Text(LocalizedStringKey(activity.name))
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundStyle(selectedActivity == activity ? .white : .primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(selectedActivity == activity ? Color.themeOrange : Color.gray.opacity(0.1))
                                .cornerRadius(20)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(selectedActivity == activity ? Color.themeOrange.opacity(0.5) : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(BounceButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    
                    if let _ = selectedActivity {
                        VStack(spacing: 24) {
                            // Duration Slider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Duration")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(Int(durationMinutes)) min")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.themeOrange)
                                }
                                Slider(value: Binding(get: { durationMinutes }, set: { durationMinutes = $0; updateCalories() }), in: 5...180, step: 5)
                                    .tint(.themeOrange)
                            }
                            
                            // Calories Slider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Calories Burned")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(Int(caloriesBurned)) kcal")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.themeOrange)
                                }
                                Slider(value: $caloriesBurned, in: 10...2000, step: 10)
                                    .tint(.themeOrange)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(24)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selectedActivity != nil {
                    Button(action: saveActivity) {
                        Text("Save Activity")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.themeOrange)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .shadow(color: Color.themeOrange.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding()
                    .background(Color(uiColor: .systemBackground).opacity(0.9).ignoresSafeArea())
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
            }
        }
    }
    
    private func updateCalories() {
        guard let activity = selectedActivity else { return }
        // Formula: Calories = MET * weight(kg) * (duration(min) / 60)
        let calculated = activity.metValue * userWeightKg * (durationMinutes / 60.0)
        caloriesBurned = calculated
    }
    
    private func saveActivity() {
        guard !isSaving, let activity = selectedActivity else { return }
        isSaving = true

        let cals = Int(caloriesBurned)
        let duration = Int(durationMinutes)
        let targetSummary = DailySummary.fetchOrCreate(for: summary.date, in: context)

        let calendar = Calendar.current
        let workoutDate: Date
        if calendar.isDateInToday(summary.date) {
            workoutDate = Date()
        } else {
            // Anchor past-date workouts to noon so subtracting duration never crosses midnight into the previous day.
            workoutDate = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: summary.date) ?? summary.date
        }

        let previousLocalCals = targetSummary.localActivityCalories
        let priorExternalWorkouts = WorkoutSyncManager.priorExternalWorkoutCalories(
            totalWorkoutCalories: targetSummary.workoutCalories,
            previousLocalActivityCalories: previousLocalCals
        )

        let log = ActivityLog(title: activity.name, icon: activity.icon, durationMinutes: duration, calories: cals, date: workoutDate)
        context.insert(log)
        targetSummary.addActivity(log)

        let shouldSyncHealthKit = users.first?.isHealthKitEnabled == true
        let wtCals = WorkoutSyncManager.shared.fetchWorkoutCalories(for: targetSummary.date)
        let reconciled = WorkoutSyncManager.computeDailyBurn(
            localActivityCalories: targetSummary.localActivityCalories,
            workoutTrackerCalories: wtCals,
            healthKitWorkoutCalories: priorExternalWorkouts,
            otherExternalWorkoutCalories: 0,
            healthKitTotalActiveCalories: max(targetSummary.activeCaloriesBurned, targetSummary.activeCaloriesBurned + cals),
            stepsCount: targetSummary.stepsCount,
            isHealthKitEnabled: shouldSyncHealthKit
        )
        targetSummary.workoutCalories = reconciled.workoutCalories
        targetSummary.activeCaloriesBurned = reconciled.activeCaloriesBurned
        targetSummary.stepsCount = reconciled.stepsCount

        try? context.save()
        WidgetReloader.reloadAll()

        let logTitle = activity.name
        Task {
            if shouldSyncHealthKit {
                let ids = await HealthKitManager.shared.saveWorkout(
                    activityType: activity.hkType,
                    calories: cals,
                    durationMinutes: duration,
                    date: workoutDate
                )
                await MainActor.run {
                    WorkoutSyncManager.shared.storeActivityHealthKitIDs(
                        workoutID: ids.workoutID,
                        energySampleID: ids.energySampleID,
                        title: logTitle,
                        date: workoutDate,
                        calories: cals,
                        durationMinutes: duration
                    )
                }
            }
            await MainActor.run {
                dismiss()
            }
        }
    }
}
