import Foundation
import HealthKit
import Observation

@Observable final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    var isAuthorized: Bool = false

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        guard let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let water = HKObjectType.quantityType(forIdentifier: .dietaryWater),
              let dietaryEnergy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
              let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
              let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        else { return }

        let typesToRead: Set = [bodyMass, steps, activeEnergy]

        let typesToWrite: Set = [water, dietaryEnergy]

        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)

        await MainActor.run {
            self.isAuthorized = true
        }
    }

    func fetchSteps(for date: Date) async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let steps = Int(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0)
                continuation.resume(returning: steps)
            }
            healthStore.execute(query)
        }
    }
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

    func fetchTotalActiveCalories(for date: Date) async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        guard let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error); return
                }

                let totalKcal = result?.sumQuantity()?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                continuation.resume(returning: Int(totalKcal))
            }
            healthStore.execute(query)
        }
    }
}
