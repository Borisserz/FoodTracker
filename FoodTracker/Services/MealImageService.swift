import Foundation
import FirebaseAppCheck

/// Резолвит URL фото блюда через серверный imageProxy
/// (Pexels + глобальный кэш Firestore). Ключ Pexels в приложение не попадает.
final class MealImageService {
    static let shared = MealImageService()
    private init() {}

    func resolveImageURL(keywords: [String], title: String) async -> URL? {
        let configured = await RemoteConfigManager.shared.getString(forKey: AIProxyEndpoint.imageRemoteConfigKey)
        let url = AIProxyEndpoint.resolve(configured: configured, fallback: AIProxyEndpoint.imageFallbackURL)
        guard let appCheckToken = try? await AppCheck.appCheck()
            .token(forcingRefresh: false).token else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 12
        req.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "keywords": keywords,
            "title": title
        ])

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let urlStr = json["url"] as? String, !urlStr.isEmpty else {
            return nil
        }
        return URL(string: urlStr)
    }
}
