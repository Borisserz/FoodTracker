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
    var diets: [DietPlan] = DietDataLoader.defaultOfflineDiets()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private init() { fetchDiets() }

    deinit {
        listener?.remove()
    }

    static func defaultOfflineDiets() -> [DietPlan] {
        DietPlan.defaultDiets
    }

    func fetchDiets() {
        listener?.remove()
        listener = db.collection("diets").addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("❌ DietDataLoader error (using offline defaults): \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents, !documents.isEmpty else { return }
            let fetched = documents.compactMap { try? $0.data(as: DietPlan.self) }
            guard !fetched.isEmpty else { return }
            self?.diets = fetched
            print("✅ Загружено диет: \(fetched.count)")
        }
    }
}

@Observable
class FastingDataLoader {
    static let shared = FastingDataLoader()
    var plans: [FastingPlan] = FastingDataLoader.defaultOfflinePlans()
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private init() { fetchPlans() }

    deinit {
        listener?.remove()
    }

    static func defaultOfflinePlans() -> [FastingPlan] {
        FastingPlan.defaultPlans
    }

    func fetchPlans() {
        listener?.remove()
        // Сортируем по часам голодания (от простых к сложным)
        listener = db.collection("fasting_plans").order(by: "fastingHours").addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                print("❌ FastingDataLoader error (using offline defaults): \(error.localizedDescription)")
                return
            }
            guard let documents = snapshot?.documents, !documents.isEmpty else { return }
            let fetched = documents.compactMap { try? $0.data(as: FastingPlan.self) }
            guard !fetched.isEmpty else { return }
            self?.plans = fetched
            print("✅ Загружено планов голодания: \(fetched.count)")
        }
    }
}
