import Foundation
import HealthKit
import Observation
import SwiftData

enum HealthKitWeightSyncHelper {
    static func shouldImportHealthKitWeight(
        latestHKWeightKg: Double,
        currentUserWeightKg: Double,
        existingSameDayLogWeightKg: Double?,
        latestHKSampleDate: Date? = nil,
        latestLocalLogDate: Date? = nil
    ) -> Bool {
        guard latestHKWeightKg > 0 else { return false }
        if let latestHKSampleDate, let latestLocalLogDate, latestHKSampleDate < latestLocalLogDate {
            return false
        }
        if let existingSameDayLogWeightKg, abs(latestHKWeightKg - existingSameDayLogWeightKg) < 0.05 {
            return false
        }
        return abs(latestHKWeightKg - currentUserWeightKg) >= 0.05
    }
}

protocol HealthKitStoreExecuting: Sendable {
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus
    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws
    func save(_ object: HKObject) async throws
    func finishWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        calories: Int,
        metadata: [String: Any]
    ) async throws -> (workoutID: UUID, energySampleID: UUID?)
    func delete(_ object: HKObject) async throws
    func sumQuantity(for identifier: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> Double
    func fetchWorkouts(start: Date, end: Date) async throws -> [HKWorkout]
    func fetchLatestQuantitySample(for identifier: HKQuantityTypeIdentifier, since start: Date) async throws -> HKQuantitySample?
    func fetchSourceQuantitySamples(for identifier: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> [HKQuantitySample]
}

final class LiveHealthKitStore: HealthKitStoreExecuting, @unchecked Sendable {
    private let healthStore = HKHealthStore()

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        healthStore.authorizationStatus(for: type)
    }

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func save(_ object: HKObject) async throws {
        try await healthStore.save(object)
    }

    func finishWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        calories: Int,
        metadata: [String: Any]
    ) async throws -> (workoutID: UUID, energySampleID: UUID?) {
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: config, device: .local())
        try await builder.beginCollection(at: start)
        if !metadata.isEmpty {
            try await builder.addMetadata(metadata)
        }
        var energySampleID: UUID?
        if calories > 0, let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let energyBurned = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))
            let sample = HKQuantitySample(type: energyType, quantity: energyBurned, start: start, end: end)
            try await builder.addSamples([sample])
            energySampleID = sample.uuid
        }
        try await builder.endCollection(at: end)
        guard let workout = try await builder.finishWorkout() else {
            throw NSError(domain: HKErrorDomain, code: HKError.errorHealthDataUnavailable.rawValue)
        }
        return (workout.uuid, energySampleID)
    }

    func delete(_ object: HKObject) async throws {
        try await healthStore.delete(object)
    }

    func sumQuantity(for identifier: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> Double {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let samplePredicate = HKSamplePredicate.quantitySample(type: quantityType, predicate: predicate)
        let query = HKStatisticsQueryDescriptor(predicate: samplePredicate, options: .cumulativeSum)
        let result = try await query.result(for: healthStore)
        let unit: HKUnit = identifier == .stepCount ? .count() : .kilocalorie()
        return result?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor<HKWorkout>(
            predicates: [.workout(predicate)],
            sortDescriptors: []
        )
        return try await descriptor.result(for: healthStore)
    }

    func fetchLatestQuantitySample(for identifier: HKQuantityTypeIdentifier, since start: Date) async throws -> HKQuantitySample? {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return nil }
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: quantityType, predicate: datePredicate)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return try await descriptor.result(for: healthStore).first
    }

    func fetchSourceQuantitySamples(for identifier: HKQuantityTypeIdentifier, start: Date, end: Date) async throws -> [HKQuantitySample] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        let ownSourcePredicate = HKQuery.predicateForObjects(from: HKSource.default())
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let compound = NSCompoundPredicate(andPredicateWithSubpredicates: [ownSourcePredicate, datePredicate])
        let descriptor = HKSampleQueryDescriptor<HKQuantitySample>(
            predicates: [.quantitySample(type: quantityType, predicate: compound)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        return try await descriptor.result(for: healthStore)
    }
}

