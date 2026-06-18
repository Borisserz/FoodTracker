import SwiftUI
import SwiftData

/// Floating pill/dot visible on every screen while a plan is being generated.
/// - While generating: shows a pulsing circle with progress
/// - When ready: expands to a tappable pill "Plan ready — tap to view ✨"
/// - When tapped: presents WeeklyPlanOverview fullscreen
struct GenerationStatusPill: View {
    @Environment(\.modelContext) private var context
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var planService = PlanGenerationService.shared
    @State private var showPlan = false
    @State private var showBuilder = false
    @State private var showExitWarning = false
    @State private var pillExpanded = false
    @State private var pulse = false

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                pillContent
                    .padding(.trailing, 16)
                    .padding(.bottom, 150) // Moved up to prevent overlapping the plus button
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: planService.isActive)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: planService.readyPlan != nil)
        // Save plan to SwiftData as soon as it's ready
        .onChange(of: planService.readyPlan) { _, plan in
            guard let plan else { return }
            savePlan(plan)
        }
        // Warn user if they background the app during generation
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && planService.isGenerating {
                showExitWarning = true
            }
        }
        .alert("Generation Will Pause", isPresented: $showExitWarning) {
            Button("Keep Generating", role: .cancel) {}
            Button("Cancel Generation", role: .destructive) { planService.cancel() }
        } message: {
            Text("If the app is closed, your plan generation will be interrupted. Keep the app open for best results.")
        }
        .fullScreenCover(isPresented: $showPlan) {
            if let plan = planService.readyPlan {
                WeeklyPlanOverview(plan: plan) {
                    showPlan = false
                    planService.acknowledge()
                }
            }
        }
        .fullScreenCover(isPresented: $showBuilder) {
            SmartPlanBuilderFlow()
        }
    }

    @ViewBuilder
    private var pillContent: some View {
        if planService.isActive {
            if planService.readyPlan != nil {
                // ── Ready state: expanded pill ─────────────────────────────
                Button {
                    showPlan = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)

                        Text(planService.pillLabel)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.9))
                            .shadow(color: .green.opacity(0.5), radius: 12, y: 4)
                    )
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                // ── Generating state: compact pulsing circle ───────────────
                Button {
                    showBuilder = true
                } label: {
                    ZStack {
                        // Outer pulse ring
                        Circle()
                            .stroke(themeManager.current.primaryAccent.opacity(0.4), lineWidth: 2)
                            .scaleEffect(pulse ? 1.35 : 1.0)
                            .opacity(pulse ? 0 : 0.8)
                            .frame(width: 52, height: 52)

                        // Inner circle background
                        Circle()
                            .fill(.black.opacity(0.85))
                            .frame(width: 52, height: 52)
                            .shadow(color: themeManager.current.primaryAccent.opacity(0.5), radius: 8)

                        if case .fetchingImages(let done, let total) = planService.phase {
                            // Progress arc
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.15), lineWidth: 3)
                                    .frame(width: 40, height: 40)

                                Circle()
                                    .trim(from: 0, to: total > 0 ? CGFloat(done) / CGFloat(total) : 0)
                                    .stroke(themeManager.current.primaryAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .frame(width: 40, height: 40)
                                    .rotationEffect(.degrees(-90))

                                Image(systemName: "photo")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        } else {
                            // Sparkle while AI writes
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(themeManager.current.primaryAccent)
                        }
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        pulse = true
                    }
                }
                .transition(.scale.combined(with: .opacity))
                // Tooltip on long-press
                .contextMenu {
                    Text(planService.pillLabel)
                    Button("Cancel Generation", role: .destructive) { planService.cancel() }
                }
            }
        }
    }

    private func savePlan(_ plan: WeeklyMealPlan) {
        // Clean up old plans (keep only last 2)
        if let existing = try? context.fetch(
            FetchDescriptor<WeeklyMealPlan>(sortBy: [SortDescriptor(\.createdDate, order: .reverse)])
        ) {
            if existing.count >= 3 {
                for old in existing.dropFirst(2) { context.delete(old) }
            }
        }
        context.insert(plan)
        try? context.save()
    }
}
