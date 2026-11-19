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
                  "calcium_100g": 120,
                  "calcium_unit": "mg",
                  "iron_100g": 0.004,
                  "iron_unit": "g",
                  "potassium_100g": 150,
                  "potassium_unit": "mg",
                  "magnesium_100g": 25,
                  "magnesium_unit": "mg",
                  "vitamin-c_100g": 18,
                  "vitamin-c_unit": "mg",
                  "vitamin-d_100g": 1.5,
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
}
