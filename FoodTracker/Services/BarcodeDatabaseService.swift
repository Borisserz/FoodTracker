import Foundation
import FirebaseFirestore

class BarcodeDatabaseService {
    static let shared = BarcodeDatabaseService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func saveCustomBarcode(barcode: String, item: FoodItem) {
        let keywords = generateKeywords(from: item.name)
        
        let data: [String: Any] = [
            "barcode": barcode,
            "name": item.name,
            "calories": item.calories,
            "protein": item.protein,
            "fats": item.fats,
            "carbs": item.carbs,
            "weight": item.weight,
            "keywords": keywords,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("custom_barcodes").document(barcode).setData(data) { error in
            if let error = error {
                print("❌ Failed to save custom barcode \(barcode): \(error.localizedDescription)")
            } else {
                print("✅ Successfully saved custom barcode \(barcode) to Firestore.")
            }
        }
    }
    
    func fetchCustomBarcode(barcode: String) async -> FoodItem? {
        do {
            let doc = try await db.collection("custom_barcodes").document(barcode).getDocument()
            guard let data = doc.data(),
                  let name = data["name"] as? String,
                  let calories = data["calories"] as? Int,
                  let protein = data["protein"] as? Double,
                  let fats = data["fats"] as? Double,
                  let carbs = data["carbs"] as? Double else {
                return nil
            }
            let weight = data["weight"] as? Double ?? 100.0
            return FoodItem(name: name, weight: weight, calories: calories, protein: protein, fats: fats, carbs: carbs)
        } catch {
            print("⚠️ Error fetching custom barcode \(barcode): \(error.localizedDescription)")
            return nil
        }
    }
    
    func searchCustomBarcodesByText(query: String, limit: Int = 5) async -> [FoodItem] {
        let searchKeyword = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard searchKeyword.count >= 3 else { return [] }
        
        let firstWord = searchKeyword.components(separatedBy: .whitespaces).first ?? searchKeyword
        
        do {
            let snapshot = try await db.collection("custom_barcodes")
                .whereField("keywords", arrayContains: firstWord)
                .limit(to: limit)
                .getDocuments()
            
            var results: [FoodItem] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let calories = data["calories"] as? Int,
                      let protein = data["protein"] as? Double,
                      let fats = data["fats"] as? Double,
                      let carbs = data["carbs"] as? Double else {
                    continue
                }
                
                let weight = data["weight"] as? Double ?? 100.0
                results.append(FoodItem(name: name, weight: weight, calories: calories, protein: protein, fats: fats, carbs: carbs))
            }
            
            print("🌐 Firestore Custom Barcode Search for '\(firstWord)' found \(results.count) items.")
            return results
        } catch {
            print("⚠️ Error searching custom barcodes for \(query): \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - Global Community Foods
    
    /// Generates an array of lowercased words from a string for basic text search in Firestore
    func generateKeywords(from name: String) -> [String] {
        let cleanName = name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
        
        let words = cleanName.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var keywords = Set(words)
        
        // Add prefix subsets of each word (e.g., "apple" -> "app", "appl", "apple")
        // This makes basic partial matches work with array-contains
        for word in words {
            if word.count >= 3 {
                for i in 3...word.count {
                    let prefix = String(word.prefix(i))
                    keywords.insert(prefix)
                }
            }
        }
        
        return Array(keywords)
    }
    
    func saveCommunityFood(item: FoodItem) {
        let cleanName = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        
        // Create a predictable document ID to prevent duplicate spam
        // e.g., "apple_52" for an apple with 52 calories
        let docId = "\(cleanName.replacingOccurrences(of: " ", with: "_"))_\(item.calories)"
        
        let keywords = generateKeywords(from: item.name)
        
        let data: [String: Any] = [
            "name": item.name,
            "calories": item.calories,
            "protein": item.protein,
            "fats": item.fats,
            "carbs": item.carbs,
            "weight": item.weight,
            "keywords": keywords,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("global_community_foods").document(docId).setData(data, merge: true) { error in
            if let error = error {
                print("❌ Failed to save global community food \(item.name): \(error.localizedDescription)")
            } else {
                print("✅ Successfully saved global community food \(item.name) to Firestore.")
            }
        }
    }
    
    func searchCommunityFoods(query: String, limit: Int = 5) async -> [FoodItem] {
        let searchKeyword = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard searchKeyword.count >= 3 else { return [] } // Only search meaningful queries
        
        // Take the first main word of the query for array-contains searching
        let firstWord = searchKeyword.components(separatedBy: .whitespaces).first ?? searchKeyword
        
        do {
            let snapshot = try await db.collection("global_community_foods")
                .whereField("keywords", arrayContains: firstWord)
                .limit(to: limit)
                .getDocuments()
            
            var results: [FoodItem] = []
            
            for doc in snapshot.documents {
                let data = doc.data()
                guard let name = data["name"] as? String,
                      let calories = data["calories"] as? Int,
                      let protein = data["protein"] as? Double,
                      let fats = data["fats"] as? Double,
                      let carbs = data["carbs"] as? Double else {
                    continue
                }
                
                let weight = data["weight"] as? Double ?? 100.0
                results.append(FoodItem(name: name, weight: weight, calories: calories, protein: protein, fats: fats, carbs: carbs))
            }
            
            print("🌐 Firestore Community Search for '\(firstWord)' found \(results.count) items.")
            return results
        } catch {
            print("⚠️ Error searching global community foods for \(query): \(error.localizedDescription)")
            return []
        }
    }
    
    // MARK: - UGC Moderation (App Store Compliance)
    
    func blockCommunityFood(item: FoodItem) {
        let cleanName = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var blockedList = UserDefaults.standard.stringArray(forKey: "blockedCommunityFoods") ?? []
        if !blockedList.contains(cleanName) {
            blockedList.append(cleanName)
            UserDefaults.standard.set(blockedList, forKey: "blockedCommunityFoods")
        }
        print("🛑 Blocked community food: \(cleanName)")
    }
    
    func reportCommunityFood(item: FoodItem, reason: String) {
        let data: [String: Any] = [
            "foodName": item.name,
            "calories": item.calories,
            "reason": reason,
            "reportedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("reported_content").addDocument(data: data) { error in
            if let error = error {
                print("❌ Failed to report content: \(error.localizedDescription)")
            } else {
                print("✅ Content reported successfully.")
            }
        }
    }
}
