//
//  RemoteConfigManager.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 26.04.26.
//

import Foundation
import FirebaseRemoteConfig

actor RemoteConfigManager: Sendable, VersionConfigProviding {
    func stringValue(forKey key: String) async -> String {
        getString(forKey: key)
    }

    static let shared = RemoteConfigManager()
    private let remoteConfig = RemoteConfig.remoteConfig()
    private var inFlightFetch: Task<Void, Never>?

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults([
            "food_minimum_ios_version": "1.0.0" as NSObject,
            "food_recommended_ios_version": "1.0.0" as NSObject,
            AIProxyEndpoint.remoteConfigKey: AIProxyEndpoint.fallbackURL.absoluteString as NSObject,
            AIProxyEndpoint.searchRemoteConfigKey: AIProxyEndpoint.searchFallbackURL.absoluteString as NSObject,
            AIProxyEndpoint.deleteAccountRemoteConfigKey: AIProxyEndpoint.deleteAccountFallbackURL.absoluteString as NSObject
        ])
    }

    func fetchCloudValues() async {
        if let existing = inFlightFetch {
            await existing.value
            return
        }
        let task = Task { [remoteConfig] in
            do {
                let status = try await remoteConfig.fetchAndActivate()
                if status == .successFetchedFromRemote {
                    print("☁️✅ FoodTracker: Свежие ключи загружены из облака!")
                } else {
                    print("☁️⚡️ FoodTracker: Используем кэш конфига.")
                }
            } catch {
                print("☁️❌ Ошибка Remote Config: \(error.localizedDescription)")
            }
        }
        inFlightFetch = task
        await task.value
        inFlightFetch = nil
    }

    func getString(forKey key: String) -> String {
        return remoteConfig.configValue(forKey: key).stringValue ?? ""
    }
}
