import Foundation

/// Resolves the FoodTracker AI proxy URL. Remote Config (`food_ai_proxy_url`) may override it;
/// anything that is not a valid HTTPS URL falls back to the deployed `foodAiProxy` endpoint.
nonisolated enum AIProxyEndpoint {
    static let fallbackURLString = "https://us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net/foodAiProxy"
    static let remoteConfigKey = "food_ai_proxy_url"

    static var fallbackURL: URL {
        URL(string: fallbackURLString)!
    }

    static func resolve(configured: String?) -> URL {
        let trimmed = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              let host = url.host,
              !host.isEmpty else {
            return fallbackURL
        }
        return url
    }
}
