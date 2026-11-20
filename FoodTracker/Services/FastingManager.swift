import SwiftUI
import Observation
import UserNotifications

struct FastingRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let planName: String
    let targetHours: Int
    let startTime: Date
    let endTime: Date
    let durationSeconds: TimeInterval
    let reachedGoal: Bool

    init(
        id: UUID = UUID(),
        planName: String,
        targetHours: Int,
        startTime: Date,
        endTime: Date,
        durationSeconds: TimeInterval,
        reachedGoal: Bool
    ) {
        self.id = id
        self.planName = planName
        self.targetHours = targetHours
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.reachedGoal = reachedGoal
    }
}

@MainActor
@Observable
final class FastingManager {
    static let shared = FastingManager()
    static let historyDefaultsKey = "fastingHistory_v1"
    private static let maxHistoryCount = 50

    var isFasting: Bool = false
    var planName: String = ""
    var targetHours: Int = 16
    var startTime: Date? = nil

    var elapsedTime: TimeInterval = 0
    var progress: Double = 0
    private(set) var history: [FastingRecord] = []

    // No more legacy repeating Timer. We drive updates via a structured async Task (see startTimer).
    private var updateTask: Task<Void, Never>?
    private var notificationGeneration: Int = 0

    nonisolated static func shouldApplyScheduledNotifications(
        capturedGeneration: Int,
        currentGeneration: Int,
        isFasting: Bool
    ) -> Bool {
        capturedGeneration == currentGeneration && isFasting
    }

    private init() {
        loadHistory()
        loadState()
    }

    var liveActivityManager: FastingLiveActivityManaging = FastingLiveActivityManager.shared

    func startFast(plan: FastingPlan) {
        guard plan.fastingHours > 0 else { return }
        let now = Date()
        self.startTime = now
        self.targetHours = plan.fastingHours
        self.planName = plan.title
        self.isFasting = true

        saveState()
        liveActivityManager.startActivity(planName: plan.title, targetHours: plan.fastingHours, startTime: now)
        startUpdateTask()
        HapticManager.shared.impact(style: .heavy)

        scheduleFastingNotifications(target: plan.fastingHours, startTime: now)
    }

    func startCustomFast(hours: Int) {
        let clampedHours = min(max(hours, 1), 168)
        let customTitle = String(localized: "Custom \(clampedHours)h")
        let customPlan = FastingPlan(
            category: .intermediate,
            title: customTitle,
            description: String(localized: "Custom fasting schedule."),
            icon: "timer",
            colorHex: "F25C78",
            isPopular: false,
            fastingHours: clampedHours,
            eatingHours: max(0, 24 - clampedHours),
            difficultyRating: 3,
            benefits: [],
            breakFastTip: String(localized: "Break your fast gently with protein and whole foods.")
        )
        startFast(plan: customPlan)
    }

    func updateStartTime(_ newStartTime: Date) {
        guard isFasting, targetHours > 0 else { return }
        let clampedStart = min(newStartTime, Date())
        self.startTime = clampedStart
        saveState()
        updateCalculations(notifyLiveActivity: false)
        liveActivityManager.reattachActivity(
            planName: planName,
            targetHours: targetHours,
            startTime: clampedStart,
            currentStage: currentPhase.name,
            progressPct: progress
        )
        scheduleFastingNotifications(target: targetHours, startTime: clampedStart)
        if updateTask == nil || updateTask?.isCancelled == true {
            startUpdateTask()
        }
    }

