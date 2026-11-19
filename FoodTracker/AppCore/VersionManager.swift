import Foundation
import SwiftUI

protocol VersionConfigProviding: Sendable {
    func stringValue(forKey key: String) async -> String
}

@MainActor
@Observable
final class VersionManager {
    static let shared = VersionManager()
    
    var updateRequirement: UpdateRequirement = .noUpdate
    var hasDismissedSoftUpdate: Bool = false
    
    enum UpdateRequirement: Equatable {
        case hardUpdate
        case softUpdate
        case noUpdate
    }
    
    private init() {}
    
    func checkVersion(
        configProvider: any VersionConfigProviding = RemoteConfigManager.shared,
        currentVersion: String? = nil
    ) async {
        // Fetch values from Remote Config
        let minVersion = await configProvider.stringValue(forKey: "food_minimum_ios_version")
        let recVersion = await configProvider.stringValue(forKey: "food_recommended_ios_version")
        
        // Debug prints
        let resolvedVersion = currentVersion ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")
        print("📱 App Version: \(resolvedVersion)")
        
        let newRequirement = Self.evaluateRequirement(current: resolvedVersion, minimum: minVersion, recommended: recVersion)
        
        if newRequirement != self.updateRequirement {
            self.updateRequirement = newRequirement
        }
    }
    
    nonisolated static func evaluateRequirement(current: String, minimum: String, recommended: String) -> UpdateRequirement {
        if !minimum.isEmpty && isVersion(current, lessThan: minimum) {
            return .hardUpdate
        }
        if !recommended.isEmpty && isVersion(current, lessThan: recommended) {
            return .softUpdate
        }
        return .noUpdate
    }
    
    nonisolated static func isVersion(_ v1: String, lessThan v2: String) -> Bool {
        let v1Components = v1.split(separator: ".").compactMap { Int($0) }
        let v2Components = v2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let c1 = i < v1Components.count ? v1Components[i] : 0
            let c2 = i < v2Components.count ? v2Components[i] : 0
            if c1 < c2 { return true }
            if c1 > c2 { return false }
        }
        return false
    }
}
