import Foundation
import HealthKit
import Observation

@Observable final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private let hasRequestedKey = "healthKitAuthRequested_v1"

    var isAuthorized: Bool = false

    private init() {
        if HKHealthStore.isHealthDataAvailable(),
           let water = HKObjectType.quantityType(forIdentifier: .dietaryWater) {
            let status = healthStore.authorizationStatus(for: water)
            self.isAuthorized = (status == .sharingAuthorized) ||
                (status != .sharingDenied && UserDefaults.standard.bool(forKey: hasRequestedKey))
        }
    }

    private func canWrite(_ sampleType: HKObjectType) -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let status = healthStore.authorizationStatus(for: sampleType)
        if status == .sharingAuthorized { return true }
        return status != .sharingDenied && isAuthorized
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        guard let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let water = HKObjectType.quantityType(forIdentifier: .dietaryWater),
              let dietaryEnergy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
              let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
              let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        else { return }

        let typesToRead: Set<HKObjectType> = [bodyMass, steps, activeEnergy, HKObjectType.workoutType()]
        let typesToWrite: Set<HKSampleType> = [water, dietaryEnergy, HKObjectType.workoutType()]

        let hasRequested = UserDefaults.standard.bool(forKey: hasRequestedKey)
        // Only write types expose real authorizationStatus; read types (.stepCount) always report .notDetermined.
        let waterWriteStatus = healthStore.authorizationStatus(for: water)

        if !hasRequested || waterWriteStatus == .notDetermined {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            UserDefaults.standard.set(true, forKey: hasRequestedKey)
        }

        let anyWriteAllowed = [water, dietaryEnergy, HKObjectType.workoutType()].contains {
            healthStore.authorizationStatus(for: $0) != .sharingDenied
        }
        await MainActor.run {
            self.isAuthorized = anyWriteAllowed && UserDefaults.standard.bool(forKey: hasRequestedKey)
        }
    }

    // Modern async descriptor-based query (no legacy HKStatisticsQuery + continuation)
    func fetchSteps(for date: Date) async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: stepsType, predicate: predicate)

        let query = HKStatisticsQueryDescriptor(
            predicate: samplePredicate,
            options: .cumulativeSum
        )

        let result = try await query.result(for: healthStore)
        return Int(result?.sumQuantity()?.doubleValue(for: .count()) ?? 0)
    }

    func saveWater(liters: Double, date: Date) async {
        guard liters > 0,
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater),
              canWrite(waterType) else { return }

        let quantity = HKQuantity(unit: .liter(), doubleValue: liters)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)

        do {
            try await healthStore.save(sample)
            print("Successfully saved \(liters)L of water to HealthKit")
        } catch {
            print("Error saving water to HealthKit: \(error.localizedDescription)")
        }
    }

    // Write dietary energy consumed synced from food logging
    func saveDietaryEnergy(calories: Int, date: Date) async {
        guard calories > 0,
              let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
              canWrite(energyType) else { return }

        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))
        let sample = HKQuantitySample(type: energyType, quantity: quantity, start: date, end: date)

        do {
            try await healthStore.save(sample)
            print("Saved \(calories) kcal dietary energy to HealthKit")
        } catch {
            print("Error saving dietary energy: \(error.localizedDescription)")
        }
    }

    func saveWorkout(activityType: HKWorkoutActivityType, calories: Int, durationMinutes: Int, date: Date) async {
        guard calories > 0, durationMinutes > 0,
              canWrite(HKObjectType.workoutType()) else { return }
        let duration = TimeInterval(durationMinutes * 60)
        let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))

        // Ensure HealthKit handles standard workouts without issue.
        let workout = HKWorkout(
            activityType: activityType,
            start: date.addingTimeInterval(-duration),
            end: date,
            duration: duration,
            totalEnergyBurned: energyBurned,
            totalDistance: nil,
            device: nil,
            metadata: nil
        )

        do {
            try await healthStore.save(workout)
            print("Successfully saved workout to HealthKit: \(calories) kcal for \(durationMinutes) min.")
        } catch {
            print("Error saving workout to HealthKit: \(error.localizedDescription)")
        }
    }

    // Modern descriptor version
    func fetchTotalActiveCalories(for date: Date) async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: energyType, predicate: predicate)

        let query = HKStatisticsQueryDescriptor(
            predicate: samplePredicate,
            options: .cumulativeSum
        )

        let result = try await query.result(for: healthStore)
        return Int(result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
    }

    // Background delivery stub (per healthkit skill). Call once at launch if desired.
    // Requires "Background Delivery" capability + proper observer query handling + app launch handling.
    func enableBackgroundDeliveryIfPossible() async {
        // Example (uncomment + implement observer when ready):
        // try? await healthStore.enableBackgroundDelivery(for: HKQuantityType(.stepCount), frequency: .hourly)
        // Similar for activeEnergyBurned.
        // Then register HKObserverQuery in AppDelegate or on launch.
        print("HealthKit background delivery not yet enabled (add capability + observer query to activate).")
    }
}
