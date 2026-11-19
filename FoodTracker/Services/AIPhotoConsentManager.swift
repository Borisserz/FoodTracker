import Foundation
import Observation

/// Tracks explicit user consent before sending photos to third-party AI vision providers (OpenRouter).
@Observable
@MainActor
final class AIPhotoConsentManager {
    static let shared = AIPhotoConsentManager()
    nonisolated static let defaultsKey = "aiPhotoThirdPartyConsentGranted_v1"

    private let defaults: UserDefaults
    private(set) var hasConsented: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasConsented = defaults.bool(forKey: Self.defaultsKey)
    }

    func grantConsent() {
        defaults.set(true, forKey: Self.defaultsKey)
        hasConsented = true
    }

    func revokeConsent() {
        defaults.set(false, forKey: Self.defaultsKey)
        hasConsented = false
    }

    func syncFromDefaults() {
        hasConsented = defaults.bool(forKey: Self.defaultsKey)
    }
}
