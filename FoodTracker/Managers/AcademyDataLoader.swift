import SwiftUI
import Observation

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
    let readTime: Int
    let isLocked: Bool
    let colorHex1: String
    let colorHex2: String
    let iconName: String
    let content: String

    var color1: Color { Color.fromHex(colorHex1) ?? .gray }
    var color2: Color { Color.fromHex(colorHex2) ?? .black }
}

@Observable
class AcademyDataLoader {
    var categories: [ArticleCategory] = []

    var completedArticleIDs: Set<String> = []

    init() {
        loadCompletedArticles()
        loadData()
    }

    private func loadCompletedArticles() {
        if let saved = UserDefaults.standard.array(forKey: "CompletedAcademyArticles") as? [String] {
            completedArticleIDs = Set(saved)
        }
    }

    private func saveCompletedArticles() {
        UserDefaults.standard.set(Array(completedArticleIDs), forKey: "CompletedAcademyArticles")
    }

    func markAsCompleted(articleID: String) {
        completedArticleIDs.insert(articleID)
        saveCompletedArticles()
        recalculateProgress()
    }

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
                self.recalculateProgress()
            }
        } catch {
            print("❌ Ошибка парсинга academy.json: \(error)")
        }
    }
}
