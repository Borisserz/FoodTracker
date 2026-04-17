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
    
    // ✅ ДОБАВЛЕНО: Храним ID прочитанных статей
    var completedArticleIDs: Set<String> = []
    
    init() {
        loadCompletedArticles()
        loadData()
    }
    
    // Загружаем сохраненный прогресс
    private func loadCompletedArticles() {
        if let saved = UserDefaults.standard.array(forKey: "CompletedAcademyArticles") as? [String] {
            completedArticleIDs = Set(saved)
        }
    }
    
    // Сохраняем прогресс в память телефона
    private func saveCompletedArticles() {
        UserDefaults.standard.set(Array(completedArticleIDs), forKey: "CompletedAcademyArticles")
    }
    
    // Метод, который вызывается при нажатии кнопки "Mark as Completed"
    func markAsCompleted(articleID: String) {
        completedArticleIDs.insert(articleID)
        saveCompletedArticles()
        recalculateProgress()
    }
    
    // Пересчет полоски прогресса для каждой категории
    private func recalculateProgress() {
        for i in 0..<categories.count {
            let completedInCat = categories[i].articles.filter { completedArticleIDs.contains($0.id) }.count
            categories[i].completedCount = completedInCat
        }
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
                self.recalculateProgress() // ✅ ДОБАВЛЕНО: Считаем прогресс сразу после загрузки
            }
        } catch {
            print("❌ Ошибка парсинга academy.json: \(error)")
        }
    }
}
