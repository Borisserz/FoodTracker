import Foundation
import SwiftUI
import Observation

@Observable
class RecipeDataLoader {
    var recipes: [PremiumRecipe] = []

    init() {
        loadRecipes()
    }

    func loadRecipes() {
        guard let url = Bundle.main.url(forResource: "recipes", withExtension: "json") else {
            print("❌ recipes.json не найден. Использую моковые данные.")
            self.recipes = mockRecipesData
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([PremiumRecipe].self, from: data)

            DispatchQueue.main.async {
                self.recipes = decoded
            }
        } catch {
            print("❌ Ошибка парсинга JSON: \(error)")
            self.recipes = mockRecipesData
        }
    }
    func toggleFavorite(for id: UUID) {

           if let index = recipes.firstIndex(where: { $0.id == id }) {
               recipes[index].isFavorite.toggle()
           }
       }
}
