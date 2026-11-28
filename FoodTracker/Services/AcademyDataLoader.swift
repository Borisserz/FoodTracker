import Foundation
import SwiftUI
import Observation
import FirebaseFirestore

struct ArticleCategory: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    let title: String
    var completedCount: Int = 0
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
    static let shared = AcademyDataLoader()
    private static let cacheLock = NSLock()
    private static var bundledCache: [String: [ArticleCategory]] = [:]

    var categories: [ArticleCategory] = []
    var completedArticleIDs: Set<String> = []
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var hasLoadedRemote = false

    init() {
        loadCompletedArticles()
        let langCode = Locale.current.language.languageCode?.identifier
        Task.detached(priority: .userInitiated) { [weak self] in
            let bundled = Self.loadBundledCategories(languageCode: langCode)
            await MainActor.run {
                guard let self else { return }
                if self.categories.isEmpty && !self.hasLoadedRemote {
                    self.categories = bundled
                    self.recalculateProgress()
                }
                self.fetchCategoriesFromFirestore()
            }
        }
    }

    deinit {
        listener?.remove()
    }

    static func loadBundledCategories(languageCode: String? = Locale.current.language.languageCode?.identifier) -> [ArticleCategory] {
        let code = (languageCode ?? "en").lowercased()
        let resourceName: String
        switch code {
        case "ru", "de", "es", "fr", "it":
            resourceName = "academy_\(code)"
        case "pt":
            resourceName = "academy_pt-PT"
        default:
            resourceName = "academy"
        }

        if let cached = cacheLock.withLock({ bundledCache[resourceName] }) {
            return cached
        }

        for candidate in [resourceName, "academy"] {
            if let url = Bundle.main.url(forResource: candidate, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([BundledArticleCategory].self, from: data),
               !decoded.isEmpty {
                let mapped = decoded.map { $0.toArticleCategory() }
                cacheLock.withLock { bundledCache[resourceName] = mapped }
                return mapped
            }
        }
        return []
    }

    private struct BundledArticleCategory: Decodable {
        let id: String?
        let title: String
        let completedCount: Int?
        let articles: [Article]

        func toArticleCategory() -> ArticleCategory {
            ArticleCategory(
                id: id ?? title,
                title: title,
                completedCount: completedCount ?? 0,
                articles: articles
            )
        }
    }

    private func loadCompletedArticles() {
        if let saved = UserDefaults.standard.array(forKey: "CompletedAcademyArticles") as? [String] {
            completedArticleIDs = Set(saved)
        }
    }

    func markAsCompleted(articleID: String) {
        completedArticleIDs.insert(articleID)
        UserDefaults.standard.set(Array(completedArticleIDs), forKey: "CompletedAcademyArticles")
        recalculateProgress()
    }

    func resetProgress() {
        completedArticleIDs.removeAll()
        recalculateProgress()
    }

    private func recalculateProgress() {
        for i in 0..<categories.count {
            let completedInCat = categories[i].articles.filter { completedArticleIDs.contains($0.id) }.count
            categories[i].completedCount = completedInCat
        }
    }

    static func shouldPreferRemoteCatalog(languageCode: String? = Locale.current.language.languageCode?.identifier) -> Bool {
        (languageCode ?? "en").lowercased() == "en"
    }

    func fetchCategoriesFromFirestore() {
        guard Self.shouldPreferRemoteCatalog() || categories.isEmpty else { return }
        listener?.remove()
        listener = db.collection("academy_categories").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("❌ Ошибка загрузки Академии (используем локальный фоллбек): \(error.localizedDescription)")
                #endif
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else { return }

            let fetchedCategories = documents.compactMap { try? $0.data(as: ArticleCategory.self) }
            guard !fetchedCategories.isEmpty else { return }

            DispatchQueue.main.async {
                self.hasLoadedRemote = true
                self.categories = fetchedCategories.sorted { $0.title < $1.title }
                self.recalculateProgress()
                #if DEBUG
                print("✅ Академия загружена: \(self.categories.count) категорий.")
                #endif
            }
        }
    }
}
