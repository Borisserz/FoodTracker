import Foundation
import FirebaseAuth
import FirebaseAppCheck

/// Centralized client for the Gemini/Vertex proxy.
/// Eliminates duplication between AINutritionService and VertexAIManager.
/// Handles auth (Firebase ID + AppCheck), request construction, and response cleaning.
final class GeminiProxyClient {
    static let shared = GeminiProxyClient()
    private init() {}

    private let proxyUrl = "https://us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net/vertexProxy"

    // MARK: - Public API (used by services)

    /// Sends a text-only prompt expecting a JSON response. Returns decoded type.
    func fetchJSON<T: Decodable>(prompt: String, responseType: T.Type, schema: [String: Any]? = nil, temperature: Double? = nil) async throws -> T {
        let raw = try await performRequest(prompt: prompt, includeImage: nil, forceJSON: true, responseSchema: schema, temperature: temperature)
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
        responseType: T.Type,
        schema: [String: Any]? = nil,
        temperature: Double? = nil
    ) async throws -> T {
        let raw = try await performRequest(prompt: prompt, includeImage: (base64Image, mimeType), forceJSON: true, responseSchema: schema, temperature: temperature)
        let cleaned = cleanJSONResponse(raw)
        return try decode(cleaned, as: T.self, rawForLogging: cleaned)
    }

    // MARK: - Core Request

    private func performRequest(prompt: String, includeImage: (base64: String, mime: String)?, forceJSON: Bool, responseSchema: [String: Any]? = nil, temperature: Double? = nil) async throws -> String {
        let (authToken, appCheckToken) = try await getFirebaseTokens()

        guard let url = URL(string: proxyUrl) else {
            throw GeminiProxyError.invalidURL
        }

        var localizedPrompt = prompt
        if let preferredLang = Locale.preferredLanguages.first {
            let langName = Locale.current.localizedString(forIdentifier: preferredLang) ?? preferredLang
            localizedPrompt += "\n\nIMPORTANT: You MUST respond in \(langName) (\(preferredLang)) unless instructed otherwise. Maintain JSON keys in English if a JSON schema is requested."
        }

        var parts: [[String: Any]] = [["text": localizedPrompt]]

        if let image = includeImage {
            parts.append([
                "inlineData": [
                    "mimeType": image.mime,
                    "data": image.base64
                ]
            ])
        }

        var generationConfig: [String: Any] = [
            "temperature": temperature ?? (includeImage == nil ? 0.7 : 0.4)   // slightly more deterministic for vision
        ]
        if forceJSON {
            generationConfig["responseMimeType"] = "application/json"
        }
        if let schema = responseSchema {
            generationConfig["responseSchema"] = schema
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

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if httpResponse.statusCode == 429 {
                // Try to extract Retry-After
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
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
        guard let user = Auth.auth().currentUser else {
            throw URLError(.userAuthenticationRequired)
        }
        let authToken = try await user.getIDToken()
        let appCheckToken = try await AppCheck.appCheck().token(forcingRefresh: false).token
        return (authToken, appCheckToken)
    }

    // MARK: - JSON Cleaning (centralized, previously duplicated & slightly inconsistent)

    private func cleanJSONResponse(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove common Gemini code fences (multiple variants)
        let prefixes = ["```json", "```JSON", "```"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }

        let suffixes = ["```"]
        for suffix in suffixes {
            if cleaned.hasSuffix(suffix) {
                cleaned = String(cleaned.dropLast(suffix.count))
                break
            }
        }

        // Remove leading/trailing whitespace and any stray backticks
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "`"))

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
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