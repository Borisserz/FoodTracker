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
    }
    
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        networkManager.session = .shared
        super.tearDown()
    }

    func testSearchFoodOpenFoodFactsFallback() async {
        // Mock Open Food Facts to return a successful item
        let jsonString = """
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
        
        MockURLProtocol.requestHandler = { request in
            let data = jsonString.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
        
        let results = await networkManager.searchFoodByText(query: "Apple")
        
        // Since OFF returned 1 item, it will fallback to FatSecret, which will crash if not mocked, 
        // wait, we mock all requests. If we mock ALL requests with the same handler, 
        // the FatSecret token request will fail to parse `access_token`, so it will return empty from FS.
        // That's fine, we should still get the OFF item.
        
        XCTAssertTrue(results.count >= 1)
        XCTAssertEqual(results.first?.name, "Test Apple")
        XCTAssertEqual(results.first?.calories, 52)
    }
}
