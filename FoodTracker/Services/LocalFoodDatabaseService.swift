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
    var omega3: Double? = nil
    var calcium: Double? = nil
    var potassium: Double? = nil
    var magnesium: Double? = nil
    var iron: Double? = nil
    var vitaminC: Double? = nil
    var vitaminD: Double? = nil

    // Convert to FoodItem (SwiftData model) for use in the app
    func toFoodItem(weight: Double = 100) -> FoodItem {
        let factor = weight > 0 ? (weight / 100.0) : 1.0
        let estimated = MicronutrientEstimator.estimate(
            id: id,
            name: name,
            category: category,
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
            weight: weight
        )
        return FoodItem(
            name: name,
            weight: weight,
            calories: max(0, Int((Double(calories) * factor).rounded())),
            protein: max(0, protein * factor),
            fats: max(0, fat * factor),
            carbs: max(0, carbs * factor),
            omega3: omega3.map { max(0, $0 * factor) } ?? estimated.omega3,
            calcium: calcium.map { max(0, $0 * factor) } ?? estimated.calcium,
            potassium: potassium.map { max(0, $0 * factor) } ?? estimated.potassium,
            magnesium: magnesium.map { max(0, $0 * factor) } ?? estimated.magnesium,
            iron: iron.map { max(0, $0 * factor) } ?? estimated.iron,
            vitaminC: vitaminC.map { max(0, $0 * factor) } ?? estimated.vitaminC,
            vitaminD: vitaminD.map { max(0, $0 * factor) } ?? estimated.vitaminD
        )
    }
}

// MARK: - Local Food Database Service
/// Provides instant, zero-network, zero-Firestore food search from bundled JSON files.
/// Files: foods_ru.json, foods_en.json, foods_de.json, foods_es.json, foods_fr.json, foods_it.json
///
/// Architecture: JSON decoding and search-key normalization run off the main actor at startup,
/// then indexed entries are stored in memory for O(N) substring/prefix scans without per-keystroke allocations.
final class LocalFoodDatabaseService {
    static let shared = LocalFoodDatabaseService()

    private struct IndexedFoodEntry {
        let entry: LocalFoodEntry
        let foldedName: String
        let foldedWords: Set<String>
    }

    private let lock = NSLock()
    private var primaryLanguageCode: String = "en"
    private var indexedFoods: [IndexedFoodEntry] = []
    private var indexedFallbackFoods: [IndexedFoodEntry] = []
    private var _isLoaded = false
    private var loadTask: Task<Void, Never>?

    /// Foods for the current device language
    var foods: [LocalFoodEntry] {
        lock.withLock { indexedFoods.map(\.entry) }
    }

    /// All English foods — used as fallback when locale-specific search returns nothing
    var fallbackFoods: [LocalFoodEntry] {
        lock.withLock { indexedFallbackFoods.map(\.entry) }
    }

    /// Indicates whether background JSON decoding and indexing has finished.
    var isLoaded: Bool {
        lock.withLock { _isLoaded }
    }

    private init() {
        let lang = Self.resolveLanguageCode()
        primaryLanguageCode = lang
        loadTask = Task.detached(priority: .userInitiated) { [weak self] in
            let primary = Self.loadAndIndexFoods(language: lang)
            let fallback = lang == "en" ? [] : Self.loadAndIndexFoods(language: "en")
            guard let self else { return }
            self.lock.withLock {
                self.indexedFoods = primary
                self.indexedFallbackFoods = fallback
                self._isLoaded = true
            }
            print("📚 LocalFoodDB: loaded \(primary.count) '\(lang)' foods + \(fallback.count) EN fallback (async)")
        }
    }

    /// Suspends until the initial off-main-thread database load completes.
    func waitUntilLoaded() async {
        await loadTask?.value
    }

    // MARK: - Search

    /// Thread-safe raw entry search that can run off the main actor before creating SwiftData `FoodItem` instances.
    func searchEntriesSnapshot(query: String, limit: Int = 15) -> [LocalFoodEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }

