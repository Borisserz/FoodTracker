import Foundation
import SwiftUI
import Observation // Указываем современный фреймворк

@Observable
class RecipeDataLoader {
    var recipes: [PremiumRecipe] = []
    
    init() {
        loadRecipes()
    }
    
    func loadRecipes() {
        guard let url = Bundle.main.url(forResource: "recipes", withExtension: "json") else {
            print("❌ recipes.json не найден. Использую моковые данные.")
            self.recipes = mockRecipesData // Если файла нет, берем тестовые данные
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
           // Ищем рецепт по ID и меняем его статус
           if let index = recipes.firstIndex(where: { $0.id == id }) {
               recipes[index].isFavorite.toggle()
           }
       }
}
