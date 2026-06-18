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
        db.collection("premium_recipes").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error loading recipes: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            do {
                self.recipes = try documents.compactMap { try $0.data(as: PremiumRecipe.self) }
                print("✅ All recipes loaded! Total: \(self.recipes.count)")
            } catch {
                print("❌ Error parsing recipes: \(error)")
            }
        }
    }
    
    func toggleFavorite(for id: String?) {
        guard let id = id, let index = recipes.firstIndex(where: { $0.id == id }) else { return }
        recipes[index].isFavorite.toggle()
    }
}
