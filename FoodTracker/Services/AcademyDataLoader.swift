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
    var categories: [ArticleCategory] = []
    var completedArticleIDs: Set<String> = []
    
    private let db = Firestore.firestore()

    init() {
        loadCompletedArticles()
        fetchCategoriesFromFirestore()
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

    private func recalculateProgress() {
        for i in 0..<categories.count {
            let completedInCat = categories[i].articles.filter { completedArticleIDs.contains($0.id) }.count
            categories[i].completedCount = completedInCat
        }
    }

    func fetchCategoriesFromFirestore() {
        db.collection("academy_categories").addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Ошибка загрузки Академии: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            do {
                let fetchedCategories = try documents.compactMap { try $0.data(as: ArticleCategory.self) }
                
                DispatchQueue.main.async {
                    self.categories = fetchedCategories.sorted { $0.title < $1.title } // Или добавь поле order для сортировки
                    self.recalculateProgress()
                    print("✅ Академия загружена: \(self.categories.count) категорий.")
                }
            } catch {
                print("❌ Ошибка парсинга Академии: \(error)")
            }
        }
    }
}
import FirebaseFirestore
import Foundation

class FirebaseUploader {
    static let shared = FirebaseUploader()
    private let db = Firestore.firestore()
    
    func seedDatabaseIfNeeded() {
#if DEBUG
        db.collection("diets").limit(to: 1).getDocuments { [weak self] snapshot, _ in
            if let snapshot = snapshot, snapshot.documents.isEmpty {
                print("🌱 Seeding diets...")
                self?.uploadDiets()
            }
        }
        
        db.collection("fasting_plans").limit(to: 1).getDocuments { [weak self] snapshot, _ in
            if let snapshot = snapshot, snapshot.documents.isEmpty {
                print("🌱 Seeding fasting plans...")
                self?.uploadFastingPlans()
            }
        }
        
        db.collection("premium_recipes").limit(to: 1).getDocuments { [weak self] snapshot, _ in
            if let snapshot = snapshot, snapshot.documents.isEmpty {
                print("🌱 Seeding premium recipes...")
                self?.uploadRecipesFromJSON()
            }
        }
        
        db.collection("academy_categories").limit(to: 1).getDocuments { [weak self] snapshot, _ in
            if let snapshot = snapshot, snapshot.documents.isEmpty {
                print("🌱 Seeding academy categories...")
                self?.uploadAcademyFromJSON()
            }
        }
#endif
    }
    
    // 1. Выгрузка рецептов
    func uploadRecipesFromJSON() {
        guard let url = Bundle.main.url(forResource: "recipes", withExtension: "json") else { return }
        
        do {
            let data = try Data(contentsOf: url)
            // Парсим твою старую модель (где ID был UUID)
            let recipes = try JSONDecoder().decode([PremiumRecipe].self, from: data)
            
            for recipe in recipes {
                do {
                    // Создаем новый документ в коллекции
                    let docRef = db.collection("premium_recipes").document()
                    try docRef.setData(from: recipe)
                    print("⬆️ Загружен рецепт: \(recipe.title)")
                } catch {
                    print("Ошибка при загрузке рецепта: \(error)")
                }
            }
            print("✅ Все рецепты успешно загружены в Firestore!")
        } catch {
            print("Ошибка чтения recipes.json: \(error)")
        }
    }
    
    // Временная функция для выгрузки 15 новых рецептов
    func uploadNewRecipesFromJSON() {
        guard let url = Bundle.main.url(forResource: "new_recipes", withExtension: "json") else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let newRecipes = try JSONDecoder().decode([PremiumRecipe].self, from: data)
            
            for recipe in newRecipes {
                do {
                    let docRef = db.collection("premium_recipes").document()
                    try docRef.setData(from: recipe)
                    print("⬆️ Загружен НОВЫЙ рецепт: \(recipe.title)")
                } catch {
                    print("Ошибка при загрузке нового рецепта: \(error)")
                }
            }
            print("✅ Все НОВЫЕ рецепты успешно добавлены в Firestore!")
        } catch {
            print("Ошибка чтения new_recipes.json: \(error)")
        }
    }
    // Выгрузка диет
        func uploadDiets() {
            for diet in DietPlan.defaultDiets { // defaultDiets - тот самый массив, который мы переименовали
                do {
                    try db.collection("diets").document(diet.key).setData(from: diet)
                    print("⬆️ Загружена диета: \(diet.name)")
                } catch {
                    print("❌ Ошибка диеты: \(error)")
                }
            }
        }
        
        // Выгрузка планов голодания
        func uploadFastingPlans() {
            for plan in FastingPlan.defaultPlans { // defaultPlans - массив планов
                do {
                    try db.collection("fasting_plans").document().setData(from: plan)
                    print("⬆️ Загружен план: \(plan.title)")
                } catch {
                    print("❌ Ошибка плана: \(error)")
                }
            }
        }
    // 2. Выгрузка Академии
    func uploadAcademyFromJSON() {
           guard let url = Bundle.main.url(forResource: "academy", withExtension: "json") else { return }
           
           do {
               let data = try Data(contentsOf: url)
               
               // Читаем как сырой массив словарей (чтобы обойти конфликт Codable и @DocumentID)
               guard let categoriesArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                   print("❌ Не удалось распарсить academy.json как массив словарей")
                   return
               }
               
               for categoryDict in categoriesArray {
                   let docRef = db.collection("academy_categories").document()
                   // Заливаем данные напрямую
                   docRef.setData(categoryDict) { error in
                       if let error = error {
                           print("❌ Ошибка при загрузке категории: \(error)")
                       } else {
                           print("⬆️ Загружена категория из Академии")
                       }
                   }
               }
               print("✅ Скрипт загрузки Академии завершен!")
           } catch {
               print("❌ Ошибка чтения academy.json: \(error)")
           }
       }
}
