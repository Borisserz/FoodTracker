import XCTest
@testable import FoodTracker

final class NetworkManagerTests: XCTestCase {
    var networkManager: NetworkManager!
    var originalSession: URLSession!
    
    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        networkManager = NetworkManager.shared
        originalSession = networkManager.session
        networkManager.clearCacheForTesting()
        networkManager.session = session
        networkManager.appCheckTokenProvider = { "mock-appcheck-token" }
        networkManager.authTokenProvider = { "mock-auth-token" }
        networkManager.searchProxyURLProvider = { URL(string: "https://mock.local/foodSearchProxy")! }
    }
    
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        networkManager.clearCacheForTesting()
        if let originalSession {
            networkManager.session = originalSession
        }
        networkManager.searchProxyURLProvider = nil
        networkManager.refreshingProxyTokensProvider = nil
        super.tearDown()
    }

    func testSearchFoodOpenFoodFactsFallback() async {
        // Mock Open Food Facts to return 1 item, then foodSearchProxy returns 1 extra item
        let offJSON = """
        {
            "products": [
                {
                    "product_name": "Test Apple",
                    "nutriments": {
                        "energy-kcal_100g": 52,
                        "proteins_100g": 0.3,
                        "fat_100g": 0.2,
                        "carbohydrates_100g": 11.4
                    }
                }
            ]
        }
        """
        let proxyJSON = """
        {
            "items": [
                { "name": "Fuji Apple", "weight": 100.0, "calories": 60, "protein": 0.4, "fats": 0.2, "carbs": 14.0 }
            ]
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            if request.url?.host == "mock.local" {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer mock-auth-token")
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"), "mock-appcheck-token")
            }
            let payload = request.url?.host == "mock.local" ? proxyJSON : offJSON
            let data = payload.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
        
        let results = await networkManager.searchFoodByText(query: "Apple")
        
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.name, "Test Apple")
        XCTAssertEqual(results.last?.name, "Fuji Apple")
    }

    func testSearchEncodesReservedQueryCharactersAndRejectsNon200BarcodeOFF() async {
        var capturedURL: URL?
        MockURLProtocol.requestHandler = { request in
            if request.url?.host == "world.openfoodfacts.org", request.url?.path == "/cgi/search.pl" {
                capturedURL = request.url
            }
            let status = (request.url?.path.contains("/api/v0/product/") == true) ? 503 : 200
            let data = #"{"status":1,"product":{"product_name":"Should Be Ignored","nutriments":{"energy-kcal_100g":100}}}"#.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        _ = await networkManager.searchFoodByText(query: "mac & cheese + 2")
        XCTAssertNotNil(capturedURL)
        let components = URLComponents(url: capturedURL!, resolvingAgainstBaseURL: false)
        let searchTerms = components?.queryItems?.first(where: { $0.name == "search_terms" })?.value
        XCTAssertEqual(searchTerms, "mac & cheese + 2")

        let barcodeItem = await networkManager.fetchProduct(barcode: "123456")
        XCTAssertNil(barcodeItem)
    }

    func testBarcodeFallsThroughZeroOFFToFatSecretAndRetries401WithForcedRefresh() async {
        var refreshFlags: [Bool] = []
        networkManager.refreshingProxyTokensProvider = { forceRefresh in
            refreshFlags.append(forceRefresh)
            return (authToken: forceRefresh ? "fresh-auth" : "stale-auth", appCheckToken: "appcheck")
        }

        var proxyAttempts = 0
        MockURLProtocol.requestHandler = { request in
            if request.url?.host == "world.openfoodfacts.org" {
                let emptyOFF = #"{"status":1,"product":{"product_name":"Zero OFF Product","nutriments":{}}}"#.data(using: .utf8)!
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, emptyOFF)
            }
            proxyAttempts += 1
            if proxyAttempts == 1 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer stale-auth")
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh-auth")
            let proxyHit = #"{"item":{"name":"FatSecret Granola Bar","weight":40,"calories":180,"protein":4,"fats":7,"carbs":26}}"#.data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, proxyHit)
        }

        let item = await networkManager.fetchProduct(barcode: "004900000044")
        XCTAssertEqual(item?.name, "FatSecret Granola Bar")
        XCTAssertEqual(item?.calories, 180)
        XCTAssertEqual(refreshFlags, [false, true])
        XCTAssertNil(networkManager.lastBarcodeLookupError)
    }

    func testBarcodeUsesServingNutrimentsWhen100gMissing() async {
        MockURLProtocol.requestHandler = { request in
            let servingOFF = #"""
            {
              "status": 1,
              "product": {
                "product_name": "US Protein Bar",
                "serving_quantity": "60",
                "nutriments": {
                  "energy-kcal_serving": 210,
                  "proteins_serving": 20,
                  "fat_serving": 7,
                  "carbohydrates_serving": 22
                }
              }
            }
            """#.data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, servingOFF)
        }

        let item = await networkManager.fetchProduct(barcode: "88888888")
        XCTAssertEqual(item?.name, "US Protein Bar")
        XCTAssertEqual(item?.weight ?? 0, 60.0, accuracy: 0.01)
        XCTAssertEqual(item?.calories, 210)
        XCTAssertEqual(item?.protein ?? 0, 20.0, accuracy: 0.01)
    }

    func testBarcodeParsesUnitSuffixedServingQuantity() async {
        MockURLProtocol.requestHandler = { request in
            let servingOFF = #"""
            {
              "status": 1,
              "product": {
                "product_name": "Trail Mix",
                "serving_quantity": "30 g",
                "nutriments": {
                  "energy-kcal_serving": 160,
                  "proteins_serving": 5,
                  "fat_serving": 10,
                  "carbohydrates_serving": 12
                }
              }
            }
            """#.data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, servingOFF)
        }

        let item = await networkManager.fetchProduct(barcode: "77777777")
        XCTAssertEqual(item?.name, "Trail Mix")
        XCTAssertEqual(item?.weight ?? 0, 30.0, accuracy: 0.01)
    }

    func testBarcodeAndSearchCacheAvoidDuplicateNetworkRequestsAndReturnFreshFoodItems() async {
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            let offBarcode = #"{"status":1,"product":{"product_name":"Cached Oats","nutriments":{"energy-kcal_100g":380,"proteins_100g":13,"fat_100g":7,"carbohydrates_100g":65}}}"#.data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, offBarcode)
        }

        let first = await networkManager.fetchProduct(barcode: "99999999")
        let second = await networkManager.fetchProduct(barcode: "99999999")
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(first?.name, "Cached Oats")
        XCTAssertEqual(second?.name, "Cached Oats")
        XCTAssertFalse(first === second, "Cached lookup must return a distinct FoodItem instance for SwiftData")
    }

    func testBarcodeParsesUSParentheticalServingAndRejectsNaNNutriments() async {
        MockURLProtocol.requestHandler = { request in
            let offBarcode = #"""
            {
              "status": 1,
              "product": {
                "product_name": "Almond Pack",
                "serving_size": "1 oz (28 g)",
                "nutriments": {
                  "energy-kcal_serving": 170,
                  "proteins_serving": "NaN",
                  "fat_serving": "15",
                  "carbohydrates_serving": "1,250"
                }
              }
            }
            """#.data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, offBarcode)
        }

        let item = await networkManager.fetchProduct(barcode: "55556666")
        XCTAssertEqual(item?.weight ?? 0, 28.0, accuracy: 0.01)
        XCTAssertEqual(item?.protein ?? -1, 0.0, accuracy: 0.01)
        XCTAssertEqual(item?.carbs ?? 0, 1250.0, accuracy: 0.01)
    }

    func testSearchProxySendsDeviceInstallIdRetriesMissingInitialTokenAndSeparatesAIFallbackCache() async {
        var sentDeviceHeaders: [String] = []
        var forceFlags: [Bool] = []
        networkManager.refreshingProxyTokensProvider = { forceRefresh in
            forceFlags.append(forceRefresh)
            if !forceRefresh {
                return (authToken: nil, appCheckToken: "app-check")
            }
            return (authToken: "fresh-id-token", appCheckToken: "app-check")
        }

        MockURLProtocol.requestHandler = { request in
            let host = request.url?.host ?? ""
            if host == "mock.local" {
                if let devId = request.value(forHTTPHeaderField: "X-Device-Install-ID") {
                    sentDeviceHeaders.append(devId)
                }
                let body = #"{"items":[{"name":"Proxy Yogurt","weight":150,"calories":90,"protein":15,"fats":0,"carbs":7}]}"#.data(using: .utf8)!
                let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, body)
            }
            let offEmpty = #"{"products":[]}"#.data(using: .utf8)!
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, offEmpty)
        }

        let noAI = await networkManager.searchFoodByText(query: "yogurt", allowAIFallback: false)
        XCTAssertEqual(noAI.first?.name, "Proxy Yogurt")
        XCTAssertEqual(forceFlags, [false, true])
        XCTAssertEqual(sentDeviceHeaders.count, 1)
        XCTAssertEqual(sentDeviceHeaders.first?.isEmpty, false)

        // Separate cache bucket for allowAIFallback: true vs false should still isolate entries cleanly.
        let bucketA = NetworkManager.searchCacheKey(query: "Oats", language: "en", allowAIFallback: true)
        let bucketB = NetworkManager.searchCacheKey(query: "Oats", language: "en", allowAIFallback: false)
        XCTAssertNotEqual(bucketA, bucketB)
    }

    func testOpenFoodFactsSearchHandlesEmptyProductNameAndServingOnlyNutriments() async {
        MockURLProtocol.requestHandler = { request in
            let host = request.url?.host ?? ""
            if host == "mock.local" {
                let empty = #"{"items":[]}"#.data(using: .utf8)!
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, empty)
            }
            let offSearch = #"""
            {
              "products": [
                {
                  "product_name": "",
                  "product_name_en": "US Quest Bar",
                  "serving_size": "60 g",
                  "nutriments": {
                    "energy-kcal_serving": 200,
                    "proteins_serving": 21,
                    "fat_serving": 8,
                    "carbohydrates_serving": 22
                  }
                }
              ]
            }
            """#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, offSearch)
        }

        let results = await networkManager.searchFoodByText(query: "quest", allowAIFallback: false)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "US Quest Bar")
        XCTAssertEqual(results.first?.weight ?? 0, 60.0, accuracy: 0.01)
        XCTAssertEqual(results.first?.calories, 200)
        XCTAssertEqual(results.first?.protein ?? 0, 21.0, accuracy: 0.01)
    }

    func testSearchFoodTrimsQueryAndFetchProductOutcomeSurfacesFailureDirectly() async {
        var capturedSearchTerms: String?
        MockURLProtocol.requestHandler = { request in
            let url = request.url!
            if url.host == "world.openfoodfacts.org" {
                let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
                capturedSearchTerms = comps?.queryItems?.first(where: { $0.name == "search_terms" })?.value
                let empty = #"{"products":[]}"#.data(using: .utf8)!
                return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, empty)
            }
            let emptyProxy = #"{"items":[]}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!, emptyProxy)
        }

        _ = await networkManager.searchFoodByText(query: "   avocado   ", allowAIFallback: false)
        XCTAssertEqual(capturedSearchTerms, "avocado")

        MockURLProtocol.requestHandler = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let outcome = await networkManager.fetchProductOutcome(barcode: "12345678")
        if case .failed(let message) = outcome {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected .failed outcome on HTTP 503")
        }
    }
}
