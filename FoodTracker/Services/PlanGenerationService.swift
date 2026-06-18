import SwiftUI
import SwiftData

/// Global singleton that manages the 7-day plan AI generation lifecycle.
/// Generation runs entirely in background so the user can navigate the app freely.
@Observable
@MainActor
final class PlanGenerationService {
    static let shared = PlanGenerationService()
    private init() {}

    enum Phase {
        case idle
        case generatingText          // AI is writing the plan
        case fetchingImages(done: Int, total: Int) // Downloading meal photos
        case ready(WeeklyMealPlan)   // Done – plan is ready to view
        case failed
    }

    private(set) var phase: Phase = .idle
    private var generationTask: Task<Void, Never>?

    // MARK: - Computed helpers

    var isActive: Bool {
        switch phase {
        case .idle, .failed: return false
        default: return true
        }
    }

    var isGenerating: Bool {
        switch phase {
        case .generatingText, .fetchingImages: return true
        default: return false
        }
    }

    var readyPlan: WeeklyMealPlan? {
        if case .ready(let plan) = phase { return plan }
        return nil
    }

    /// Short label shown inside the floating pill.
    var pillLabel: String {
        switch phase {
        case .idle: return ""
        case .generatingText: return "AI is cooking your week…"
        case .fetchingImages(let done, let total): return "Loading photos \(done)/\(total)"
        case .ready: return "Your plan is ready — tap to view ✨"
        case .failed: return "Generation failed. Try again."
        }
    }

    var imageProgress: Double {
        if case .fetchingImages(let done, let total) = phase, total > 0 {
            return Double(done) / Double(total)
        }
        return 0
    }

    // MARK: - Actions

    /// Start generation. The caller should dismiss the loading screen immediately
    /// so the user can freely navigate while this runs in background.
    func start(calories: Int, diet: String, complexity: String) {
        guard !isGenerating else { return }
        phase = .generatingText

        generationTask = Task { @MainActor in
            // ── Phase 1: AI text generation (~10–15 s) ──────────────────────
            guard let plan = await AINutritionService.shared.generateWeeklyPlan(
                targetCalories: calories,
                diet: diet,
                complexity: complexity
            ) else {
                if !Task.isCancelled { phase = .failed }
                return
            }

            if Task.isCancelled { return }
            
            // ── Phase 2: Show plan immediately ──────────────────────────
            // The text generation is the only blocking part. We show the plan immediately.
            phase = .ready(plan)
        }
    }

    func cancel() {
        generationTask?.cancel()
        generationTask = nil
        phase = .idle
    }

    /// Call after the user has opened and dismissed the ready plan.
    func acknowledge() {
        if case .ready = phase { phase = .idle }
    }
}
