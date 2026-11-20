import XCTest
@testable import FoodTracker

final class MicronutrientPipelineTests: XCTestCase {

    func testLocalFoodEntryPopulatesAndScalesMicronutrientsForNutrientDenseFoods() {
        let salmon100 = LocalFoodEntry(
            id: "salmon_raw",
            name: "Salmon (raw)",
            calories: 208,
            protein: 20.0,
            fat: 13.0,
            carbs: 0.0,
            category: "fish"
        ).toFoodItem(weight: 100)

        let salmon200 = LocalFoodEntry(
            id: "salmon_raw",
            name: "Salmon (raw)",
            calories: 208,
            protein: 20.0,
            fat: 13.0,
            carbs: 0.0,
            category: "fish"
        ).toFoodItem(weight: 200)

        XCTAssertGreaterThan(salmon100.omega3, 0.5)
        XCTAssertGreaterThan(salmon100.vitaminD, 2.0)
        XCTAssertGreaterThan(salmon100.potassium, 100.0)
        XCTAssertEqual(salmon200.omega3, salmon100.omega3 * 2.0, accuracy: 0.01)
        XCTAssertEqual(salmon200.vitaminD, salmon100.vitaminD * 2.0, accuracy: 0.01)

        let water = LocalFoodEntry(
            id: "plain_water",
            name: "Water",
            calories: 0,
            protein: 0,
            fat: 0,
            carbs: 0,
            category: "beverages"
        ).toFoodItem(weight: 250)

        XCTAssertEqual(water.omega3, 0.0)
        XCTAssertEqual(water.iron, 0.0)
        XCTAssertEqual(water.vitaminC, 0.0)
    }

    func testOpenFoodFactsExtractsMicronutrientsAcrossUnits() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let manager = NetworkManager.shared
        let originalSession = manager.session
        manager.clearCacheForTesting()
        manager.session = URLSession(configuration: config)
        defer {
            MockURLProtocol.requestHandler = nil
            manager.clearCacheForTesting()
            manager.session = originalSession
        }

