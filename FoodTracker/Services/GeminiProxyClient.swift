import Foundation
import Observation
import Security
import FirebaseAuth
import FirebaseAppCheck

enum DeviceInstallIdentifier {
    private static let service = "com.borisdev.FoodTracker2026.deviceInstall"
    private static let account = "deviceInstallId"
    private static let lock = NSLock()
    private static var cachedId: String?

    static var current: String {
        lock.lock()
        defer { lock.unlock() }
        if let cachedId {
            return cachedId
        }
        if let existing = readFromKeychain() {
            cachedId = existing
            return existing
        }
        let generated = UUID().uuidString
        cachedId = generated
        saveToKeychain(generated)
        return generated
    }

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let id = String(data: data, encoding: .utf8),
              !id.isEmpty else {
            return nil
        }
        return id
    }

    private static func saveToKeychain(_ id: String) {
        guard let data = id.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let matchQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemUpdate(matchQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
    }
}

protocol GeminiProxyExecuting: Sendable {
    func fetchJSON<T: Decodable>(
        prompt: String,
        responseType: T.Type,
        maxOutputTokens: Int?,
        suppressRateLimitAlert: Bool
    ) async throws -> T

    func fetchText(prompt: String, suppressRateLimitAlert: Bool) async throws -> String

    func fetchJSONWithImage<T: Decodable>(
        prompt: String,
        base64Image: String,
        mimeType: String,
        responseType: T.Type
    ) async throws -> T

    func fetchJSONWithImages<T: Decodable>(
        prompt: String,
        images: [(base64: String, mime: String)],
        responseType: T.Type
    ) async throws -> T
}

extension GeminiProxyExecuting {
    func fetchJSON<T: Decodable>(
        prompt: String,
        responseType: T.Type,
        maxOutputTokens: Int? = nil,
        suppressRateLimitAlert: Bool = false
    ) async throws -> T {
        try await fetchJSON(
            prompt: prompt,
            responseType: responseType,
            maxOutputTokens: maxOutputTokens,
            suppressRateLimitAlert: suppressRateLimitAlert
        )
    }

    func fetchText(prompt: String, suppressRateLimitAlert: Bool = false) async throws -> String {
        try await fetchText(prompt: prompt, suppressRateLimitAlert: suppressRateLimitAlert)
    }

    func fetchJSONWithImage<T: Decodable>(
        prompt: String,
        base64Image: String,
        mimeType: String = "image/jpeg",
        responseType: T.Type
    ) async throws -> T {
        try await fetchJSONWithImage(
            prompt: prompt,
            base64Image: base64Image,
            mimeType: mimeType,
            responseType: responseType
        )
    }
}

/// Centralized client for the FoodTracker OpenRouter AI proxy (`foodAiProxy`).
/// Handles auth (Firebase ID + AppCheck), Remote Config URL resolution, timeouts, and JSON extraction.
@Observable
final class GeminiProxyClient: GeminiProxyExecuting, @unchecked Sendable {
    static let shared = GeminiProxyClient()

    static var shouldSuppressSecondaryErrorAlert: Bool {
        shared.rateLimitAlertMessage != nil
    }

    var rateLimitAlertMessage: String?

    @ObservationIgnored var session: URLSession
    @ObservationIgnored var tokenProvider: (() async throws -> (authToken: String, appCheckToken: String))?
    @ObservationIgnored var refreshingTokenProvider: ((_ forceRefresh: Bool) async throws -> (authToken: String, appCheckToken: String))?

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 105.0
        config.timeoutIntervalForResource = 120.0
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API (used by services)

    /// Sends a text-only prompt expecting a JSON response. Returns decoded type.
    func fetchJSON<T: Decodable>(
        prompt: String,
        responseType: T.Type,
        maxOutputTokens: Int? = nil,
        suppressRateLimitAlert: Bool = false
    ) async throws -> T {
        let raw = try await performRequest(
            prompt: prompt,
            forceJSON: true,
            maxOutputTokens: maxOutputTokens,
            suppressRateLimitAlert: suppressRateLimitAlert
        )
        let cleaned = cleanJSONResponse(raw)
        return try decode(cleaned, as: T.self, rawForLogging: cleaned)
    }

    /// Sends a text-only prompt expecting raw text (e.g. chat, title).
    func fetchText(prompt: String, suppressRateLimitAlert: Bool = false) async throws -> String {
        return try await performRequest(prompt: prompt, forceJSON: false, suppressRateLimitAlert: suppressRateLimitAlert)
    }

    /// Sends a multimodal prompt (text + single image) expecting JSON.
    func fetchJSONWithImage<T: Decodable>(
        prompt: String,
        base64Image: String,
        mimeType: String = "image/jpeg",
        responseType: T.Type
    ) async throws -> T {
        return try await fetchJSONWithImages(
            prompt: prompt,
            images: [(base64: base64Image, mime: mimeType)],
            responseType: responseType
        )
    }

