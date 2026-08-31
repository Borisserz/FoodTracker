import SwiftUI
import UIKit
import OnboardingKit

struct SwissBentoOnboardingFlow: View {
    let onFinish: (OnboardingMetrics) -> Void
    
    @State private var stage: Int = 0
    @State private var metrics = OnboardingMetrics()
    
    // Live calculated nutrition metrics
    private var calculatedBMR: Int {
        // Mifflin-St Jeor Formula
        let s = 5 // Male approx baseline
        let bmr = Double(10 * metrics.weight) + (6.25 * Double(metrics.height)) - Double(5 * metrics.age) + Double(s)
        return max(1200, Int(bmr))
    }
    
    private var dailyTargetCalories: Int {
        let base = calculatedBMR
        let multiplier: Double
        switch metrics.activityLevel {
        case .none, .office: multiplier = 1.2
        case .light: multiplier = 1.375
        case .active: multiplier = 1.55
        case .beast: multiplier = 1.725
        }
        let tdee = Double(base) * multiplier
        
        switch metrics.goal {
        case "Lose Weight": return Int(tdee - 450)
        case "Build Muscle": return Int(tdee + 350)
        default: return Int(tdee)
        }
    }
    
    private var targetProtein: Int { Int(Double(metrics.weight) * 2.1) }
    private var targetCarbs: Int { max(100, (dailyTargetCalories - (targetProtein * 4) - (targetFats * 9)) / 4) }
    private var targetFats: Int { Int(Double(dailyTargetCalories) * 0.25 / 9.0) }
    
    private let stageNames = ["INTRO", "BIOMETRICS", "PROTOCOL", "TOOLS", "BLUEPRINT"]
    
    var body: some View {
        ZStack {
            Color.swissGraphite.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Interactive Swiss Navigation Bar
                SwissOnboardingNavBar(
                    currentStage: stage,
                    totalStages: 5,
                    stageNames: stageNames,
                    onBack: { previousStage() },
                    onSelectStage: { selected in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            stage = selected
                        }
                    }
                )
                
                // Stage Views
                TabView(selection: $stage) {
                    Stage0WelcomeView(onNext: { nextStage() })
                        .tag(0)
                    
                    Stage1BiometricsView(
                        metrics: $metrics,
                        bmr: calculatedBMR,
                        targetCalories: dailyTargetCalories,
                        protein: targetProtein,
                        carbs: targetCarbs,
                        fats: targetFats,
                        onNext: { nextStage() }
                    )
                    .tag(1)
                    
                    Stage2GoalProtocolView(
                        metrics: $metrics,
                        onNext: { nextStage() }
                    )
                    .tag(2)
                    
                    Stage3FeatureLabView(
                        onNext: { nextStage() }
                    )
                    .tag(3)
                    
                    Stage4BlueprintRevealView(
                        metrics: metrics,
                        calories: dailyTargetCalories,
                        protein: targetProtein,
                        carbs: targetCarbs,
                        fats: targetFats,
                        onFinish: { onFinish(metrics) }
                    )
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: stage)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func nextStage() {
        if stage < 4 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                stage += 1
            }
        } else {
            onFinish(metrics)
        }
    }
    
    private func previousStage() {
        if stage > 0 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                stage -= 1
            }
        }
    }
}