@Observable
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    nonisolated static let readTypeIdentifiers: [HKQuantityTypeIdentifier] = [
        .bodyMass,
        .stepCount,
        .activeEnergyBurned
    ]
    nonisolated static let writeTypeIdentifiers: [HKQuantityTypeIdentifier] = [
        .dietaryWater,
        .dietaryEnergyConsumed,
        .activeEnergyBurned,
        .bodyMass
    ]
    private let store: any HealthKitStoreExecuting
    private let isHealthDataAvailableProvider: @Sendable () -> Bool
    private let hasRequestedKey = "healthKitAuthRequested_v1"

    var isAuthorized: Bool = false

    private convenience init() {
        self.init(store: LiveHealthKitStore(), isAvailable: { HKHealthStore.isHealthDataAvailable() })
    }

    init(
        store: any HealthKitStoreExecuting,
        isAvailable: @escaping @Sendable () -> Bool = { HKHealthStore.isHealthDataAvailable() }
    ) {
        self.store = store
        self.isHealthDataAvailableProvider = isAvailable
        if isAvailable() {
            var writeTypes: [HKSampleType] = Self.writeTypeIdentifiers.compactMap {
                HKObjectType.quantityType(forIdentifier: $0)
            }
            writeTypes.append(HKObjectType.workoutType())
            let statuses = writeTypes.map { store.authorizationStatus(for: $0) }
            let anyAuthorized = statuses.contains(.sharingAuthorized)
            let anyAllowedAfterPrompt = UserDefaults.standard.bool(forKey: hasRequestedKey)
                && statuses.contains(where: { $0 != .sharingDenied && $0 != .notDetermined })
            self.isAuthorized = anyAuthorized || anyAllowedAfterPrompt
        }
    }

    private func canWrite(_ sampleType: HKObjectType) -> Bool {
        guard isHealthDataAvailableProvider() else { return false }
        return store.authorizationStatus(for: sampleType) == .sharingAuthorized
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailableProvider() else { return }

        var typesToRead: Set<HKObjectType> = Set(Self.readTypeIdentifiers.compactMap {
            HKObjectType.quantityType(forIdentifier: $0)
        })
        typesToRead.insert(HKObjectType.workoutType())

        var typesToWrite: Set<HKSampleType> = Set(Self.writeTypeIdentifiers.compactMap {
            HKObjectType.quantityType(forIdentifier: $0)
        })
        typesToWrite.insert(HKObjectType.workoutType())

        guard !typesToRead.isEmpty, !typesToWrite.isEmpty else { return }

        let hasRequested = UserDefaults.standard.bool(forKey: hasRequestedKey)
        // Only write types expose real authorizationStatus; prompt if never requested or any write type is still undetermined.
        let hasUndeterminedWriteType = typesToWrite.contains {
            store.authorizationStatus(for: $0) == .notDetermined
        }

        if !hasRequested || hasUndeterminedWriteType {
            try await store.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            UserDefaults.standard.set(true, forKey: hasRequestedKey)
        }

        let anyWriteAllowed = typesToWrite.contains {
            store.authorizationStatus(for: $0) != .sharingDenied
        }
        self.isAuthorized = anyWriteAllowed && UserDefaults.standard.bool(forKey: hasRequestedKey)
    }

    func resetAuthorizationState() {
        isAuthorized = false
        UserDefaults.standard.removeObject(forKey: hasRequestedKey)
    }

    // Modern async descriptor-based query (no legacy HKStatisticsQuery + continuation)
    func fetchSteps(for date: Date) async throws -> Int {
        guard isHealthDataAvailableProvider() else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }

        let steps = try await store.sumQuantity(for: .stepCount, start: startOfDay, end: endOfDay)
        return Int(steps)
    }

    @discardableResult
    func saveWater(liters: Double, date: Date) async -> UUID? {
        guard liters > 0,
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater),
              canWrite(waterType) else { return nil }

        let quantity = HKQuantity(unit: .liter(), doubleValue: liters)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date)

        do {
            try await store.save(sample)
            #if DEBUG
            print("Successfully saved \(liters)L of water to HealthKit")
            #endif
            return sample.uuid
        } catch {
            #if DEBUG
            print("Error saving water to HealthKit: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // Write dietary energy consumed synced from food logging
    @discardableResult
    func saveDietaryEnergy(calories: Int, date: Date) async -> UUID? {
        guard calories > 0,
              let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
              canWrite(energyType) else { return nil }

        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: Double(calories))
        let sample = HKQuantitySample(type: energyType, quantity: quantity, start: date, end: date)

        do {
            try await store.save(sample)
            #if DEBUG
            print("Saved \(calories) kcal dietary energy to HealthKit")
            #endif
            return sample.uuid
        } catch {
            #if DEBUG
            print("Error saving dietary energy: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    func deleteDietaryEnergySample(idString: String?, caloriesFallback: Int, date: Date) async {
        await deleteSourceQuantitySample(
            identifier: .dietaryEnergyConsumed,
            idString: idString,
            fallbackValue: Double(caloriesFallback),
            unit: .kilocalorie(),
            tolerance: 0.5,
            date: date
        )
    }

    func deleteWaterSample(idString: String?, litersFallback: Double, date: Date) async {
        guard idString?.hasPrefix("external:") != true else { return }
        await deleteSourceQuantitySample(
            identifier: .dietaryWater,
            idString: idString,
            fallbackValue: litersFallback,
            unit: .liter(),
            tolerance: 0.002,
            date: date
        )
    }

    func deleteBodyMassSample(idString: String?, kgFallback: Double, date: Date) async {
        await deleteSourceQuantitySample(
            identifier: .bodyMass,
            idString: idString,
            fallbackValue: kgFallback,
            unit: .gramUnit(with: .kilo),
            tolerance: 0.05,
            date: date
        )
    }

    func syncEditedDietaryEnergy(oldID: String?, oldCalories: Int, newCalories: Int, date: Date) async -> String? {
        guard oldCalories != newCalories else { return oldID }
        if oldID != nil || oldCalories > 0 {
            await deleteDietaryEnergySample(idString: oldID, caloriesFallback: oldCalories, date: date)
        }
        guard newCalories > 0 else { return nil }
        return await saveDietaryEnergy(calories: newCalories, date: date)?.uuidString
    }

    private func deleteSourceQuantitySample(
        identifier: HKQuantityTypeIdentifier,
        idString: String?,
        fallbackValue: Double,
        unit: HKUnit,
        tolerance: Double,
        date: Date
    ) async {
        guard isHealthDataAvailableProvider(),
              let quantityType = HKQuantityType.quantityType(forIdentifier: identifier),
              canWrite(quantityType) else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let samples = (try? await store.fetchSourceQuantitySamples(for: identifier, start: startOfDay, end: endOfDay)) ?? []

        if let idString, let uuid = UUID(uuidString: idString) {
            // When an exact HealthKit UUID is known, never fall through to value-based
            // fallback deletion — the target sample may already have been deleted in Apple Health.
            if let uuidMatch = samples.first(where: { $0.uuid == uuid }) {
                do {
                    try await store.delete(uuidMatch)
                } catch {
                    #if DEBUG
                    print("Error deleting HealthKit sample by UUID: \(error.localizedDescription)")
                    #endif
                }
            }
            return
        }

        guard fallbackValue > 0,
              let match = samples.first(where: { abs($0.quantity.doubleValue(for: unit) - fallbackValue) <= tolerance }) else {
            return
        }
        do {
            try await store.delete(match)
        } catch {
            #if DEBUG
            print("Error deleting fallback HealthKit sample: \(error.localizedDescription)")
            #endif
        }
    }

    nonisolated static func clampedWorkoutInterval(
        date: Date,
        durationMinutes: Int,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        let clampedMinutes = max(0, durationMinutes)
        let duration = TimeInterval(clampedMinutes * 60)
        let rawStart = date.addingTimeInterval(-duration)
        let startOfDay = calendar.startOfDay(for: date)
        let clampedStart = max(startOfDay, min(rawStart, date))
        return (clampedStart, date)
    }

    @discardableResult
    func saveWorkout(activityType: HKWorkoutActivityType, calories: Int, durationMinutes: Int, date: Date) async -> (workoutID: String?, energySampleID: String?) {
        guard calories > 0, durationMinutes > 0,
              canWrite(HKObjectType.workoutType()) else { return (nil, nil) }
        let interval = Self.clampedWorkoutInterval(date: date, durationMinutes: durationMinutes)
        let startDate = interval.start

        do {
            let result = try await store.finishWorkout(
                activityType: activityType,
                start: startDate,
                end: date,
                calories: calories,
                metadata: [HKMetadataKeyWorkoutBrandName: WorkoutSyncManager.healthKitBrandName]
            )
            #if DEBUG
            print("Successfully saved workout to HealthKit: \(calories) kcal for \(durationMinutes) min.")
            #endif
            return (result.workoutID.uuidString, result.energySampleID?.uuidString)
        } catch {
            #if DEBUG
            print("Error saving workout to HealthKit: \(error.localizedDescription)")
            #endif
            return (nil, nil)
        }
    }

    func deleteWorkoutAndEnergySamples(
        workoutID: String?,
        energySampleID: String?,
        caloriesFallback: Int,
        date: Date
    ) async {
        guard isHealthDataAvailableProvider() else { return }

        await deleteSourceQuantitySample(
            identifier: .activeEnergyBurned,
            idString: energySampleID,
            fallbackValue: Double(caloriesFallback),
            unit: .kilocalorie(),
            tolerance: 0.5,
            date: date
        )

        guard canWrite(HKObjectType.workoutType()) else { return }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let workouts = (try? await store.fetchWorkouts(start: startOfDay, end: endOfDay)) ?? []
        if let workoutID, let uuid = UUID(uuidString: workoutID) {
            if let uuidMatch = workouts.first(where: { $0.uuid == uuid }) {
                try? await store.delete(uuidMatch)
            }
            return
        }

        let fallbackMatch = workouts.first { workout in
            let brand = workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String
            guard brand == WorkoutSyncManager.healthKitBrandName else { return false }
            let kcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            return abs(kcal - Double(caloriesFallback)) <= 0.5
        }
        if let fallbackMatch {
            try? await store.delete(fallbackMatch)
        }
    }

    struct ExternalWorkoutCaloriesBreakdown: Equatable {
        let workoutTrackerCalories: Int
        let otherExternalCalories: Int
    }

    nonisolated static func isWorkoutTrackerWorkout(sourceBundleIdentifier: String?, brandName: String?) -> Bool {
        if brandName == WorkoutSyncManager.workoutTrackerBrandName {
            return true
        }
        guard let bundleID = sourceBundleIdentifier, !bundleID.isEmpty else { return false }
        return bundleID == "com.borisdev.WorkoutTracker"
            || bundleID.hasPrefix("com.borisdev.WorkoutTracker.")
    }

    /// Sums active calories from external HKWorkouts, separating WorkoutTracker entries
    /// from other external sources (e.g., Apple Watch) so neither is dropped nor double-counted.
    func fetchExternalWorkoutBreakdown(for date: Date) async throws -> ExternalWorkoutCaloriesBreakdown {
        guard isHealthDataAvailableProvider() else {
            return ExternalWorkoutCaloriesBreakdown(workoutTrackerCalories: 0, otherExternalCalories: 0)
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return ExternalWorkoutCaloriesBreakdown(workoutTrackerCalories: 0, otherExternalCalories: 0)
        }

        let workouts = try await store.fetchWorkouts(start: startOfDay, end: endOfDay)
        let ownBundleId = Bundle.main.bundleIdentifier
        var wtTotal = 0.0
        var otherTotal = 0.0

        for workout in workouts {
            let brandName = workout.metadata?[HKMetadataKeyWorkoutBrandName] as? String
            let isOwnBundle = ownBundleId != nil && workout.sourceRevision.source.bundleIdentifier == ownBundleId
            let isOwnBrand = brandName == WorkoutSyncManager.healthKitBrandName
            guard !isOwnBundle && !isOwnBrand else { continue }

            let kcal: Double
            if #available(iOS 18.0, *), let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                kcal = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie())
                    ?? workout.totalEnergyBurned?.doubleValue(for: .kilocalorie())
                    ?? 0.0
            } else {
                kcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0.0
            }

            if Self.isWorkoutTrackerWorkout(
                sourceBundleIdentifier: workout.sourceRevision.source.bundleIdentifier,
                brandName: brandName
            ) {
                wtTotal += kcal
            } else {
                otherTotal += kcal
            }
        }

        return ExternalWorkoutCaloriesBreakdown(
            workoutTrackerCalories: Int(wtTotal.rounded()),
            otherExternalCalories: Int(otherTotal.rounded())
        )
    }

    /// Sums active calories from external HKWorkouts (Apple Watch, WorkoutTracker, etc.),
    /// excluding workouts saved by FoodTracker itself to prevent double-counting.
    func fetchExternalWorkoutCalories(for date: Date) async throws -> Int {
        let breakdown = try await fetchExternalWorkoutBreakdown(for: date)
        return breakdown.workoutTrackerCalories + breakdown.otherExternalCalories
    }

    // Modern descriptor version
    func fetchTotalActiveCalories(for date: Date) async throws -> Int {
        guard isHealthDataAvailableProvider() else { return 0 }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return 0 }

        let kcal = try await store.sumQuantity(for: .activeEnergyBurned, start: startOfDay, end: endOfDay)
        return Int(kcal)
    }

    nonisolated static func bodyMassLookbackStartDate(
        from referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Date {
        calendar.date(byAdding: .day, value: -90, to: referenceDate)
            ?? referenceDate.addingTimeInterval(-90 * 86_400)
    }

    func fetchLatestBodyMassSample() async throws -> (kg: Double, date: Date)? {
        guard isHealthDataAvailableProvider() else { return nil }
        guard let latest = try await store.fetchLatestQuantitySample(
            for: .bodyMass,
            since: Self.bodyMassLookbackStartDate()
        ) else { return nil }
        let kg = latest.quantity.doubleValue(for: .gramUnit(with: .kilo))
        return kg > 0 ? (kg, latest.endDate) : nil
    }

    func fetchLatestBodyMassKg() async throws -> Double? {
        try await fetchLatestBodyMassSample()?.kg
    }

    @discardableResult
    func saveBodyMass(kg: Double, date: Date) async -> UUID? {
        guard kg > 0,
              let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass),
              canWrite(bodyMassType) else { return nil }

        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: date, end: date)
        do {
            try await store.save(sample)
            return sample.uuid
        } catch {
            #if DEBUG
            print("Error saving body mass to HealthKit: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}

extension WorkoutSyncManager {
    /// Centralizes HealthKit water sample deletions, partial-trim replacement writes, and new water saves.
    /// Kept in HealthKitManager.swift so `FoodTrackerWidgetExtension` (which links `WorkoutSyncManager`
    /// without `HealthKitManager`) compiles cleanly.
    func syncHealthKitWaterChanges(
        deletedSamples: [DeletedWaterHealthSample],
        newBeverage: Beverage? = nil,
        addedLiters: Double? = nil,
        logDate: Date,
        summaryDate: Date,
        summary: DailySummary,
        container: ModelContainer
    ) async {
        var needsSave = false
        for sample in deletedSamples {
            await HealthKitManager.shared.deleteWaterSample(
                idString: sample.sampleID,
                litersFallback: sample.volumeMl / 1000.0,
                date: summaryDate
            )
            if sample.replacementVolumeMl > 0,
               let uuid = await HealthKitManager.shared.saveWater(
                   liters: sample.replacementVolumeMl / 1000.0,
                   date: summaryDate
               ),
               let beverageID = sample.beverageID,
               let surviving = (summary.beverages ?? []).first(where: { $0.persistentModelID == beverageID }) {
                surviving.healthKitSampleID = uuid.uuidString
                needsSave = true
            }
        }
        if let newBeverage, let addedLiters, addedLiters > 0,
           let uuid = await HealthKitManager.shared.saveWater(liters: addedLiters, date: logDate) {
            newBeverage.healthKitSampleID = uuid.uuidString
            needsSave = true
        }
        if needsSave {
            try? container.mainContext.save()
        }
    }
}
