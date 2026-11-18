import Foundation

/// Resolves FoodTracker Cloud Function URLs. Remote Config may override each endpoint;
/// anything that is not a valid HTTPS URL falls back to the deployed default.
nonisolated enum AIProxyEndpoint {
    static let fallbackURLString = "https://us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net/foodAiProxy"
    static let remoteConfigKey = "food_ai_proxy_url"

    static let searchFallbackURLString = "https://us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net/foodSearchProxy"
    static let searchRemoteConfigKey = "food_search_proxy_url"

    static let deleteAccountFallbackURLString = "https://us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net/foodDeleteAccount"
    static let deleteAccountRemoteConfigKey = "food_delete_account_url"

    static let defaultAllowedHosts: Set<String> = [
        "us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net"
    ]

    static var fallbackURL: URL {
        URL(string: fallbackURLString)!
    }

    static var searchFallbackURL: URL {
        URL(string: searchFallbackURLString)!
    }

    static var deleteAccountFallbackURL: URL {
        URL(string: deleteAccountFallbackURLString)!
    }

    static func resolve(
        configured: String?,
        fallback: URL = fallbackURL,
        allowedHosts: Set<String>? = nil
    ) -> URL {
        let trimmed = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var permittedHosts = allowedHosts ?? defaultAllowedHosts
        if allowedHosts == nil, let fallbackHost = fallback.host?.lowercased(), !fallbackHost.isEmpty {
            permittedHosts.insert(fallbackHost)
        }
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              let host = url.host?.lowercased(),
              !host.isEmpty,
              permittedHosts.contains(host) else {
            return fallback
        }
        return url
    }
}
