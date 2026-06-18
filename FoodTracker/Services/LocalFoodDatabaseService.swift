import Foundation
import SwiftData

// MARK: - Local Food Entry (Codable JSON record)
struct LocalFoodEntry: Codable, Identifiable {
    let id: String
    let name: String
    let calories: Int
    let protein: Double
    let fat: Double
    let carbs: Double
    let category: String

    // Convert to FoodItem (SwiftData model) for use in the app
    func toFoodItem(weight: Double = 100) -> FoodItem {
        FoodItem(
            name: name,
            weight: weight,
            calories: Int(Double(calories) * weight / 100),
            protein: protein * weight / 100,
            fats: fat * weight / 100,
            carbs: carbs * weight / 100
        )
    }
}

// MARK: - Local Food Database Service
/// Provides instant, zero-network, zero-Firestore food search from bundled JSON files.
/// Files: foods_ru.json, foods_en.json, foods_de.json, foods_es.json, foods_fr.json, foods_it.json
///
/// Architecture: loaded once at startup, kept in memory, searched with simple substring matching.
/// Typical load time: <5ms. Memory footprint: ~200KB for all languages combined.
final class LocalFoodDatabaseService {
    static let shared = LocalFoodDatabaseService()

    /// Foods for the current device language (loaded at init)
    private(set) var foods: [LocalFoodEntry] = []

    /// All English foods — used as fallback when locale-specific search returns nothing
    private(set) var fallbackFoods: [LocalFoodEntry] = []

    private init() {
        let lang = resolveLanguageCode()
        foods = loadFoods(language: lang)
        // Always load English as fallback (avoids showing nothing for unsupported locales)
        if lang != "en" {
            fallbackFoods = loadFoods(language: "en")
        }
        print("📚 LocalFoodDB: loaded \(foods.count) '\(lang)' foods + \(fallbackFoods.count) EN fallback")
    }

    // MARK: - Search

    /// Returns up to `limit` foods matching `query` using locale-aware substring matching.
    /// Falls back to English results if locale-specific database returns fewer than 3 hits.
    func search(query: String, limit: Int = 15) -> [FoodItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        var results = matchFoods(foods, query: q)

        // Supplement with English fallback if not enough locale results
        if results.count < 3 && !fallbackFoods.isEmpty {
            let fallback = matchFoods(fallbackFoods, query: q)
                .filter { fb in !results.contains(where: { $0.name.lowercased() == fb.name.lowercased() }) }
            results += fallback
        }

        return Array(results.prefix(limit)).map { $0.toFoodItem() }
    }

    /// Returns true if local database has at least one result for the query.
    func hasResults(for query: String) -> Bool {
        !search(query: query, limit: 1).isEmpty
    }

    // MARK: - Private helpers

    private func matchFoods(_ foods: [LocalFoodEntry], query: String) -> [LocalFoodEntry] {
        // Score: starts-with name gets highest priority, then any word starts-with, then substring
        var scored: [(score: Int, entry: LocalFoodEntry)] = []

        for entry in foods {
            let name = entry.name.lowercased()
            var score = 0
            if name.hasPrefix(query) {
                score = 100
            } else if name.contains(" \(query)") || name.contains("(\(query)") {
                score = 60
            } else if name.contains(query) {
                score = 30
            } else {
                continue
            }
            // Bonus: exact word match
            if name.components(separatedBy: " ").contains(query) {
                score += 20
            }
            scored.append((score, entry))
        }

        return scored.sorted { $0.score > $1.score }.map { $0.entry }
    }

    private func resolveLanguageCode() -> String {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        let supported = ["ru", "en", "de", "es", "fr", "it"]
        return supported.contains(code) ? code : "en"
    }

    private func loadFoods(language: String) -> [LocalFoodEntry] {
        guard let url = Bundle.main.url(forResource: "foods_\(language)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([LocalFoodEntry].self, from: data) else {
            print("⚠️ LocalFoodDB: could not load foods_\(language).json")
            return []
        }
        return entries
    }
}


