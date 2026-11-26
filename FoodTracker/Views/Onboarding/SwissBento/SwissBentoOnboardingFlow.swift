import SwiftUI
import UIKit

enum OnboardingStageGuard {
    static func canAdvance(from stage: Int, metrics: OnboardingMetrics) -> Bool {
        switch stage {
        case 2:
            return metrics.activityLevel != .none
        case 0, 1, 3:
            return true
        default:
            return false
        }
    }

    static func clampedStage(_ requested: Int, current: Int, metrics: OnboardingMetrics) -> Int {
        let bounded = min(max(requested, 0), 4)
        if bounded <= current {
            return bounded
        }
        var allowed = current
        while allowed < bounded && canAdvance(from: allowed, metrics: metrics) {
            allowed += 1
        }
        return allowed
    }

    static func canFinish(metrics: OnboardingMetrics) -> Bool {
        metrics.activityLevel != .none
    }
}

struct SwissBentoOnboardingFlow: View {
    let onFinish: (OnboardingMetrics) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: Int = 0
    @State private var metrics = OnboardingMetrics()

    private var blueprint: MetabolicBlueprint {
        MetabolicBlueprintCalculator.calculate(for: metrics)
    }

    private var stagePaletteIndex: Int {
        switch stage {
        case 0: return 0 // Forest Sage
        case 1: return 1 // Deep Ocean Teal
        case 2: return 2 // Roasted Espresso Amber
        case 3: return 3 // Midnight Cobalt
        default: return 0 // Forest Sage (matches Home tab seamlessly)
        }
    }

    private let stageNames = ["Welcome", "Body", "Goal", "Tools", "Plan"]

    var body: some View {
        ZStack {
            DynamicAuroraBackgroundView(pinnedPaletteIndex: stagePaletteIndex)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                SwissOnboardingNavBar(
                    currentStage: stage,
                    totalStages: 5,
                    stageNames: stageNames,
                    onBack: { previousStage() },
                    onSelectStage: { selected in
                        let target = OnboardingStageGuard.clampedStage(selected, current: stage, metrics: metrics)
                        if reduceMotion {
                            stage = target
                        } else {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                stage = target
                            }
                        }
                    }
                )

                Group {
                    switch stage {
                    case 0:
                        Stage0WelcomeView(onNext: { nextStage() })
                    case 1:
                        Stage1BiometricsView(
                            metrics: $metrics,
                            blueprint: blueprint,
                            onNext: { nextStage() }
                        )
                    case 2:
                        Stage2GoalProtocolView(
                            metrics: $metrics,
                            onNext: { nextStage() }
                        )
                    case 3:
                        Stage3FeatureLabView(
                            weightKg: metrics.weight,
                            onNext: { nextStage() }
                        )
                    default:
                        Stage4BlueprintRevealView(
                            metrics: metrics,
                            blueprint: blueprint,
                            onFinish: {
                                guard OnboardingStageGuard.canFinish(metrics: metrics) else { return }
                                HapticManager.shared.notification(type: .success)
                                onFinish(metrics)
                            }
                        )
                    }
                }
                .onChange(of: metrics.weight) { _, newWeight in
                    metrics.targetWeight = MetabolicBlueprintCalculator.sanitizedTargetWeight(
                        for: metrics.goal,
                        weight: newWeight,
                        targetWeight: metrics.targetWeight
                    )
                }
                .onChange(of: metrics.goal) { _, newGoal in
                    metrics.targetWeight = MetabolicBlueprintCalculator.sanitizedTargetWeight(
                        for: newGoal,
                        weight: metrics.weight,
                        targetWeight: metrics.targetWeight
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.84), value: stage)
            }
        }
    }

    private func nextStage() {
        if stage < 4 {
            guard OnboardingStageGuard.canAdvance(from: stage, metrics: metrics) else { return }
            if reduceMotion {
                stage += 1
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                    stage += 1
                }
            }
        } else if OnboardingStageGuard.canFinish(metrics: metrics) {
            HapticManager.shared.notification(type: .success)
            onFinish(metrics)
        }
    }

    private func previousStage() {
        guard stage > 0 else { return }
        if reduceMotion {
            stage -= 1
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.84)) {
                stage -= 1
            }
        }
    }
}

