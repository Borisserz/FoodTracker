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
        let resolvedVersion = currentVersion ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
        #if DEBUG
        print("📱 App Version: \(resolvedVersion)")
        #endif
        
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
        guard let v1Components = parsedComponents(from: v1),
              let v2Components = parsedComponents(from: v2) else {
            return false
        }
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let c1 = i < v1Components.count ? v1Components[i] : 0
            let c2 = i < v2Components.count ? v2Components[i] : 0
            if c1 < c2 { return true }
            if c1 > c2 { return false }
        }
        return false
    }

    private nonisolated static func parsedComponents(from raw: String) -> [Int]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        var components: [Int] = []
        components.reserveCapacity(parts.count)
        for part in parts {
            guard !part.isEmpty,
                  part.allSatisfy({ $0 >= "0" && $0 <= "9" }),
                  let value = Int(part) else {
                return nil
            }
            components.append(value)
        }
        return components
    }
}
