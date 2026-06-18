import Foundation
import SwiftUI
import Observation
import FirebaseFirestore

struct ArticleCategory: Identifiable, Codable, Hashable {
    var id: String?
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
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        var fileName = "academy_\(langCode)"
        
        var url = Bundle.main.url(forResource: fileName, withExtension: "json")
        if url == nil {
            fileName = "academy"
            url = Bundle.main.url(forResource: fileName, withExtension: "json")
        }
        
        guard let url = url else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let fetchedCategories = try JSONDecoder().decode([ArticleCategory].self, from: data)
            
            DispatchQueue.main.async {
                self.categories = fetchedCategories.sorted { $0.title < $1.title } 
                self.recalculateProgress()
                print("✅ Academy loaded from JSON: \(self.categories.count) categories.")
            }
        } catch {
            print("❌ Error parsing Academy JSON: \(error)")
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
    
    
    func uploadRecipesFromJSON() {
        guard let url = Bundle.main.url(forResource: "recipes", withExtension: "json") else { return }
        
        do {
            let data = try Data(contentsOf: url)
            
            let recipes = try JSONDecoder().decode([PremiumRecipe].self, from: data)
            
            for recipe in recipes {
                do {
                    
                    let docRef = db.collection("premium_recipes").document()
                    try docRef.setData(from: recipe)
                    print("Log output removed for English localization")
                } catch {
                    print("Log output removed for English localization")
                }
            }
            print("Log output removed for English localization")
        } catch {
            print("Log output removed for English localization")
        }
    }
    
    
    func uploadNewRecipesFromJSON() {
        guard let url = Bundle.main.url(forResource: "new_recipes", withExtension: "json") else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let newRecipes = try JSONDecoder().decode([PremiumRecipe].self, from: data)
            
            for recipe in newRecipes {
                do {
                    let docRef = db.collection("premium_recipes").document()
                    try docRef.setData(from: recipe)
                    print("Log output removed for English localization")
                } catch {
                    print("Log output removed for English localization")
                }
            }
            print("Log output removed for English localization")
        } catch {
            print("Log output removed for English localization")
        }
    }
    
        func uploadDiets() {
            for diet in DietPlan.defaultDiets { 
                do {
                    try db.collection("diets").document(diet.key).setData(from: diet)
                    print("Log output removed for English localization")
                } catch {
                    print("Log output removed for English localization")
                }
            }
        }
        
        
        func uploadFastingPlans() {
            for plan in FastingPlan.defaultPlans { 
                do {
                    try db.collection("fasting_plans").document().setData(from: plan)
                    print("Log output removed for English localization")
                } catch {
                    print("Log output removed for English localization")
                }
            }
        }
    
    func uploadAcademyFromJSON() {
           guard let url = Bundle.main.url(forResource: "academy", withExtension: "json") else { return }
           
           do {
               let data = try Data(contentsOf: url)
               
               
               guard let categoriesArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                   print("Log output removed for English localization")
                   return
               }
               
               for categoryDict in categoriesArray {
                   let docRef = db.collection("academy_categories").document()
                   
                   docRef.setData(categoryDict) { error in
                       if let error = error {
                           print("Log output removed for English localization")
                       } else {
                           print("Log output removed for English localization")
                       }
                   }
               }
               print("Log output removed for English localization")
           } catch {
               print("Log output removed for English localization")
           }
       }
}