// MARK: - Stage 0: Core Product Introduction
private struct Stage0WelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily calories, macros, and meal tracking")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Estimate meals from photos or barcodes and keep daily energy targets in focus.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            LaserScanViewfinder()
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                factItem(icon: "function", text: "Mifflin-St Jeor target")
                Rectangle()
                    .fill(EditorialPalette.hairlineLight)
                    .frame(width: 1, height: 18)
                factItem(icon: "heart.fill", text: "Apple Health")
            }
            .padding(.horizontal, 22)

            Spacer(minLength: 12)

            Button(action: onNext) {
                Text("Get Started")
            }
            .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite))
            .accessibilityIdentifier("onboarding_stage0_next")
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func factItem(icon: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(EditorialPalette.forest)
            Text(text)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(EditorialPalette.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

private enum OnboardingMetricsUIHelper {
    static func recommendedWaterLiters(for weightKg: Double) -> Double {
        let raw = max(1.6, min(3.8, weightKg * 0.032))
        return (raw * 10).rounded() / 10
    }

    static func weightIntBinding(_ target: Binding<Double>, useMetric: Bool) -> Binding<Int> {
        Binding(
            get: { Int(NutritionMath.displayWeight(target.wrappedValue, useMetric: useMetric).rounded()) },
            set: { newValue in
                target.wrappedValue = useMetric
                    ? Double(newValue)
                    : NutritionMath.kgFromDisplayWeight(Double(newValue), useMetric: false)
            }
        )
    }
}

// MARK: - Stage 1: Body Measurements & Live Estimate
private struct Stage1BiometricsView: View {
    @Binding var metrics: OnboardingMetrics
    let blueprint: MetabolicBlueprint
    let onNext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("useMetricSystem") private var useMetricSystem = true

    private var heightBinding: Binding<Int> {
        Binding(
            get: { NutritionMath.displayHeight(Double(metrics.height), useMetric: useMetricSystem) },
            set: { newValue in
                if useMetricSystem {
                    metrics.height = newValue
                } else {
                    metrics.height = Int(NutritionMath.cmFromDisplayHeight(Double(newValue), useMetric: false).rounded())
                }
            }
        )
    }

    private var weightBinding: Binding<Int> {
        OnboardingMetricsUIHelper.weightIntBinding($metrics.weight, useMetric: useMetricSystem)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your measurements")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                EditorialDarkCard(cornerRadius: 20, padding: 16) {
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Estimated daily target")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(EditorialPalette.oat.opacity(0.85))
                                Text("Daily calorie target")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Text("\(blueprint.dailyCalories) kcal")
                                .font(.system(size: 24, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(EditorialPalette.oat)
                                .contentTransition(reduceMotion ? .identity : .numericText())
                        }

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 0.75)

                        HStack(spacing: 8) {
                            EditorialMetricChip(label: "Protein", value: String(localized: "\(blueprint.proteinGrams) g"), accent: EditorialPalette.oceanSlate)
                            EditorialMetricChip(label: "Carbs", value: String(localized: "\(blueprint.carbsGrams) g"), accent: EditorialPalette.oat)
                            EditorialMetricChip(label: "Fat", value: String(localized: "\(blueprint.fatGrams) g"), accent: EditorialPalette.warmAmber)
                        }
                    }
                }
                .padding(.horizontal, 20)

                HStack(spacing: 10) {
                    genderPill("Male")
                    genderPill("Female")
                }
                .padding(.horizontal, 20)

                VStack(spacing: 12) {
                    SwissTapeRuler(title: "Age", unit: "yo", range: 16...99, value: $metrics.age)
                    SwissTapeRuler(
                        title: "Height",
                        unit: NutritionMath.heightUnit(useMetric: useMetricSystem),
                        range: useMetricSystem ? 130...225 : 51...89,
                        value: heightBinding
                    )
                    SwissTapeRuler(
                        title: "Current weight",
                        unit: NutritionMath.weightUnit(useMetric: useMetricSystem),
                        range: useMetricSystem ? 40...200 : 88...441,
                        value: weightBinding
                    )
                }
                .padding(.horizontal, 20)

                Button(action: onNext) {
                    Text("Continue")
                }
                .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite))
                .accessibilityIdentifier("onboarding_stage1_next")
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
        }
    }

    @ViewBuilder
    private func genderPill(_ option: String) -> some View {
        let isSelected = metrics.gender == option
        Button(action: {
            HapticManager.shared.impact(style: .light)
            metrics.gender = option
        }) {
            Text(LocalizedStringKey(option))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : EditorialPalette.inkPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isSelected ? EditorialPalette.cardDark : EditorialPalette.surfaceLight)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            isSelected ? EditorialPalette.cardBorderDarkFocused : EditorialPalette.hairlineLight,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stage 2: Goal & Activity Selection
private struct Stage2GoalProtocolView: View {
    @Binding var metrics: OnboardingMetrics
    let onNext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("useMetricSystem") private var useMetricSystem = true

    private var targetWeightBinding: Binding<Int> {
        OnboardingMetricsUIHelper.weightIntBinding($metrics.targetWeight, useMetric: useMetricSystem)
    }

    private struct GoalOption {
        let modelValue: String
        let titleKey: String
        let descriptionKey: String
        let icon: String
    }

    private let goals: [GoalOption] = [
        GoalOption(
            modelValue: "Lose Weight",
            titleKey: "Lose weight",
            descriptionKey: "Steady calorie deficit for gradual weight loss.",
            icon: "arrow.down.right"
        ),
        GoalOption(
            modelValue: "Maintain Weight",
            titleKey: "Maintain weight",
            descriptionKey: "Balanced calories to keep your current weight steady.",
            icon: "equal"
        ),
        GoalOption(
            modelValue: "Build Muscle",
            titleKey: "Build muscle",
            descriptionKey: "Calorie surplus and higher protein to support training.",
            icon: "arrow.up.right"
        )
    ]

    private var selectableActivities: [ActivityType] {
        ActivityType.allCases.filter { $0 != .none }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Choose your goal")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                VStack(spacing: 10) {
                    ForEach(goals, id: \.modelValue) { item in
                        let isSelected = metrics.goal == item.modelValue
                        Button(action: {
                            selectGoal(item.modelValue)
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(isSelected ? EditorialPalette.textOnOat : EditorialPalette.inkPrimary)
                                    .frame(width: 40, height: 40)
                                    .background(isSelected ? EditorialPalette.oat : Color.black.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(LocalizedStringKey(item.titleKey))
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(isSelected ? Color.white : EditorialPalette.inkPrimary)

                                    Text(LocalizedStringKey(item.descriptionKey))
                                        .font(.system(size: 12.5, weight: .regular, design: .rounded))
                                        .foregroundStyle(isSelected ? Color.white.opacity(0.75) : EditorialPalette.inkSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(EditorialPalette.emerald)
                                }
                            }
                            .padding(14)
                            .background(isSelected ? EditorialPalette.cardDark : EditorialPalette.surfaceLight)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(
                                        isSelected ? EditorialPalette.cardBorderDarkFocused : EditorialPalette.hairlineLight,
                                        lineWidth: isSelected ? 1.25 : 0.75
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                if metrics.goal != "Maintain Weight" {
                    SwissTapeRuler(
                        title: "Target weight",
                        unit: NutritionMath.weightUnit(useMetric: useMetricSystem),
                        range: useMetricSystem ? 40...200 : 88...441,
                        value: targetWeightBinding
                    )
                    .padding(.horizontal, 20)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Daily activity")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(EditorialPalette.inkPrimary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 8) {
                        ForEach(selectableActivities, id: \.self) { act in
                            let isSelected = metrics.activityLevel == act
                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                metrics.activityLevel = act
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: act.sfSymbolName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(isSelected ? EditorialPalette.emerald : EditorialPalette.inkSecondary)
                                        .frame(width: 28, height: 28)
                                        .background(isSelected ? EditorialPalette.emerald.opacity(0.16) : Color.black.opacity(0.05))
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(LocalizedStringKey(act.titleKey))
                                            .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                                            .foregroundStyle(isSelected ? Color.white : EditorialPalette.inkPrimary)

                                        Text(LocalizedStringKey(act.descriptionKey))
                                            .font(.system(size: 12, weight: .regular, design: .rounded))
                                            .foregroundStyle(isSelected ? Color.white.opacity(0.72) : EditorialPalette.inkSecondary)
                                    }

                                    Spacer()

                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(EditorialPalette.emerald)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(isSelected ? EditorialPalette.cardDark : EditorialPalette.surfaceLight)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? EditorialPalette.cardBorderDarkFocused : EditorialPalette.hairlineLight,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboarding_activity_\(String(describing: act))")
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button(action: onNext) {
                    Text(metrics.activityLevel == .none ? "Select Activity Level" : "Continue")
                }
                .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite, isEnabled: metrics.activityLevel != .none))
                .disabled(metrics.activityLevel == .none)
                .accessibilityIdentifier("onboarding_stage2_next")
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
        }
    }

    private func selectGoal(_ modelValue: String) {
        HapticManager.shared.impact(style: .medium)
        let apply = {
            metrics.goal = modelValue
            metrics.targetWeight = MetabolicBlueprintCalculator.sanitizedTargetWeight(
                for: modelValue,
                weight: metrics.weight,
                targetWeight: metrics.targetWeight
            )
        }
        if reduceMotion {
            apply()
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                apply()
            }
        }
    }
}

// MARK: - Stage 3: Daily Tools & Rhythm (No Stage 0 Duplication)
private struct Stage3FeatureLabView: View {
    let weightKg: Double
    let onNext: () -> Void

    private var recommendedWaterLiters: Double {
        OnboardingMetricsUIHelper.recommendedWaterLiters(for: weightKg)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Core tracking tools")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(EditorialPalette.inkPrimary)

                    Text("Water guide, fasting windows, and AI Chef recipes work together with your daily calorie balance.")
                        .font(.system(size: 14.5, weight: .regular, design: .rounded))
                        .foregroundStyle(EditorialPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                HStack(spacing: 12) {
                    WaveLiquidHydrationView(
                        fillPercentage: 0.72,
                        currentAmount: recommendedWaterLiters * 0.72,
                        targetAmount: recommendedWaterLiters
                    )
                    CircadianFastingClock()
                }
                .padding(.horizontal, 20)

                EditorialPhotoBackdropCard(
                    imageName: "chef_card_cooking",
                    minHeight: 164,
                    cornerRadius: 22,
                    scrimBottomOpacity: 0.88
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Chef Studio")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(EditorialPalette.oat)

                        Text("Recipes tailored to your remaining calories")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Cook with ingredients already in your kitchen.")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.78))
                    }
                }
                .frame(height: 168)
                .padding(.horizontal, 20)

                Button(action: onNext) {
                    Text("See My Plan")
                }
                .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .graphite))
                .accessibilityIdentifier("onboarding_stage3_next")
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
        }
    }
}

