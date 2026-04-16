import SwiftUI
import Observation

// MARK: - МОДЕЛИ ДАННЫХ ДЛЯ ОБУЧЕНИЯ (ДЛЯ РАБОТЫ С JSON)

struct ArticleCategory: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    var completedCount: Int
    let articles: [Article]
    
    var totalCount: Int { articles.count }
}

struct Article: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let readTime: Int // В минутах
    let isLocked: Bool
    let colorHex1: String
    let colorHex2: String
    let iconName: String
    let content: String // Здесь будет полный текст статьи (Markdown)
    
    // Вспомогательные свойства для конвертации HEX в Color
    var color1: Color { Color.fromHex(colorHex1) ?? .gray }
    var color2: Color { Color.fromHex(colorHex2) ?? .black }
}

@Observable
class AcademyDataLoader {
    var categories: [ArticleCategory] = []
    
    init() {
        loadData()
    }
    
    func loadData() {
        guard let url = Bundle.main.url(forResource: "academy", withExtension: "json") else {
            print("❌ academy.json не найден. Загрузите JSON файл в проект.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([ArticleCategory].self, from: data)
            
            DispatchQueue.main.async {
                self.categories = decoded
            }
        } catch {
            print("❌ Ошибка парсинга academy.json: \(error)")
        }
    }
}