    /// Sends a multimodal prompt (text + multiple images) expecting JSON.
    func fetchJSONWithImages<T: Decodable>(
        prompt: String,
        images: [(base64: String, mime: String)],
        responseType: T.Type
    ) async throws -> T {
        let raw = try await performRequest(prompt: prompt, images: images, forceJSON: true)
        let cleaned = cleanJSONResponse(raw)
        return try decode(cleaned, as: T.self, rawForLogging: cleaned)
    }

    // MARK: - Core Request

    private func performRequest(
        prompt: String,
        images: [(base64: String, mime: String)] = [],
        forceJSON: Bool,
        maxOutputTokens: Int? = nil,
        suppressRateLimitAlert: Bool = false
    ) async throws -> String {
        let configuredURL = await RemoteConfigManager.shared.getString(forKey: AIProxyEndpoint.remoteConfigKey)
        let url = AIProxyEndpoint.resolve(configured: configuredURL)

        var parts: [[String: Any]] = [["text": prompt]]

        for image in images {
            parts.append([
                "inlineData": [
                    "mimeType": image.mime,
                    "data": image.base64
                ]
            ])
        }

        var generationConfig: [String: Any] = [
            "temperature": images.isEmpty ? 0.7 : 0.4   // slightly more deterministic for vision
        ]
        if forceJSON {
            generationConfig["responseMimeType"] = "application/json"
        }
        if let maxOutputTokens, maxOutputTokens > 0 {
            generationConfig["maxOutputTokens"] = maxOutputTokens
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
        let encodedBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await executeAuthorizedRequest(
            url: url,
            body: encodedBody,
            allowRefreshRetry: refreshingTokenProvider != nil || tokenProvider == nil
        )

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if httpResponse.statusCode == 429 {
                let retryAfter = Self.extractRetryAfter(httpResponse: httpResponse, data: data)
                if !suppressRateLimitAlert {
                    let message = AIResponseParsing.rateLimitMessage(retryAfter: retryAfter)
                    await MainActor.run {
                        self.rateLimitAlertMessage = message
                    }
                }
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
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let candidates = json["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let finalText = parts.first?["text"] as? String {
                return finalText
            }
            if json["error"] != nil || json["candidates"] != nil {
                throw GeminiProxyError.invalidResponse
            }
        }

        // Direct JSON payload (e.g. unit test mocks) or raw completion text
        return text
    }

    // MARK: - Auth (moved from duplicated code in services)

    private func executeAuthorizedRequest(
        url: URL,
        body: Data,
        allowRefreshRetry: Bool
    ) async throws -> (Data, URLResponse) {
        let (authToken, appCheckToken) = try await getFirebaseTokens(forceRefresh: false)
        var request = makeAuthorizedRequest(url: url, body: body, authToken: authToken, appCheckToken: appCheckToken)
        let (data, response) = try await session.data(for: request)

        if allowRefreshRetry,
           let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401 {
            let (freshAuth, freshAppCheck) = try await getFirebaseTokens(forceRefresh: true)
            request = makeAuthorizedRequest(url: url, body: body, authToken: freshAuth, appCheckToken: freshAppCheck)
            return try await session.data(for: request)
        }
        return (data, response)
    }

    private func makeAuthorizedRequest(
        url: URL,
        body: Data,
        authToken: String,
        appCheckToken: String
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        request.setValue(DeviceInstallIdentifier.current, forHTTPHeaderField: "X-Device-Install-ID")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    private func getFirebaseTokens(forceRefresh: Bool = false) async throws -> (authToken: String, appCheckToken: String) {
        if let refreshingTokenProvider {
            return try await refreshingTokenProvider(forceRefresh)
        }
        if let tokenProvider {
            return try await tokenProvider()
        }
        let user: FirebaseAuth.User
        if let current = Auth.auth().currentUser {
            user = current
        } else {
            user = try await AnonymousAuthBootstrap.shared.ensureSignedIn()
        }
        let authToken: String
        do {
            authToken = try await user.getIDToken(forcingRefresh: forceRefresh)
        } catch {
            if forceRefresh && AuthManager.isPermanentTokenInvalidationError(error) {
                let wasAnonymous = user.isAnonymous
                try? Auth.auth().signOut()
                if wasAnonymous {
                    let freshUser = try await AnonymousAuthBootstrap.shared.ensureSignedIn()
                    authToken = try await freshUser.getIDToken(forcingRefresh: false)
                } else {
                    throw error
                }
            } else {
                throw error
            }
        }
        let appCheckToken = try await AppCheck.appCheck().token(forcingRefresh: forceRefresh).token
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
