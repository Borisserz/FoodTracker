import XCTest
@testable import FoodTracker

final class NetworkManagerTests: XCTestCase {
    var networkManager: NetworkManager!
    
    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        networkManager = NetworkManager.shared
        networkManager.session = session
        networkManager.appCheckTokenProvider = { "mock-appcheck-token" }
        networkManager.authTokenProvider = { "mock-auth-token" }
        networkManager.searchProxyURLProvider = { URL(string: "https://mock.local/foodSearchProxy")! }
    }
    
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        networkManager.session = .shared
        networkManager.searchProxyURLProvider = nil
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
}