        let (primary, fallback, primaryLang) = lock.withLock { (indexedFoods, indexedFallbackFoods, primaryLanguageCode) }
        return Self.searchIndexedEntries(
            primary: primary,
            fallback: fallback,
            query: trimmed,
            limit: limit,
            primaryLanguageCode: primaryLang
        )
    }

    /// Returns up to `limit` foods matching `query` using pre-normalized locale-aware substring matching.
    /// Supplements non-English results from `foods_en` up to `limit` without duplicates.
    func search(query: String, limit: Int = 15) -> [FoodItem] {
        searchEntriesSnapshot(query: query, limit: limit).map { $0.toFoodItem() }
    }

    static func searchEntries(
        primary: [LocalFoodEntry],
        fallback: [LocalFoodEntry],
        query: String,
        limit: Int = 15,
        primaryLanguageCode: String = "en"
    ) -> [LocalFoodEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, limit > 0 else { return [] }
        return searchIndexedEntries(
            primary: indexEntries(primary),
            fallback: indexEntries(fallback),
            query: trimmed,
            limit: limit,
            primaryLanguageCode: primaryLanguageCode
        )
    }

    private static func searchIndexedEntries(
        primary: [IndexedFoodEntry],
        fallback: [IndexedFoodEntry],
        query: String,
        limit: Int,
        primaryLanguageCode: String
    ) -> [LocalFoodEntry] {
        var results = matchFoods(primary, query: query, languageCode: primaryLanguageCode)

        if results.count < limit && !fallback.isEmpty {
            let existingNames = Set(results.map { $0.name.lowercased() })
            let fallbackMatches = matchFoods(fallback, query: query, languageCode: "en")
                .filter { !existingNames.contains($0.name.lowercased()) }
            results += fallbackMatches
        }

        return Array(results.prefix(limit))
    }

    /// Async search that ensures background database loading has finished before querying.
    func searchAsync(query: String, limit: Int = 15) async -> [FoodItem] {
        await waitUntilLoaded()
        return search(query: query, limit: limit)
    }

    /// Returns true if local database has at least one result for the query.
    func hasResults(for query: String) -> Bool {
        !search(query: query, limit: 1).isEmpty
    }

    /// Synchronously decodes the bundled food database for an explicit language code (used in diagnostics/tests).
    static func loadBundledFoods(languageCode: String? = Locale.current.language.languageCode?.identifier) -> [LocalFoodEntry] {
        let suffix = resolveLanguageCode(for: languageCode)
        return loadAndIndexFoods(language: suffix).map(\.entry)
    }

    // MARK: - Private helpers

    private static func normalizeForSearch(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private static func matchFoods(_ entries: [IndexedFoodEntry], query: String, languageCode: String) -> [LocalFoodEntry] {
        let normalizedQuery = Self.normalizeForSearch(query)
        let queryRoots = SmartSearch.getRoots(for: query, languageCode: languageCode)
        var scored: [(score: Int, entry: LocalFoodEntry)] = []

        for indexed in entries {
            let name = indexed.foldedName
            var score = 0
            if name.hasPrefix(normalizedQuery) {
                score = 100
            } else if name.contains(" \(normalizedQuery)") || name.contains("(\(normalizedQuery)") {
                score = 60
            } else if name.contains(normalizedQuery) {
                score = 30
            } else if !queryRoots.isEmpty && SmartSearch.matchesFolded(normalizedName: name, queryRoots: queryRoots) {
                score = 20
            } else {
                continue
            }
            // Bonus: exact word match using pre-tokenized word set
            if indexed.foldedWords.contains(normalizedQuery) {
                score += 20
            }
            scored.append((score, indexed.entry))
        }

        return scored.sorted { $0.score > $1.score }.map(\.entry)
    }

    /// Maps device language codes to bundled JSON resource suffixes (including European Portuguese `pt-PT`).
    static func resolveLanguageCode(for languageCode: String? = Locale.current.language.languageCode?.identifier) -> String {
        let code = (languageCode ?? "en").lowercased()
        switch code {
        case "ru", "en", "de", "es", "fr", "it":
            return code
        case "pt":
            return "pt-PT"
        default:
            return "en"
        }
    }

    private static func indexEntries(_ entries: [LocalFoodEntry]) -> [IndexedFoodEntry] {
        entries.map { entry in
            let folded = normalizeForSearch(entry.name)
            let words = Set(folded.split(separator: " ").map(String.init))
            return IndexedFoodEntry(entry: entry, foldedName: folded, foldedWords: words)
        }
    }

    private static func loadAndIndexFoods(language: String) -> [IndexedFoodEntry] {
        guard let url = Bundle.main.url(forResource: "foods_\(language)", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([LocalFoodEntry].self, from: data) else {
            print("⚠️ LocalFoodDB: could not load foods_\(language).json")
            return []
        }
        return indexEntries(entries)
    }
}