        MockURLProtocol.requestHandler = { request in
            let json = #"""
            {
              "status": 1,
              "product": {
                "product_name": "Fortified Oat Drink",
                "nutriments": {
                  "energy-kcal_100g": 46,
                  "proteins_100g": 1.0,
                  "fat_100g": 1.5,
                  "carbohydrates_100g": 7.0,
                  "calcium_100g": 0.12,
                  "calcium_unit": "mg",
                  "iron_100g": 0.004,
                  "iron_unit": "g",
                  "potassium_100g": 0.15,
                  "potassium_unit": "mg",
                  "magnesium_100g": 0.025,
                  "magnesium_unit": "mg",
                  "vitamin-c_100g": 0.018,
                  "vitamin-c_unit": "mg",
                  "vitamin-d_100g": 0.0000015,
                  "vitamin-d_unit": "µg",
                  "omega-3-fat_100g": 0.3
                }
              }
            }
            """#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let outcome = await manager.fetchProductOutcome(barcode: "33330001")
        guard case .found(let item) = outcome else {
            XCTFail("Expected .found")
            return
        }
        XCTAssertEqual(item.calcium, 120.0, accuracy: 0.01)
        XCTAssertEqual(item.iron, 4.0, accuracy: 0.01)
        XCTAssertEqual(item.potassium, 150.0, accuracy: 0.01)
        XCTAssertEqual(item.magnesium, 25.0, accuracy: 0.01)
        XCTAssertEqual(item.vitaminC, 18.0, accuracy: 0.01)
        XCTAssertEqual(item.vitaminD, 1.5, accuracy: 0.01)
        XCTAssertEqual(item.omega3, 0.3, accuracy: 0.01)
    }

    func testAIDTOsDecodeOptionalMicronutrientsAndClampNegatives() throws {
        let aiFoodJSON = #"""
        {
            "isFood": true,
            "name": "Grilled Salmon Bowl",
            "weight": 250,
            "calories": 520,
            "protein": 38,
            "fats": 22,
            "carbs": 42,
            "omega3": 2.4,
            "calcium": 65,
            "potassium": 680,
            "magnesium": 85,
            "iron": -3.0,
            "vitaminC": 14,
            "vitaminD": 11.5
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(VertexAIManager.AIFoodResponse.self, from: aiFoodJSON)
        XCTAssertEqual(decoded.omega3 ?? 0, 2.4, accuracy: 0.01)
        XCTAssertEqual(decoded.calcium ?? 0, 65.0, accuracy: 0.01)
        XCTAssertEqual(decoded.potassium ?? 0, 680.0, accuracy: 0.01)
        XCTAssertEqual(decoded.magnesium ?? 0, 85.0, accuracy: 0.01)
        XCTAssertEqual(decoded.iron ?? -1, 0.0, accuracy: 0.01)
        XCTAssertEqual(decoded.vitaminC ?? 0, 14.0, accuracy: 0.01)
        XCTAssertEqual(decoded.vitaminD ?? 0, 11.5, accuracy: 0.01)
    }

    func testMicronutrientEstimatorDoesNotMatchSubstringsEiOrNutInsideUnrelatedWords() {
        let proteinShake = MicronutrientEstimator.estimate(
            id: "protein_shake",
            name: "Protein Shake",
            category: "supplements",
            calories: 140,
            protein: 25,
            fat: 2,
            carbs: 4,
            weight: 100
        )
        XCTAssertNotEqual(proteinShake.calcium, 56.0, "Protein must not match German 'ei' egg profile")
        XCTAssertEqual(proteinShake.calcium, 80.0, accuracy: 0.01)

        let fleisch = MicronutrientEstimator.estimate(
            id: "rindfleisch",
            name: "Rindfleisch",
            category: "meat",
            calories: 210,
            protein: 26,
            fat: 12,
            carbs: 0,
            weight: 100
        )
        XCTAssertEqual(fleisch.vitaminD, 0.2, accuracy: 0.01, "Fleisch must use meat profile, not egg ('ei') vitamin D 2.0")

        let reis = MicronutrientEstimator.estimate(
            id: "weisser_reis",
            name: "Reis",
            category: "grains",
            calories: 130,
            protein: 2.7,
            fat: 0.3,
            carbs: 28,
            weight: 100
        )
        XCTAssertEqual(reis.vitaminD, 0.0, accuracy: 0.01, "Reis must use grains profile, not egg ('ei')")

        let eggDE = MicronutrientEstimator.estimate(
            id: "huehner_ei",
            name: "Bio Ei",
            category: "",
            calories: 155,
            protein: 13,
            fat: 11,
            carbs: 1.1,
            weight: 100
        )
        XCTAssertEqual(eggDE.vitaminD, 2.0, accuracy: 0.01)

        let donut = MicronutrientEstimator.estimate(
            id: "glazed_donut",
            name: "Glazed Donut",
            category: "sweets",
            calories: 320,
            protein: 4,
            fat: 15,
            carbs: 42,
            weight: 100
        )
        XCTAssertEqual(donut.magnesium, 28.0, accuracy: 0.01, "Donut must not match 'nut' nuts profile (210mg Mg)")

        let mixedNuts = MicronutrientEstimator.estimate(
            id: "mixed_nuts",
            name: "Mixed Nuts",
            category: "",
            calories: 600,
            protein: 20,
            fat: 52,
            carbs: 16,
            weight: 100
        )
        XCTAssertEqual(mixedNuts.magnesium, 210.0, accuracy: 0.01)
    }

    func testOpenFoodFactsIgnoresPercentDVUnitsScalesOmega3MgAndPreservesKnownZeroMicros() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let manager = NetworkManager.shared
        let originalSession = manager.session
        manager.clearCacheForTesting()
        manager.session = URLSession(configuration: config)
        defer {
            MockURLProtocol.requestHandler = nil
            manager.clearCacheForTesting()
            manager.session = originalSession
        }

        MockURLProtocol.requestHandler = { request in
            let json = #"""
            {
              "status": 1,
              "product": {
                "product_name": "US Cereal",
                "nutriments": {
                  "energy-kcal_100g": 370,
                  "proteins_100g": 8.0,
                  "fat_100g": 2.0,
                  "carbohydrates_100g": 80.0,
                  "calcium_100g": 42,
                  "calcium_unit": "%",
                  "iron_100g": 20,
                  "iron_unit": "% dv",
                  "vitamin-d_100g": 10,
                  "vitamin-d_unit": "%",
                  "potassium_100g": 0.28,
                  "potassium_unit": "mg",
                  "vitamin-c_100g": 0,
                  "vitamin-c_unit": "mg",
                  "omega-3-fat_100g": 0.5,
                  "omega-3-fat_unit": "mg"
                }
              }
            }
            """#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json)
        }

        let outcome = await manager.fetchProductOutcome(barcode: "44440001")
        guard case .found(let item) = outcome else {
            XCTFail("Expected .found")
            return
        }
        XCTAssertEqual(item.omega3, 0.5, accuracy: 0.01)
        XCTAssertEqual(item.potassium, 280.0, accuracy: 0.01)
        XCTAssertNotEqual(item.calcium, 42.0, accuracy: 0.01)
        XCTAssertNotEqual(item.iron, 20.0, accuracy: 0.01)
        XCTAssertNotEqual(item.vitaminD, 10.0, accuracy: 0.01)
        XCTAssertEqual(item.vitaminC, 0.0, accuracy: 0.01)
    }

    func testBarcodeReturnsNotFoundWhenOFFReturnsNotFoundAndFatSecretFails() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let manager = NetworkManager.shared
        let originalSession = manager.session
        let originalProxyURL = manager.searchProxyURLProvider
        let originalAuth = manager.authTokenProvider
        let originalAppCheck = manager.appCheckTokenProvider
        let originalRefreshing = manager.refreshingProxyTokensProvider
        manager.clearCacheForTesting()
        manager.session = URLSession(configuration: config)
        manager.searchProxyURLProvider = { URL(string: "https://mock.local/foodSearchProxy")! }
        manager.authTokenProvider = { "mock-auth" }
        manager.appCheckTokenProvider = { "mock-appcheck" }
        manager.refreshingProxyTokensProvider = { _ in (authToken: "mock-auth", appCheckToken: "mock-appcheck") }
        defer {
            MockURLProtocol.requestHandler = nil
            manager.clearCacheForTesting()
            manager.session = originalSession
            manager.searchProxyURLProvider = originalProxyURL
            manager.authTokenProvider = originalAuth
            manager.appCheckTokenProvider = originalAppCheck
            manager.refreshingProxyTokensProvider = originalRefreshing
        }

        MockURLProtocol.requestHandler = { request in
            if request.url?.host == "world.openfoodfacts.org" {
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let outcome = await manager.fetchProductOutcome(barcode: "44449999")
        guard case .notFound = outcome else {
            XCTFail("Expected .notFound when OFF succeeded with 404 and FatSecret failed, got \(outcome)")
            return
        }
    }
}
