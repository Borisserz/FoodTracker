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

    static let imageFallbackURLString = "https://us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net/imageProxy"
    static let imageRemoteConfigKey = "food_image_proxy_url"

    static var fallbackURL: URL {
        URL(string: fallbackURLString)!
    }

    static var searchFallbackURL: URL {
        URL(string: searchFallbackURLString)!
    }

    static var deleteAccountFallbackURL: URL {
        URL(string: deleteAccountFallbackURLString)!
    }

    static var imageFallbackURL: URL {
        URL(string: imageFallbackURLString)!
    }

    static func resolve(configured: String?, fallback: URL = fallbackURL) -> URL {
        let trimmed = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              let host = url.host,
              !host.isEmpty else {
            return fallback
        }
        return url
    }
}
