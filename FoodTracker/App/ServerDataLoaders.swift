//
//  ServerDataLoaders.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 26.04.26.
//

import Foundation
import SwiftUI
import Observation
import FirebaseFirestore

@Observable
class DietDataLoader {
    static let shared = DietDataLoader()
    var diets: [DietPlan] = []
    private let db = Firestore.firestore()
    
    private init() { fetchDiets() }
    
    func fetchDiets() {
        db.collection("diets").addSnapshotListener { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else { return }
            self?.diets = documents.compactMap { try? $0.data(as: DietPlan.self) }
            print("✅ Загружено диет: \(self?.diets.count ?? 0)")
        }
    }
}

@Observable
class FastingDataLoader {
    static let shared = FastingDataLoader()
    var plans: [FastingPlan] = []
    private let db = Firestore.firestore()
    
    private init() { fetchPlans() }
    
    func fetchPlans() {
        // Сортируем по часам голодания (от простых к сложным)
        db.collection("fasting_plans").order(by: "fastingHours").addSnapshotListener { [weak self] snapshot, error in
            guard let documents = snapshot?.documents else { return }
            self?.plans = documents.compactMap { try? $0.data(as: FastingPlan.self) }
            print("✅ Загружено планов голодания: \(self?.plans.count ?? 0)")
        }
    }
}
