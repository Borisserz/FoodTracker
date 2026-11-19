import XCTest
@testable import FoodTracker

final class GeminiProxyClientTests: XCTestCase {

    func testEndpointResolveAcceptsTrustedHostAndRejectsUntrustedHTTPSOverride() {
        let trustedOverride = "https://us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net/foodAiProxyStaging"
        XCTAssertEqual(
            AIProxyEndpoint.resolve(configured: "  \(trustedOverride)  ").absoluteString,
            trustedOverride
        )

        let untrustedOverride = "https://custom-proxy.example.com/foodAiProxy"
        XCTAssertEqual(
            AIProxyEndpoint.resolve(configured: untrustedOverride),
            AIProxyEndpoint.fallbackURL
        )

        let userinfoAttack = "https://us-central1-serzhanovich-ecosystem-ce700.cloudfunctions.net@evil.example.com/foodAiProxy"
        XCTAssertEqual(
            AIProxyEndpoint.resolve(configured: userinfoAttack),
            AIProxyEndpoint.fallbackURL
        )
    }

    func testEndpointResolveRejectsHTTPAndEmptyStrings() {
        XCTAssertEqual(AIProxyEndpoint.resolve(configured: nil), AIProxyEndpoint.fallbackURL)
        XCTAssertEqual(AIProxyEndpoint.resolve(configured: ""), AIProxyEndpoint.fallbackURL)
        XCTAssertEqual(AIProxyEndpoint.resolve(configured: "http://insecure.example.com"), AIProxyEndpoint.fallbackURL)
        XCTAssertEqual(AIProxyEndpoint.resolve(configured: "not a url"), AIProxyEndpoint.fallbackURL)
        XCTAssertEqual(
            AIProxyEndpoint.resolve(configured: "http://bad.example.com", fallback: AIProxyEndpoint.searchFallbackURL),
            AIProxyEndpoint.searchFallbackURL
        )
        XCTAssertEqual(
            AIProxyEndpoint.resolve(configured: nil, fallback: AIProxyEndpoint.deleteAccountFallbackURL),
            AIProxyEndpoint.deleteAccountFallbackURL
        )
    }

    func testExtractJSONStripsFencesAndSurroundingProse() {
        let raw = """
        Sure! Here is the nutrition breakdown:
        ```json
        {"name": "Avocado Toast {Special}", "calories": 220}
        ```
        Hope that helps!
        """
        let extracted = AIResponseParsing.extractJSON(from: raw)
        XCTAssertEqual(extracted, "{\"name\": \"Avocado Toast {Special}\", \"calories\": 220}")
    }

    func testExtractJSONSupportsTopLevelArray() {
        let raw = "Items: [{\"a\":1},{\"b\":2}] end"
        let extracted = AIResponseParsing.extractJSON(from: raw)
        XCTAssertEqual(extracted, "[{\"a\":1},{\"b\":2}]")
    }

    func testExtractJSONSkipsProseCitationBracketsAndExtractsFencedOrObjectPayload() {
        let withCitationAndFenced = """
        Option [1] summary:
        ```json
        {"calories": 420, "name": "Salmon Bowl"}
        ```
        """
        XCTAssertEqual(
            AIResponseParsing.extractJSON(from: withCitationAndFenced),
            "{\"calories\": 420, \"name\": \"Salmon Bowl\"}"
        )

        let withCitationAndRawObject = "Reference [2] -> {\"title\":\"Ok\"}"
        XCTAssertEqual(
            AIResponseParsing.extractJSON(from: withCitationAndRawObject),
            "{\"title\":\"Ok\"}"
        )
    }

    func testExtractRetryAfterPrefersHeaderOrBody() {
        let url = URL(string: "https://example.com")!
        let headerResp = HTTPURLResponse(
            url: url,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "120"]
        )!
        XCTAssertEqual(GeminiProxyClient.extractRetryAfter(httpResponse: headerResp, data: Data()), "120")

