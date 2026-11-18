import SwiftUI
import Observation
import UserNotifications

@MainActor
@Observable
final class FastingManager {
    static let shared = FastingManager()

    var isFasting: Bool = false
    var planName: String = ""
    var targetHours: Int = 16
    var startTime: Date? = nil

    var elapsedTime: TimeInterval = 0
    var progress: Double = 0

    // No more legacy repeating Timer. We drive updates via a structured async Task (see startTimer).
    private var updateTask: Task<Void, Never>?

    private init() {
        loadState()
    }

    var liveActivityManager: FastingLiveActivityManaging = FastingLiveActivityManager.shared

    func startFast(plan: FastingPlan) {
        let now = Date()
        self.startTime = now
        self.targetHours = plan.fastingHours
        self.planName = plan.title
        self.isFasting = true

        saveState()
        liveActivityManager.startActivity(planName: plan.title, targetHours: plan.fastingHours, startTime: now)
        startUpdateTask()
        HapticManager.shared.impact(style: .heavy)

        scheduleFastingNotifications(target: plan.fastingHours)
    }

    func endFast() {
        self.isFasting = false
        self.startTime = nil
        self.elapsedTime = 0
        self.progress = 0

        saveState()
        stopUpdateTask()
        liveActivityManager.endActivity()
        HapticManager.shared.impact(style: .rigid)

        cancelFastingNotifications()
    }

    var currentPhase: (name: String, icon: String, color: Color) {
        let hours = elapsedTime / 3600

        if hours < 4 {
            return ("Blood Sugar Normalizing", "drop.fill", .cyan)
        } else if hours < 8 {
            return ("Digestion Mode", "leaf.fill", .green)
        } else if hours < 12 {
            return ("Fat Burning Begins", "flame.fill", .themeOrange)
        } else if hours < 16 {
            return ("Ketosis State", "brain.head.profile", .themePink)
        } else {
            return ("Deep Autophagy", "sparkles", .purple)
        }
    }

    var elapsedTimeString: String {
        let h = Int(elapsedTime) / 3600
        let m = (Int(elapsedTime) % 3600) / 60
        let s = Int(elapsedTime) % 60
        return String(format: "%02dh %02dm %02ds", h, m, s)
    }

    var remainingTimeString: String {
        let totalTargetSeconds = Double(targetHours * 3600)
        let remaining = max(totalTargetSeconds - elapsedTime, 0)

        if remaining == 0 { return "Goal Reached! 🎉" }

        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        return String(format: "%dh %02dm left", h, m)
    }

    nonisolated static func shouldContinueTimerLoop(isFasting: Bool, targetHours: Int, progress: Double) -> Bool {
        isFasting && targetHours > 0
    }

    private func startUpdateTask() {
        stopUpdateTask()
        updateCalculations()
        guard isFasting, targetHours > 0, startTime != nil else { return }

        updateTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let self, Self.shouldContinueTimerLoop(isFasting: self.isFasting, targetHours: self.targetHours, progress: self.progress) else {
                    break
                }
                self.updateCalculations()
            }
        }
    }

    /// Refreshes elapsed fasting state when the app returns to foreground.
    func refreshOnForeground() {
        guard isFasting, targetHours > 0, startTime != nil else { return }
        updateCalculations()
        if updateTask == nil || updateTask?.isCancelled == true {
            startUpdateTask()
        }
    }

    private func stopUpdateTask() {
        updateTask?.cancel()
        updateTask = nil
    }

    private static let fastingNotificationIDs = [
        "fasting_goal_reached",
        "phase_4h",
        "phase_8h",
        "phase_12h",
        "phase_16h"
    ]

    private func updateCalculations() {
        guard let start = startTime else { return }
        let now = Date()
        elapsedTime = max(0, now.timeIntervalSince(start))

        guard targetHours > 0 else {
            progress = 0
            return
        }

        let totalTargetSeconds = Double(targetHours * 3600)
        progress = min(elapsedTime / totalTargetSeconds, 1.0)
        liveActivityManager.updateActivity(currentStage: currentPhase.name, progressPct: progress)
    }

    private func saveState() {
        UserDefaults.standard.set(isFasting, forKey: "isFasting")
        UserDefaults.standard.set(planName, forKey: "fastingPlanName")
        UserDefaults.standard.set(targetHours, forKey: "fastingTargetHours")
        if let start = startTime {
            UserDefaults.standard.set(start.timeIntervalSince1970, forKey: "fastingStartTime")
        } else {
            UserDefaults.standard.removeObject(forKey: "fastingStartTime")
        }
    }

    /// Rehydrates active fasting state from UserDefaults (invoked at launch and unit tests).
    func restorePersistedState() {
        loadState()
    }

    private func loadState() {
        isFasting = UserDefaults.standard.bool(forKey: "isFasting")
        if isFasting {
            planName = UserDefaults.standard.string(forKey: "fastingPlanName") ?? "Custom"
            targetHours = UserDefaults.standard.integer(forKey: "fastingTargetHours")
            let savedTime = UserDefaults.standard.double(forKey: "fastingStartTime")
            guard savedTime > 0 else {
                isFasting = false
                startTime = nil
                saveState()
                return
            }
            let savedStartDate = Date(timeIntervalSince1970: savedTime)
            startTime = savedStartDate
            updateCalculations()
            liveActivityManager.reattachActivity(
                planName: planName,
                targetHours: targetHours,
                startTime: savedStartDate,
                currentStage: currentPhase.name,
                progressPct: progress
            )
            // Re-establish live updates (structured task)
            startUpdateTask()
        }
    }

    private func scheduleFastingNotifications(target: Int) {
        guard target > 0 else { return }
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: Self.fastingNotificationIDs)

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isFasting else { return }

                self.scheduleAlert(
                    id: "fasting_goal_reached",
                    title: "Goal Reached! 🏆",
                    body: "You've successfully completed your \(target)-hour fast. It's time to eat!",
                    delayInSeconds: TimeInterval(target * 3600)
                )

                if target > 4 {
                    self.scheduleAlert(id: "phase_4h", title: "Blood Sugar Normalizing 🩸", body: "Your insulin is dropping. Your body is resting. Stay hydrated!", delayInSeconds: 4 * 3600)
                }
                if target > 8 {
                    self.scheduleAlert(id: "phase_8h", title: "Fat Burning Mode 🔥", body: "Glycogen is depleted. Your body is switching to fat for fuel.", delayInSeconds: 8 * 3600)
                }
                if target > 12 {
                    self.scheduleAlert(id: "phase_12h", title: "Ketosis Achieved 🧠", body: "Your liver is now producing ketones for energy and mental clarity.", delayInSeconds: 12 * 3600)
                }
                if target > 16 {
                    self.scheduleAlert(id: "phase_16h", title: "Autophagy Started 🧬", body: "Cellular repair and anti-aging processes are fully active.", delayInSeconds: 16 * 3600)
                }
            }
        }
    }

    private func scheduleAlert(id: String, title: String, body: String, delayInSeconds: TimeInterval) {
        guard delayInSeconds > 0 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delayInSeconds, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    private func cancelFastingNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.fastingNotificationIDs)
        center.removeDeliveredNotifications(withIdentifiers: Self.fastingNotificationIDs)
    }
}
