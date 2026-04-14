
import Foundation
import HealthKit
import Observation

@Observable final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    
    var isAuthorized: Bool = false
    
    // Запрос разрешений у пользователя
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device."])
        }
        
        guard let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
              let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let water = HKObjectType.quantityType(forIdentifier: .dietaryWater),
              let dietaryEnergy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            throw NSError(domain: "HealthKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Data types not available."])
        }
        
        let typesToRead: Set = [activeEnergy, bodyMass]
        let typesToWrite: Set = [water, dietaryEnergy]
        
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        
        // Переводим в главный поток для обновления UI
        await MainActor.run {
            self.isAuthorized = true
        }
    }
    
    // Получение сожженных калорий за день
    func fetchActiveEnergy(for date: Date) async throws -> Int {
        guard isAuthorized else { return 0 }
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: activeEnergyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                let calories = Int(sum.doubleValue(for: HKUnit.kilocalorie()))
                continuation.resume(returning: calories)
            }
            healthStore.execute(query)
        }
    }
    
    // Запись выпитой воды
    func saveWater(liters: Double, date: Date) {
        guard isAuthorized else { return }
        guard let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return }
        
        let quantity = HKQuantity(unit: HKUnit.liter(), doubleValue: liters)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)
        
        healthStore.save(sample) { success, error in
            if let error = error {
                print("Error saving water to HealthKit: \(error.localizedDescription)")
            } else {
                print("Successfully saved \(liters)L of water to HealthKit")
            }
        }
    }
}
