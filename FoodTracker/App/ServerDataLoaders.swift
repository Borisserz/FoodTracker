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

    static func shouldPreferRemoteCatalog(languageCode: String? = Locale.current.language.languageCode?.identifier) -> Bool {
        (languageCode ?? "en").lowercased() == "en"
    }

    func fetchDiets() {
        guard Self.shouldPreferRemoteCatalog() || diets.isEmpty else { return }
        listener?.remove()
        listener = db.collection("diets").addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                #if DEBUG
                print("❌ DietDataLoader error (using offline defaults): \(error.localizedDescription)")
                #endif
                return
            }
            guard let documents = snapshot?.documents, !documents.isEmpty else { return }
            let fetched = documents.compactMap { try? $0.data(as: DietPlan.self) }
            guard !fetched.isEmpty else { return }
            DispatchQueue.main.async {
                self?.diets = fetched
                #if DEBUG
                print("✅ Загружено диет: \(fetched.count)")
                #endif
            }
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

    static func shouldPreferRemoteCatalog(languageCode: String? = Locale.current.language.languageCode?.identifier) -> Bool {
        (languageCode ?? "en").lowercased() == "en"
    }

    func fetchPlans() {
        guard Self.shouldPreferRemoteCatalog() || plans.isEmpty else { return }
        listener?.remove()
        // Сортируем по часам голодания (от простых к сложным)
        listener = db.collection("fasting_plans").order(by: "fastingHours").addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                #if DEBUG
                print("❌ FastingDataLoader error (using offline defaults): \(error.localizedDescription)")
                #endif
                return
            }
            guard let documents = snapshot?.documents, !documents.isEmpty else { return }
            let fetched = documents.compactMap { try? $0.data(as: FastingPlan.self) }
            guard !fetched.isEmpty else { return }
            DispatchQueue.main.async {
                self?.plans = fetched
                #if DEBUG
                print("✅ Загружено планов голодания: \(fetched.count)")
                #endif
            }
        }
    }
}
