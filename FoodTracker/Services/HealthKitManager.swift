import Foundation
import HealthKit
import Observation

@Observable
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()
    private let hasRequestedKey = "healthKitAuthRequested_v1"

    var isAuthorized: Bool = false

    private init() {
        if HKHealthStore.isHealthDataAvailable(),
           let water = HKObjectType.quantityType(forIdentifier: .dietaryWater),
           let dietaryEnergy = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
           let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            let writeTypes: [HKSampleType] = [water, dietaryEnergy, activeEnergy, HKObjectType.workoutType()]
            let statuses = writeTypes.map { healthStore.authorizationStatus(for: $0) }
            let anyAuthorized = statuses.contains(.sharingAuthorized)
            let anyAllowedAfterPrompt = UserDefaults.standard.bool(forKey: hasRequestedKey)
                && statuses.contains(where: { $0 != .sharingDenied && $0 != .notDetermined })
            self.isAuthorized = anyAuthorized || anyAllowedAfterPrompt
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
        let typesToWrite: Set<HKSampleType> = [water, dietaryEnergy, activeEnergy, HKObjectType.workoutType()]

        let hasRequested = UserDefaults.standard.bool(forKey: hasRequestedKey)
        // Only write types expose real authorizationStatus; prompt if never requested or any write type is still undetermined.
        let hasUndeterminedWriteType = typesToWrite.contains {
            healthStore.authorizationStatus(for: $0) == .notDetermined
        }

        if !hasRequested || hasUndeterminedWriteType {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            UserDefaults.standard.set(true, forKey: hasRequestedKey)
        }

        let anyWriteAllowed = typesToWrite.contains {
            healthStore.authorizationStatus(for: $0) != .sharingDenied
        }
        self.isAuthorized = anyWriteAllowed && UserDefaults.standard.bool(forKey: hasRequestedKey)
    }

    func resetAuthorizationState() {
        isAuthorized = false
        UserDefaults.standard.removeObject(forKey: hasRequestedKey)
    }

    // Modern async descriptor-based query (no legacy HKStatisticsQuery + continuation)
    func fetchSteps(for date: Date) async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }

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
        let startDate = date.addingTimeInterval(-duration)
        let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))

        let workout = HKWorkout(
            activityType: activityType,
            start: startDate,
            end: date,
            duration: duration,
            totalEnergyBurned: energyBurned,
            totalDistance: nil,
            device: nil,
            metadata: [HKMetadataKeyWorkoutBrandName: WorkoutSyncManager.healthKitBrandName]
        )

        do {
            try await healthStore.save(workout)
            if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
               canWrite(energyType) {
                let sample = HKQuantitySample(type: energyType, quantity: energyBurned, start: startDate, end: date)
                try await healthStore.save(sample)
            }
            print("Successfully saved workout to HealthKit: \(calories) kcal for \(durationMinutes) min.")
        } catch {
            print("Error saving workout to HealthKit: \(error.localizedDescription)")
        }
    }

    /// Sums active calories from external HKWorkouts (Apple Watch, WorkoutTracker, etc.),
    /// excluding workouts saved by FoodTracker itself to prevent double-counting.
    func fetchExternalWorkoutCalories(for date: Date) async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor<HKWorkout>(
            predicates: [.workout(predicate)],
            sortDescriptors: []
        )

        let workouts = try await descriptor.result(for: healthStore)
        let ownBundleId = Bundle.main.bundleIdentifier
        let total = workouts.reduce(0.0) { sum, workout in
            let isOwnBundle = ownBundleId != nil && workout.sourceRevision.source.bundleIdentifier == ownBundleId
            let isOwnBrand = (workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String) == WorkoutSyncManager.healthKitBrandName
            guard !isOwnBundle && !isOwnBrand else { return sum }
            let kcal: Double
            if #available(iOS 18.0, *), let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                kcal = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
                    ?? workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                    ?? 0.0
            } else {
                kcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0.0
            }
            return sum + kcal
        }
        return Int(total.rounded())
    }

    // Modern descriptor version
    func fetchTotalActiveCalories(for date: Date) async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }

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
