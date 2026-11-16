import Foundation
import FirebaseAuth
import FirebaseAppCheck

/// Centralized client for the FoodTracker OpenRouter AI proxy (`foodAiProxy`).
/// Handles auth (Firebase ID + AppCheck), Remote Config URL resolution, timeouts, and JSON extraction.
final class GeminiProxyClient {
    static let shared = GeminiProxyClient()

    private let urlSession: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        config.waitsForConnectivity = true
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Public API (used by services)

    /// Sends a text-only prompt expecting a JSON response. Returns decoded type.
    func fetchJSON<T: Decodable>(prompt: String, responseType: T.Type) async throws -> T {
        let raw = try await performRequest(prompt: prompt, includeImage: nil, forceJSON: true)
        let cleaned = cleanJSONResponse(raw)
        return try decode(cleaned, as: T.self, rawForLogging: cleaned)
    }

    /// Sends a text-only prompt expecting raw text (e.g. chat, title).
    func fetchText(prompt: String) async throws -> String {
        return try await performRequest(prompt: prompt, includeImage: nil, forceJSON: false)
    }

    /// Sends a multimodal prompt (text + image) expecting JSON.
    func fetchJSONWithImage<T: Decodable>(
        prompt: String,
        base64Image: String,
        mimeType: String = "image/jpeg",
        responseType: T.Type
    ) async throws -> T {
        let raw = try await performRequest(prompt: prompt, includeImage: (base64Image, mimeType), forceJSON: true)
        let cleaned = cleanJSONResponse(raw)
        return try decode(cleaned, as: T.self, rawForLogging: cleaned)
    }

    // MARK: - Core Request

    private func performRequest(prompt: String, includeImage: (base64: String, mime: String)?, forceJSON: Bool) async throws -> String {
        let (authToken, appCheckToken) = try await getFirebaseTokens()

        let configuredURL = await RemoteConfigManager.shared.getString(forKey: AIProxyEndpoint.remoteConfigKey)
        let url = AIProxyEndpoint.resolve(configured: configuredURL)

        var parts: [[String: Any]] = [["text": prompt]]

        if let image = includeImage {
            parts.append([
                "inlineData": [
                    "mimeType": image.mime,
                    "data": image.base64
                ]
            ])
        }

        var generationConfig: [String: Any] = [
            "temperature": includeImage == nil ? 0.7 : 0.4   // slightly more deterministic for vision
        ]
        if forceJSON {
            generationConfig["responseMimeType"] = "application/json"
        }

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": parts
                ]
            ],
            "generationConfig": generationConfig
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await urlSession.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if httpResponse.statusCode == 429 {
                let retryAfter = Self.extractRetryAfter(httpResponse: httpResponse, data: data)
                throw GeminiProxyError.rateLimited(retryAfter: retryAfter)
            }
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GeminiProxyError.serverError(status: httpResponse.statusCode, body: body)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw GeminiProxyError.invalidResponse
        }

        // The proxy returns the Gemini response envelope.
        // We extract the text from candidates[0].content.parts[0].text
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let finalText = parts.first?["text"] as? String {
            return finalText
        }

        // Fallback: return raw (some streaming or error cases)
        return text
    }

    // MARK: - Auth (moved from duplicated code in services)

    private func getFirebaseTokens() async throws -> (authToken: String, appCheckToken: String) {
        let user: FirebaseAuth.User
        if let current = Auth.auth().currentUser {
            user = current
        } else {
            user = try await AnonymousAuthBootstrap.shared.ensureSignedIn()
        }
        let authToken = try await user.getIDToken()
        let appCheckToken = try await AppCheck.appCheck().token(forcingRefresh: false).token
        return (authToken, appCheckToken)
    }

    // MARK: - Helpers

    nonisolated static func extractRetryAfter(httpResponse: HTTPURLResponse, data: Data) -> String? {
        if let header = httpResponse.value(forHTTPHeaderField: "Retry-After"), !header.isEmpty {
            return header
        }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let seconds = obj["retryAfter"] {
            if let intVal = seconds as? Int { return String(intVal) }
            if let dblVal = seconds as? Double { return String(Int(dblVal)) }
            if let strVal = seconds as? String, !strVal.isEmpty { return strVal }
        }
        return nil
    }

    // MARK: - JSON Cleaning (delegated to AIResponseParsing)

    private func cleanJSONResponse(_ raw: String) -> String {
        AIResponseParsing.extractJSON(from: raw)
    }

    private func decode<T: Decodable>(_ jsonString: String, as type: T.Type, rawForLogging: String) throws -> T {
        guard let data = jsonString.data(using: .utf8) else {
            print("❌ GeminiProxyClient: Failed to convert cleaned string to Data")
            throw GeminiProxyError.decodingFailed(raw: rawForLogging)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("❌ GeminiProxyClient: JSON decode error: \(error)")
            print("📝 Raw AI response was: \(rawForLogging.prefix(500))...")
            throw GeminiProxyError.decodingFailed(raw: rawForLogging)
        }
    }
}

// MARK: - Errors

enum GeminiProxyError: LocalizedError {
    case invalidURL
    case serverError(status: Int, body: String)
    case rateLimited(retryAfter: String?)
    case invalidResponse
    case decodingFailed(raw: String)

    var errorDescription: String? {
        switch self {
        case .rateLimited(let retryAfter):
            if let r = retryAfter {
                return "AI rate limit reached. Retry after \(r) seconds."
            }
            return "AI rate limit reached. Please try again later."
        case .serverError(let status, _):
            return "AI service error (HTTP \(status))"
        default:
            return "AI service temporarily unavailable."
        }
    }
}