    func endFast(recordInHistory: Bool = true) {
        if recordInHistory, let start = startTime, targetHours > 0 {
            let now = Date()
            let duration = max(0, now.timeIntervalSince(start))
            if duration >= 60 {
                let record = FastingRecord(
                    planName: planName.isEmpty ? "\(targetHours)h Fast" : planName,
                    targetHours: targetHours,
                    startTime: start,
                    endTime: now,
                    durationSeconds: duration,
                    reachedGoal: duration >= Double(targetHours * 3600)
                )
                history.insert(record, at: 0)
                if history.count > Self.maxHistoryCount {
                    history = Array(history.prefix(Self.maxHistoryCount))
                }
                saveHistory()
            }
        }

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

    func clearHistory() {
        history.removeAll()
        UserDefaults.standard.removeObject(forKey: Self.historyDefaultsKey)
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.historyDefaultsKey),
              let decoded = try? JSONDecoder().decode([FastingRecord].self, from: data) else {
            history = []
            return
        }
        history = decoded
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: Self.historyDefaultsKey)
        }
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
        localizedRemainingTimeString
    }

    var localizedRemainingTimeString: String {
        let totalTargetSeconds = Double(targetHours * 3600)
        let remaining = max(totalTargetSeconds - elapsedTime, 0)

        if remaining == 0 { return String(localized: "Goal Reached! 🎉") }

        let h = Int(remaining) / 3600
        let m = (Int(remaining) % 3600) / 60
        let minuteText = String(format: "%02d", m)
        return String(localized: "\(h)h \(minuteText)m left")
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

    /// Ensures Live Activities match persisted fasting state on launch or foreground return.
    func reconcileLiveActivityOnAppActive() {
        if isFasting, targetHours > 0, let start = startTime {
            updateCalculations(notifyLiveActivity: false)
            liveActivityManager.reattachActivity(
                planName: planName.isEmpty ? "\(targetHours)h Fast" : planName,
                targetHours: targetHours,
                startTime: start,
                currentStage: currentPhase.name,
                progressPct: progress
            )
        } else {
            liveActivityManager.endActivity()
        }
    }

    private func stopUpdateTask() {
        updateTask?.cancel()
        updateTask = nil
    }

    static let fastingNotificationCategoryID = "FASTING_PHASE"

    private static let fastingNotificationIDs = [
        "fasting_goal_reached",
        "phase_4h",
        "phase_8h",
        "phase_12h",
        "phase_16h"
    ]

    nonisolated static func phaseNotificationCopy(forHours hours: Int) -> (title: String, body: String) {
        switch hours {
        case 4:
            return (
                String(localized: "Digestion Mode 🌱"),
                String(localized: "Blood sugar has normalized and digestion is winding down. Keep hydrating!")
            )
        case 8:
            return (
                String(localized: "Fat Burning Mode 🔥"),
                String(localized: "Glycogen is depleted. Your body is switching to fat for fuel.")
            )
        case 12:
            return (
                String(localized: "Ketosis Achieved 🧠"),
                String(localized: "Your liver is now producing ketones for energy and mental clarity.")
            )
        default:
            return (
                String(localized: "Autophagy Started 🧬"),
                String(localized: "Cellular repair and anti-aging processes are fully active.")
            )
        }
    }

    private func updateCalculations(notifyLiveActivity: Bool = true) {
        guard let start = startTime else { return }
        let now = Date()
        elapsedTime = max(0, now.timeIntervalSince(start))

        guard targetHours > 0 else {
            progress = 0
            return
        }

        let totalTargetSeconds = Double(targetHours * 3600)
        progress = min(elapsedTime / totalTargetSeconds, 1.0)
        if notifyLiveActivity {
            liveActivityManager.updateActivity(currentStage: currentPhase.name, progressPct: progress)
        }
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
            guard savedTime > 0, targetHours > 0 else {
                isFasting = false
                startTime = nil
                saveState()
                return
            }
            let savedStartDate = Date(timeIntervalSince1970: savedTime)
            startTime = savedStartDate
            updateCalculations(notifyLiveActivity: false)
            liveActivityManager.reattachActivity(
                planName: planName,
                targetHours: targetHours,
                startTime: savedStartDate,
                currentStage: currentPhase.name,
                progressPct: progress
            )
            // Re-establish live updates (structured task) without firing an immediate duplicate update before the first tick
            stopUpdateTask()
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
    }

    private func scheduleFastingNotifications(target: Int, startTime: Date = Date()) {
        guard target > 0 else { return }
        notificationGeneration += 1
        let capturedGeneration = notificationGeneration
        let elapsed = max(0, Date().timeIntervalSince(startTime))
        let center = UNUserNotificationCenter.current()

        center.removePendingNotificationRequests(withIdentifiers: Self.fastingNotificationIDs)

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            Task { @MainActor [weak self] in
                guard let self,
                      Self.shouldApplyScheduledNotifications(
                          capturedGeneration: capturedGeneration,
                          currentGeneration: self.notificationGeneration,
                          isFasting: self.isFasting
                      ) else { return }

                let goalDelay = TimeInterval(target * 3600) - elapsed
                if goalDelay > 0 {
                    self.scheduleAlert(
                        id: "fasting_goal_reached",
                        title: String(localized: "Goal Reached! 🏆"),
                        body: String(localized: "You've successfully completed your \(target)-hour fast. It's time to eat!"),
                        delayInSeconds: goalDelay
                    )
                }

                for milestone in [4, 8, 12, 16] where target > milestone {
                    let delay = TimeInterval(milestone * 3600) - elapsed
                    guard delay > 0 else { continue }
                    let copy = Self.phaseNotificationCopy(forHours: milestone)
                    self.scheduleAlert(id: "phase_\(milestone)h", title: copy.title, body: copy.body, delayInSeconds: delay)
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
        content.categoryIdentifier = Self.fastingNotificationCategoryID

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delayInSeconds, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }

    private func cancelFastingNotifications() {
        notificationGeneration += 1
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.fastingNotificationIDs)
        center.removeDeliveredNotifications(withIdentifiers: Self.fastingNotificationIDs)
    }
}
