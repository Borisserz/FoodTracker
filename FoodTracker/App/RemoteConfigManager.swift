//
//  RemoteConfigManager.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 26.04.26.
//

import Foundation
import FirebaseRemoteConfig

actor RemoteConfigManager: Sendable {
    static let shared = RemoteConfigManager()
    private let remoteConfig = RemoteConfig.remoteConfig()

    private init() {
        let settings = RemoteConfigSettings()
        #if DEBUG
        settings.minimumFetchInterval = 0
        #else
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
    }

    func fetchCloudValues() async {
        do {
            let status = try await remoteConfig.fetchAndActivate()
            if status == .successFetchedFromRemote {
                print("Log output removed for English localization")
            } else {
                print("Log output removed for English localization")
            }
        } catch {
            print("Log output removed for English localization")
        }
    }

    func getString(forKey key: String) -> String {
        return remoteConfig.configValue(forKey: key).stringValue ?? ""
    }
}
