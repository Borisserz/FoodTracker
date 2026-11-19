import XCTest
@testable import FoodTracker

final class RecipeTagCatalogTests: XCTestCase {

    func testAllBundledRecipeTagsAcrossSevenLanguagesMapToCanonicalTags() {
        for code in ["en", "ru", "de", "es", "fr", "it", "pt"] {
            let recipes = RecipeDataLoader.loadBundledRecipes(languageCode: code)
            XCTAssertEqual(recipes.count, 61)
            for recipe in recipes {
                for rawTag in recipe.tags {
                    XCTAssertNotNil(
                        RecipeTagCatalog.canonicalTag(for: rawTag),
                        "Missing canonical tag mapping for '\(rawTag)' in locale '\(code)'"
                    )
                }
            }
        }
    }

    func testDiscoverSectionsPartitionPopulatesAllCategoriesAcrossAllLanguages() {
        for code in ["en", "ru", "de", "es", "fr", "it", "pt"] {
            let recipes = RecipeDataLoader.loadBundledRecipes(languageCode: code)
            let sections = ChefDiscoverSections.partition(recipes)
            XCTAssertFalse(sections.highProtein.isEmpty, "highProtein empty for \(code)")
            XCTAssertFalse(sections.ketoLowCarb.isEmpty, "ketoLowCarb empty for \(code)")
            XCTAssertFalse(sections.quickEasy.isEmpty, "quickEasy empty for \(code)")
            XCTAssertFalse(sections.plantBased.isEmpty, "plantBased empty for \(code)")

            let breakfast = ChefDiscoverSections.filter(recipes, matchingAnyCanonicalTags: ["Breakfast"])
            XCTAssertFalse(breakfast.isEmpty, "Breakfast filter empty for \(code)")
        }
    }

    func testSpanishAndPortugueseRecipesFixMistranslatedTagsAndLocalizedTimes() {
        let esRecipes = RecipeDataLoader.loadBundledRecipes(languageCode: "es")
        let esTags = Set(esRecipes.flatMap(\.tags))
        XCTAssertFalse(esTags.contains("Zalamero"))
        XCTAssertFalse(esTags.contains("Muy activo"))
        XCTAssertFalse(esTags.contains("Hornada"))
        XCTAssertTrue(esTags.contains("Batido"))
        XCTAssertTrue(esTags.contains("Para llevar"))
        XCTAssertTrue(esTags.contains("Horneado"))

        let ptRecipes = RecipeDataLoader.loadBundledRecipes(languageCode: "pt")
        let ptTags = Set(ptRecipes.flatMap(\.tags))
        XCTAssertFalse(ptTags.contains("Café da manhã"))
        XCTAssertFalse(ptTags.contains("Cozimento"))
        XCTAssertTrue(ptTags.contains("Pequeno-almoço"))

        let ruRecipes = RecipeDataLoader.loadBundledRecipes(languageCode: "ru")
        XCTAssertTrue(ruRecipes.allSatisfy { $0.time.contains("мин") })

        let deRecipes = RecipeDataLoader.loadBundledRecipes(languageCode: "de")
        XCTAssertTrue(deRecipes.allSatisfy { $0.time.contains("Min.") })
    }
}
