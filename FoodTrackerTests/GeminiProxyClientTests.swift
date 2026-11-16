import XCTest
@testable import FoodTracker

final class GeminiProxyClientTests: XCTestCase {

    func testEndpointResolveAcceptsHTTPSOverride() {
        let overrideURL = "https://custom-proxy.example.com/foodAiProxy"
        let resolved = AIProxyEndpoint.resolve(configured: "  \(overrideURL)  ")
        XCTAssertEqual(resolved.absoluteString, overrideURL)
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
}
