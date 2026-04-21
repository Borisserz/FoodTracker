import SwiftUI
import Observation
import UserNotifications

@Observable
final class FastingManager {
    static let shared = FastingManager()

    var isFasting: Bool = false
    var planName: String = ""
    var targetHours: Int = 16
    var startTime: Date? = nil

    var elapsedTime: TimeInterval = 0
    var progress: Double = 0

    private var timer: Timer?

    private init() {
        loadState()
    }

    func startFast(plan: FastingPlan) {
        let now = Date()
        self.startTime = now
        self.targetHours = plan.fastingHours
        self.planName = plan.title
        self.isFasting = true

        saveState()
        startTimer()
        HapticManager.shared.impact(style: .heavy)

        scheduleFastingNotifications(target: plan.fastingHours)
    }

    func endFast() {
        self.isFasting = false
        self.startTime = nil
        self.elapsedTime = 0
        self.progress = 0

        saveState()
        stopTimer()
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

    private func startTimer() {
        stopTimer()
        updateCalculations()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCalculations()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateCalculations() {
        guard let start = startTime else { return }
        let now = Date()
        elapsedTime = now.timeIntervalSince(start)

        let totalTargetSeconds = Double(targetHours * 3600)
        progress = min(elapsedTime / totalTargetSeconds, 1.0)
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

    private func loadState() {
        isFasting = UserDefaults.standard.bool(forKey: "isFasting")
        if isFasting {
            planName = UserDefaults.standard.string(forKey: "fastingPlanName") ?? "Custom"
            targetHours = UserDefaults.standard.integer(forKey: "fastingTargetHours")
            let savedTime = UserDefaults.standard.double(forKey: "fastingStartTime")
            startTime = Date(timeIntervalSince1970: savedTime)
            startTimer()
        }
    }

    private func scheduleFastingNotifications(target: Int) {
        let center = UNUserNotificationCenter.current()

        center.removeAllPendingNotificationRequests()

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted else { return }

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

    private func scheduleAlert(id: String, title: String, body: String, delayInSeconds: TimeInterval) {
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
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
