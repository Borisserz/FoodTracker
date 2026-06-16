import Foundation
import FirebaseFirestore

class BarcodeDatabaseService {
    static let shared = BarcodeDatabaseService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func saveCustomBarcode(barcode: String, item: FoodItem) {
        let data: [String: Any] = [
            "barcode": barcode,
            "name": item.name,
            "calories": item.calories,
            "protein": item.protein,
            "fats": item.fats,
            "carbs": item.carbs,
            "weight": item.weight,
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
}
