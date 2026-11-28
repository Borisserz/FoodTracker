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
            ZStack {
                DynamicAuroraBackgroundView(pinnedPaletteIndex: 2)
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        Text("Log Activity")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(EditorialPalette.inkPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 14)

                        // Grid
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(activities) { activity in
                                let isSelected = selectedActivity == activity
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                        selectedActivity = activity
                                        updateCalories()
                                    }
                                    HapticManager.shared.impact(style: .light)
                                } label: {
                                    VStack(spacing: 10) {
                                        Image(systemName: activity.icon)
                                            .font(.system(size: 26, weight: .semibold))
                                            .foregroundStyle(isSelected ? EditorialPalette.warmAmber : EditorialPalette.inkPrimary)
                                        Text(LocalizedStringKey(activity.name))
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundStyle(isSelected ? .white : EditorialPalette.inkPrimary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(isSelected ? EditorialPalette.cardDark : Color.white.opacity(0.82))
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(
                                                isSelected ? EditorialPalette.cardBorderDarkFocused : EditorialPalette.hairlineLight,
                                                lineWidth: isSelected ? 1.25 : 0.75
                                            )
                                    )
                                }
                                .buttonStyle(BounceButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)

                        if let _ = selectedActivity {
                            EditorialDarkCard(cornerRadius: 22, padding: 20) {
                                VStack(spacing: 20) {
                                    // Duration Slider
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Duration")
                                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text("\(Int(durationMinutes)) min")
                                                .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                                                .foregroundStyle(EditorialPalette.oat)
                                        }
                                        Slider(value: Binding(get: { durationMinutes }, set: { durationMinutes = $0; updateCalories() }), in: 5...180, step: 5)
                                            .tint(EditorialPalette.oat)
                                    }

                                    Rectangle()
                                        .fill(Color.white.opacity(0.10))
                                        .frame(height: 0.5)

                                    // Calories Slider
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("Calories Burned")
                                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text("\(Int(caloriesBurned)) kcal")
                                                .font(.system(size: 18, weight: .heavy, design: .rounded).monospacedDigit())
                                                .foregroundStyle(EditorialPalette.warmAmber)
                                        }
                                        Slider(value: $caloriesBurned, in: 10...2000, step: 10)
                                            .tint(EditorialPalette.warmAmber)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }

                        Spacer(minLength: 24)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selectedActivity != nil {
                    Button(action: saveActivity) {
                        Text("Save Activity")
                    }
                    .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite, height: 54))
                    .disabled(isSaving)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(EditorialPalette.inkPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.84))
                            .clipShape(Circle())
                            .overlay(Circle().strokeBorder(EditorialPalette.hairlineLight, lineWidth: 0.75))
                    }
                }
            }
        }
    }
    
    static func clampedCalories(met: Double, weightKg: Double, durationMinutes: Double) -> Double {
        let calculated = met * max(0, weightKg) * (max(0, durationMinutes) / 60.0)
        let roundedStep = (calculated / 10.0).rounded() * 10.0
        return min(2000, max(10, roundedStep))
    }

    private func updateCalories() {
        guard let activity = selectedActivity else { return }
        caloriesBurned = Self.clampedCalories(
            met: activity.metValue,
            weightKg: userWeightKg,
            durationMinutes: durationMinutes
        )
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
