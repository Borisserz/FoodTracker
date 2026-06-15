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

        let typesToRead: Set<HKObjectType> = [bodyMass, steps, activeEnergy, HKObjectType.workoutType()]
        let typesToWrite: Set<HKSampleType> = [water, dietaryEnergy, HKObjectType.workoutType()]

        // Check current status before requesting (don't over-request; respect denial)
        let status = healthStore.authorizationStatus(for: steps)
        if status == .notDetermined {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        }

        // Re-check after possible prompt
        let newStatus = healthStore.authorizationStatus(for: steps)
        await MainActor.run {
            // .sharingAuthorized for write; for read we treat notDenied as usable (read denial is opaque)
            self.isAuthorized = (newStatus != .sharingDenied)
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
        guard isAuthorized else { return }
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }

        let quantity = HKQuantity(unit: .liter(), doubleValue: liters)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)

        do {
            try await healthStore.save(sample)
            print("Successfully saved \(liters)L of water to HealthKit")
        } catch {
            print("Error saving water to HealthKit: \(error.localizedDescription)")
        }
    }

    // New: write dietary energy consumed (previously declared in Info/entitlements but never implemented)
    func saveDietaryEnergy(calories: Int, date: Date) async {
        guard isAuthorized else { return }
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else { return }

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
        guard isAuthorized else { return }
        let duration = TimeInterval(durationMinutes * 60)
        let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))

        // Ensure HealthKit handles standard workouts without issue.
        let workout = HKWorkout(
            activityType: activityType,
            start: date.addingTimeInterval(-duration),
            end: date,
            workoutEvents: nil,
            totalEnergyBurned: energyBurned,
            totalDistance: nil,
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
