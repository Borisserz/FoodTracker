import SwiftUI
import SwiftData

struct OnboardingMetrics {
    var age: Int = 25
    var height: Int = 175
    var weight: Int = 75
    var targetWeight: Int = 70
    var goal: String = "Lose Weight"
    var activityLevel: ActivityType = .none
    var gender: String = "Male"
}

struct RootOnboardingView: View {
    let onFinish: (OnboardingMetrics) -> Void

    var body: some View {
        SwissBentoOnboardingFlow(onFinish: onFinish)
    }
}