        let noHeaderResp = HTTPURLResponse(url: url, statusCode: 429, httpVersion: nil, headerFields: nil)!
        let body = #"{"error":"weekly_limit_reached","retryAfter":3600}"#.data(using: .utf8)!
        XCTAssertEqual(GeminiProxyClient.extractRetryAfter(httpResponse: noHeaderResp, data: body), "3600")
    }

    func testRateLimitMessageFormatting() {
        XCTAssertTrue(AIResponseParsing.rateLimitMessage(retryAfter: "172800").contains("2d"))
        XCTAssertTrue(AIResponseParsing.rateLimitMessage(retryAfter: "7200").contains("2h"))
        XCTAssertTrue(AIResponseParsing.rateLimitMessage(retryAfter: "90").contains("2m"))
        XCTAssertTrue(AIResponseParsing.rateLimitMessage(retryAfter: nil).contains("later"))
    }

    func testFlexibleIntDecodesIntDoubleAndNumericString() throws {
        struct SampleDTO: Decodable {
            @FlexibleInt var calories: Int
            @FlexibleInt var protein: Int
            @FlexibleInt var carbs: Int
        }

        let json = #"{"calories": 420.6, "protein": "35.2", "carbs": 50}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SampleDTO.self, from: json)
        XCTAssertEqual(decoded.calories, 421)
        XCTAssertEqual(decoded.protein, 35)
        XCTAssertEqual(decoded.carbs, 50)
    }

    func testPerformRequestRetriesOnceWithForcedTokenRefreshOn401() async throws {
        let client = GeminiProxyClient.shared
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let originalSession = client.session
        client.session = URLSession(configuration: config)
        defer {
            MockURLProtocol.requestHandler = nil
            client.session = originalSession
            client.refreshingTokenProvider = nil
        }

        var refreshFlags: [Bool] = []
        client.refreshingTokenProvider = { forceRefresh in
            refreshFlags.append(forceRefresh)
            return (authToken: forceRefresh ? "fresh-token" : "stale-token", appCheckToken: "appcheck")
        }

        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            if callCount == 1 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer stale-token")
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            } else {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-token")
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data("Hello after refresh".utf8))
            }
        }

        let reply = try await client.fetchText(prompt: "Hi")
        XCTAssertEqual(reply, "Hello after refresh")
        XCTAssertEqual(refreshFlags, [false, true])
        XCTAssertEqual(callCount, 2)
    }

    func testFetchJSONIncludesMaxOutputTokensWhenProvided() async throws {
        struct TinyDTO: Decodable { let ok: Bool }
        let client = GeminiProxyClient.shared
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let originalSession = client.session
        client.session = URLSession(configuration: config)
        defer {
            MockURLProtocol.requestHandler = nil
            client.session = originalSession
            client.refreshingTokenProvider = nil
        }

        client.refreshingTokenProvider = { _ in (authToken: "t", appCheckToken: "a") }
        var capturedMaxTokens: Int?

        MockURLProtocol.requestHandler = { request in
            var bodyData = request.httpBody ?? Data()
            if bodyData.isEmpty, let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count > 0 {
                        bodyData.append(contentsOf: buffer.prefix(count))
                    } else {
                        break
                    }
                }
            }
            if let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
               let genConfig = json["generationConfig"] as? [String: Any] {
                capturedMaxTokens = genConfig["maxOutputTokens"] as? Int
            }
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{"ok":true}"#.utf8))
        }

        let dto = try await client.fetchJSON(prompt: "Plan", responseType: TinyDTO.self, maxOutputTokens: 8192)
        XCTAssertTrue(dto.ok)
        XCTAssertEqual(capturedMaxTokens, 8192)
    }

    @MainActor
    func testConsumeRateLimitAlertMessageReturnsAndClearsStoredMessage() {
        let client = GeminiProxyClient.shared
        client.rateLimitAlertMessage = "Limit reached, try again in 2h."
        XCTAssertTrue(GeminiProxyClient.shouldSuppressSecondaryErrorAlert)

        let consumed = GeminiProxyClient.consumeRateLimitAlertMessage()
        XCTAssertEqual(consumed, "Limit reached, try again in 2h.")
        XCTAssertNil(client.rateLimitAlertMessage)
        XCTAssertFalse(GeminiProxyClient.shouldSuppressSecondaryErrorAlert)
        XCTAssertNil(GeminiProxyClient.consumeRateLimitAlertMessage())
    }
}
