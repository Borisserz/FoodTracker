import Foundation
import SwiftUI
import Observation
import FirebaseFirestore

@Observable
class RecipeDataLoader {
    var recipes: [PremiumRecipe] = []
    private let db = Firestore.firestore()
    
    init() {
        fetchRecipes()
    }
    
    func fetchRecipes() {
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        var fileName = "recipes_\(langCode)"
        
        var url = Bundle.main.url(forResource: fileName, withExtension: "json")
        if url == nil {
            fileName = "recipes"
            url = Bundle.main.url(forResource: fileName, withExtension: "json")
        }
        
        guard let url = url else { return }
        
        do {
            let data = try Data(contentsOf: url)
            self.recipes = try JSONDecoder().decode([PremiumRecipe].self, from: data)
            print("✅ All recipes loaded from JSON! Total: \(self.recipes.count)")
        } catch {
            print("❌ Error parsing recipes JSON: \(error)")
        }
    }
    
    func toggleFavorite(for id: String?) {
        guard let id = id, let index = recipes.firstIndex(where: { $0.id == id }) else { return }
        recipes[index].isFavorite.toggle()
    }
}
