import Foundation
import SwiftUI
import Observation
import FirebaseFirestore

@Observable
class RecipeDataLoader {
    static let shared = RecipeDataLoader()

    var recipes: [PremiumRecipe] = []
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var hasLoadedRemote = false
    private static let favoritesDefaultsKey = "favoriteRecipeTitles_v1"

    init() {
        let langCode = Locale.current.language.languageCode?.identifier
        Task.detached(priority: .userInitiated) { [weak self] in
            let bundled = Self.applyFavorites(to: Self.loadBundledRecipes(languageCode: langCode))
            await MainActor.run {
                guard let self else { return }
                if self.recipes.isEmpty && !self.hasLoadedRemote {
                    self.recipes = bundled
                }
                self.fetchRecipes()
            }
        }
    }

    func resetFavorites() {
        for index in recipes.indices {
            recipes[index].isFavorite = false
        }
    }

    deinit {
        listener?.remove()
    }

    static func loadBundledRecipes(languageCode: String? = Locale.current.language.languageCode?.identifier) -> [PremiumRecipe] {
        let code = (languageCode ?? "en").lowercased()
        let resourceName: String
        switch code {
        case "ru", "de", "es", "fr", "it":
            resourceName = "recipes_\(code)"
        case "pt":
            resourceName = "recipes_pt-PT"
        default:
            resourceName = "recipes"
        }

        let candidates = [resourceName, "recipes"]
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([BundledPremiumRecipe].self, from: data),
               !decoded.isEmpty {
                return decoded.map { $0.toPremiumRecipe() }
            }
        }
        return []
    }

    private struct BundledPremiumRecipe: Decodable {
        let title: String
        let description: String
        let time: String
        let caloriesPerServing: Int
        let imageUrl: String
        let isFavorite: Bool?
        let tags: [String]?
        let baseServings: Int?
        let protein: Double
        let fat: Double
        let carbs: Double
        let ingredients: [RecipeIngredient]?
        let directions: [String]?

        func toPremiumRecipe() -> PremiumRecipe {
            PremiumRecipe(
                id: title,
                title: title,
                description: description,
                time: time,
                caloriesPerServing: caloriesPerServing,
                imageUrl: imageUrl,
                isFavorite: isFavorite ?? false,
                tags: tags ?? [],
                baseServings: baseServings ?? 1,
                protein: protein,
                fat: fat,
                carbs: carbs,
                ingredients: ingredients ?? [],
                directions: directions ?? []
            )
        }
    }

    private static func applyFavorites(to items: [PremiumRecipe]) -> [PremiumRecipe] {
        let savedFavorites = Set(UserDefaults.standard.stringArray(forKey: favoritesDefaultsKey) ?? [])
        guard !savedFavorites.isEmpty else { return items }
        return items.map { recipe in
            var copy = recipe
            if savedFavorites.contains(recipe.title) || (recipe.id.map { savedFavorites.contains($0) } ?? false) {
                copy.isFavorite = true
            }
            return copy
        }
    }

    static func shouldPreferRemoteCatalog(languageCode: String? = Locale.current.language.languageCode?.identifier) -> Bool {
        (languageCode ?? "en").lowercased() == "en"
    }

    func fetchRecipes() {
        // Avoid overwriting localized bundled JSON recipes with single-language Firestore documents.
        guard Self.shouldPreferRemoteCatalog() || recipes.isEmpty else { return }
        listener?.remove()
        listener = db.collection("premium_recipes").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ Error loading recipes from Firestore (using bundled fallback): \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else { return }

            let remote = documents.compactMap { try? $0.data(as: PremiumRecipe.self) }
            if !remote.isEmpty {
                let applied = Self.applyFavorites(to: remote)
                DispatchQueue.main.async {
                    self.hasLoadedRemote = true
                    self.recipes = applied
                }
            }
        }
    }

    func toggleFavorite(for id: String?) {
        guard let id = id,
              let index = recipes.firstIndex(where: { $0.id == id || $0.title == id }) else { return }
        recipes[index].isFavorite.toggle()
        let key = recipes[index].title
        var saved = Set(UserDefaults.standard.stringArray(forKey: Self.favoritesDefaultsKey) ?? [])
        if recipes[index].isFavorite {
            saved.insert(key)
        } else {
            saved.remove(key)
        }
        UserDefaults.standard.set(Array(saved), forKey: Self.favoritesDefaultsKey)
    }
}