// MARK: - Stage 0: Welcome & Vision
private struct Stage0WelcomeView: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Hero Visual Preview Bento
            VStack(spacing: 12) {
                LaserScanViewfinder()
                    .frame(height: 230)
                
                HStack(spacing: 12) {
                    WaveLiquidHydrationView()
                    CircadianFastingClock()
                }
            }
            .padding(.horizontal, 16)
            
            // Value Statement
            VStack(spacing: 8) {
                HStack {
                    Text("FOODTRACKER")
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.swissChartreuse)
                    
                    Text("• SWISS PRO v3")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                
                Text("Precision Nutrition & Metabolic Engine")
                    .font(.system(size: 26, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            
            Spacer()
            
            // CTA
            Button(action: onNext) {
                Text("Initialize Setup →")
            }
            .buttonStyle(SwissPillCTAButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Stage 1: Biometrics Lab
private struct Stage1BiometricsView: View {
    @Binding var metrics: OnboardingMetrics
    let bmr: Int
    let targetCalories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let onNext: () -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("BIOMETRIC CALIBRATION")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.swissChartreuse)
                    
                    Text("Enter Body Metrics")
                        .font(.system(size: 28, weight: .black, design: .default))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Live Macro Summary Bento Card
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("LIVE METABOLIC ESTIMATION")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundStyle(Color.swissChartreuse)
                            Text("Real-Time Target")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Text("\(targetCalories) kcal")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(Color.swissChartreuse)
                            .contentTransition(.numericText())
                    }
                    
                    Divider().background(Color.swissBorder)
                    
                    HStack(spacing: 8) {
                        MacroBadge(title: "PROTEIN", amount: "\(protein)g", color: .swissCyan)
                        MacroBadge(title: "CARBS", amount: "\(carbs)g", color: .swissChartreuse)
                        MacroBadge(title: "FATS", amount: "\(fats)g", color: .swissCoral)
                    }
                }
                .padding(16)
                .background(Color.swissCardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.swissBorder, lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                // Rulers
                VStack(spacing: 14) {
                    SwissTapeRuler(title: "Age", unit: "yo", range: 16...99, value: $metrics.age)
                    SwissTapeRuler(title: "Height", unit: "cm", range: 130...225, value: $metrics.height)
                    SwissTapeRuler(title: "Current Weight", unit: "kg", range: 40...200, value: $metrics.weight)
                }
                .padding(.horizontal, 20)
                
                // Continue Button
                Button(action: onNext) {
                    Text("Confirm Biometrics →")
                }
                .buttonStyle(SwissPillCTAButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Stage 2: Goal Protocol Matrix
private struct Stage2GoalProtocolView: View {
    @Binding var metrics: OnboardingMetrics
    let onNext: () -> Void
    
    private let goals: [(name: String, desc: String, icon: String, tag: String)] = [
        ("Lose Weight", "Burn visceral fat and preserve lean metabolic mass.", "flame.fill", "FAT LOSS"),
        ("Maintain Weight", "Optimize metabolic longevity and daily energy consistency.", "heart.fill", "HEALTH"),
        ("Build Muscle", "Hypertrophy-driven caloric surplus with high amino acids.", "bolt.fill", "HYPERTROPHY"),
    ]
    
    private let activities: [(type: ActivityType, name: String, desc: String)] = [
        (.office, "Sedentary / Office", "Desk work, < 4,000 steps/day"),
        (.light, "Light Active", "1-3 workouts / week or active job"),
        (.active, "Active Metabolism", "3-5 high-intensity sessions / week"),
        (.beast, "Turbo Mode Athlete", "Daily intense training or physical labor"),
    ]
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                VStack(alignment: .leading, spacing: 6) {
                    Text("STRATEGY MATRIX")
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.swissChartreuse)
                    
                    Text("Choose Your Protocol")
                        .font(.system(size: 28, weight: .black, design: .default))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                // Goal Cards
                VStack(spacing: 12) {
                    ForEach(goals, id: \.name) { item in
                        let isSelected = metrics.goal == item.name
                        Button(action: {
                            metrics.goal = item.name
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.prepare()
                            generator.impactOccurred()
                        }) {
                            HStack(spacing: 14) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 22))
                                    .foregroundStyle(isSelected ? Color.black : Color.swissChartreuse)
                                    .frame(width: 44, height: 44)
                                    .background(isSelected ? Color.swissChartreuse : Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(item.name)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(isSelected ? .white : .white.opacity(0.9))
                                        Spacer()
                                        SwissTagBadge(text: item.tag, color: isSelected ? .swissChartreuse : .white.opacity(0.4))
                                    }
                                    
                                    Text(item.desc)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .lineLimit(2)
                                }
                            }
                            .padding(16)
                            .background(isSelected ? Color.swissCardElevated : Color.swissCardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(isSelected ? Color.swissChartreuse : Color.swissBorder, lineWidth: isSelected ? 1.5 : 1)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                
                // Activity Level Chips
                VStack(alignment: .leading, spacing: 10) {
                    Text("DAILY ACTIVITY EXPENDITURE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        ForEach(activities, id: \.type) { act in
                            let isSelected = metrics.activityLevel == act.type
                            Button(action: {
                                metrics.activityLevel = act.type
                                let generator = UIImpactFeedbackGenerator(style: .soft)
                                generator.prepare()
                                generator.impactOccurred()
                            }) {
                                HStack {
                                    Text(act.name)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundStyle(isSelected ? Color.swissChartreuse : .white.opacity(0.8))
                                    Spacer()
                                    Text(act.desc)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(isSelected ? Color.swissChartreuse.opacity(0.1) : Color.swissCardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(isSelected ? Color.swissChartreuse : Color.swissBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                // Action
                Button(action: onNext) {
                    Text("Lock Protocol →")
                }
                .buttonStyle(SwissPillCTAButtonStyle())
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Stage 3: Feature Lab
private struct Stage3FeatureLabView: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("INTELLIGENT SUITE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(Color.swissChartreuse)
                
                Text("All Tools Included")
                    .font(.system(size: 28, weight: .black, design: .default))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Bento Grid Feature Showcase
            VStack(spacing: 12) {
                LaserScanViewfinder()
                
                HStack(spacing: 12) {
                    WaveLiquidHydrationView()
                    CircadianFastingClock()
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: onNext) {
                Text("Generate Blueprint →")
            }
            .buttonStyle(SwissPillCTAButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Stage 4: Blueprint Reveal
private struct Stage4BlueprintRevealView: View {
    let metrics: OnboardingMetrics
    let calories: Int
    let protein: Int
    let carbs: Int
    let fats: Int
    let onFinish: () -> Void
    
    @State private var progressCount: Int = 0
    @State private var isCompleted: Bool = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // AI Synthesis Dial
            ZStack {
                Circle()
                    .stroke(Color.swissBorder, lineWidth: 12)
                    .frame(width: 170, height: 170)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(progressCount) / 100.0)
                    .stroke(
                        Color.swissChartreuse,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color.swissChartreuseGlow, radius: 12)
                
                VStack(spacing: 4) {
                    Text("\(progressCount)%")
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    Text("CALIBRATED")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(Color.swissChartreuse)
                }
            }
            
            // Headline
            VStack(spacing: 6) {
                Text("Your Metabolic Blueprint")
                    .font(.system(size: 26, weight: .black, design: .default))
                    .foregroundStyle(.white)
                
                Text("Personalized for \(metrics.goal.lowercased()) with \(calories) kcal/day")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            
            // Macro Grid
            HStack(spacing: 12) {
                BlueprintPill(title: "DAILY ENERGY", val: "\(calories)", unit: "kcal", color: .swissChartreuse)
                BlueprintPill(title: "PROTEIN", val: "\(protein)", unit: "g", color: .swissCyan)
                BlueprintPill(title: "CARBS", val: "\(carbs)", unit: "g", color: .white)
                BlueprintPill(title: "FATS", val: "\(fats)", unit: "g", color: .swissCoral)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            Button(action: onFinish) {
                Text("Start Tracking Now →")
            }
            .buttonStyle(SwissPillCTAButtonStyle(isEnabled: isCompleted))
            .disabled(!isCompleted)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
                if progressCount < 100 {
                    progressCount += 2
                } else {
                    timer.invalidate()
                    isCompleted = true
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(.success)
                }
            }
        }
    }
}

// MARK: - Macro Badges & Helper Views
private struct MacroBadge: View {
    let title: String
    let amount: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(amount)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.swissCardElevated)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct BlueprintPill: View {
    let title: String
    let val: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(color)
            Text(val)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
            Text(unit)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.swissCardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.swissBorder, lineWidth: 1)
        )
    }
}
