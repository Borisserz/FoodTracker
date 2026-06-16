import XCTest
@testable import FoodTracker

final class DietModelTests: XCTestCase {

    func testDietPlanDefaultDietsCount() {
        XCTAssertEqual(DietPlan.defaultDiets.count, 9, "There should be 9 default diets defined")
    }

    func testDietPlanMacroBreakdowns() {
        let keto = DietPlan.defaultDiets.first { $0.key == "keto" }
        XCTAssertNotNil(keto)
        XCTAssertEqual(keto?.macroBreakdown.fat, 70)
        XCTAssertEqual(keto?.macroBreakdown.protein, 25)
        XCTAssertEqual(keto?.macroBreakdown.carbs, 5)

        let vegan = DietPlan.defaultDiets.first { $0.key == "vegan" }
        XCTAssertNotNil(vegan)
        XCTAssertEqual(vegan?.macroBreakdown.carbs, 65)
    }

    func testFoodDietCompatibility() {
        // High fat, low carb
        let ketoFood = FoodItem(name: "Butter", weight: 100, calories: 717, protein: 0.8, fats: 81, carbs: 0.1)
        let ketoDiet = DietPlan.defaultDiets.first { $0.key == "keto" }
        XCTAssertEqual(ketoFood.compatibility(with: ketoDiet), .perfect)

        // High carb, not for keto
        let pasta = FoodItem(name: "Pasta", weight: 100, calories: 131, protein: 5, fats: 1, carbs: 25)
        XCTAssertEqual(pasta.compatibility(with: ketoDiet), .avoid)

        // High protein
        let chicken = FoodItem(name: "Chicken Breast", weight: 100, calories: 165, protein: 31, fats: 3.6, carbs: 0)
        let highProteinDiet = DietPlan.defaultDiets.first { $0.key == "high_protein" }
        XCTAssertEqual(chicken.compatibility(with: highProteinDiet), .perfect)

        // Avoid meat on vegan
        let veganDiet = DietPlan.defaultDiets.first { $0.key == "vegan" }
        XCTAssertEqual(chicken.compatibility(with: veganDiet), .avoid)
        
        let beef = FoodItem(name: "Beef Steak", weight: 100, calories: 250, protein: 26, fats: 15, carbs: 0)
        XCTAssertEqual(beef.compatibility(with: veganDiet), .avoid)
    }
}