// MARK: - Stage 4: Instant Plan Summary
private struct Stage4BlueprintRevealView: View {
    let metrics: OnboardingMetrics
    let blueprint: MetabolicBlueprint
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("useMetricSystem") private var useMetricSystem = true

    private var displayGoalKey: String {
        switch metrics.goal {
        case "Lose Weight": return "Lose weight"
        case "Build Muscle": return "Build muscle"
        default: return "Maintain weight"
        }
    }

    private var waterGuideLiters: Double {
        OnboardingMetricsUIHelper.recommendedWaterLiters(for: metrics.weight)
    }

    private var macroCaloriesTotal: Double {
        let p = Double(blueprint.proteinGrams * 4)
        let f = Double(blueprint.fatGrams * 9)
        let c = Double(blueprint.carbsGrams * 4)
        return max(p + f + c, 1.0)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your daily target")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(EditorialPalette.inkPrimary)

                    HStack(spacing: 4) {
                        Text("Goal:")
                        Text(LocalizedStringKey(displayGoalKey))
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(EditorialPalette.inkSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                EditorialDarkCard(cornerRadius: 24, padding: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(EditorialPalette.emerald)
                                    .frame(width: 7, height: 7)
                                Text("Mifflin-St Jeor target")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.82))
                            }
                            Spacer()
                            Text(LocalizedStringKey(metrics.activityLevel.titleKey))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(EditorialPalette.oat.opacity(0.85))
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(blueprint.dailyCalories)")
                                .font(.system(size: 44, weight: .heavy, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                                .contentTransition(reduceMotion ? .identity : .numericText())

                            Text("kcal / day")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(EditorialPalette.oat)
                        }

                        // Proportional macro bar
                        GeometryReader { geo in
                            let pRatio = Double(blueprint.proteinGrams * 4) / macroCaloriesTotal
                            let fRatio = Double(blueprint.fatGrams * 9) / macroCaloriesTotal
                            let cRatio = max(0.0, 1.0 - pRatio - fRatio)

                            HStack(spacing: 3) {
                                Capsule()
                                    .fill(EditorialPalette.oceanSlate)
                                    .frame(width: max(8, geo.size.width * pRatio - 2))
                                Capsule()
                                    .fill(EditorialPalette.warmAmber)
                                    .frame(width: max(8, geo.size.width * fRatio - 2))
                                Capsule()
                                    .fill(EditorialPalette.oat)
                                    .frame(width: max(8, geo.size.width * cRatio - 2))
                            }
                        }
                        .frame(height: 7)

                        Rectangle()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 0.75)

                        HStack(spacing: 8) {
                            EditorialMetricChip(label: "Protein", value: String(localized: "\(blueprint.proteinGrams) g"), accent: EditorialPalette.oceanSlate)
                            EditorialMetricChip(label: "Fat", value: String(localized: "\(blueprint.fatGrams) g"), accent: EditorialPalette.warmAmber)
                            EditorialMetricChip(label: "Carbs", value: String(localized: "\(blueprint.carbsGrams) g"), accent: EditorialPalette.oat)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(EditorialPalette.oceanSlate)
                            Text("Water guide:")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                            Text(NutritionMath.formattedHydration(liters: waterGuideLiters, useMetric: useMetricSystem))
                                .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)

                NutritionMethodologyDisclaimerView(
                    citations: [.bmrAndTdee, .dietaryGuidelines],
                    style: .standard,
                    compact: true
                )
                .padding(.horizontal, 20)

                Button(action: onFinish) {
                    Text("Start Tracking")
                }
                .buttonStyle(EditorialPrimaryCTAButtonStyle(tone: .forest))
                .accessibilityIdentifier("onboarding_stage4_finish")
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
        }
    }
}
