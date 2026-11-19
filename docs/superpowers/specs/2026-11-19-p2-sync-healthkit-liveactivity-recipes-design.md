# FoodTracker Point 2 — Sync, HealthKit, Live Activity, Auth & Recipes Design

**Date:** 2026-11-19
**Scope:** Critical data-integrity, synchronization, concurrency, Live Activity, and localization fixes in `FoodTracker` (without modifying `WorkoutTracker`).

## Goals

1. **Workout / Activity Burn Accuracy (`QuickActivityAddView`, `WorkoutSyncManager`, `HealthKitManager`):** Eliminate double-counting when logging local activities and stop dropping non-WorkoutTracker Apple Watch workouts when WorkoutTracker App Group calories exist.
2. **Bidirectional HealthKit & Widget Water Sync (`DataModels`, `HealthKitManager`, `WidgetIntents`, `FoodTrackerWidget.entitlements`, Views):** Track per-item HealthKit sample IDs (`healthKitSampleID`) on `FoodItem` and `Beverage` so deleting/editing food or undoing water updates Apple Health accurately without removing external apps' entries, and sync widget-logged water to both `WorkoutTracker` App Group and Apple Health.
3. **Auth Concurrency Hardening (`AnonymousAuthBootstrap`, `SocialAuthService`):** Replace the fragile integer counter with race-proof UUID leases + early-end tombstones so out-of-order unstructured `Task` scheduling can never deadlock `ensureSignedIn()`.
4. **Fasting Live Activity Completion & Overtime (`FastingAttributes`, `FastingLiveActivityManager`, `FastingActivityWidget`, `AppStateManager`):** Ensure the Live Activity reliably transitions from countdown to `"Done"` at `targetEndDate` (both foreground and background) and opens the fasting dashboard on tap (`foodtracker://fasting`).
5. **Localized Recipe Discovery & Search Completeness (`ChefRecipesView`, `RecipeTagCatalog`, `DailyLogDetailView`, `LocalFoodDatabaseService`):** Canonicalize localized recipe tags across all 7 languages so Discover sections and filters work globally, delete empty parent `Meal` rows in `DailyLogDetailView`, and supplement sparse `pt-PT` food searches from `foods_en` up to the requested result limit.

---

## Architecture & Component Design

### 1. Activity Burn & `WorkoutTracker` / Apple Watch Merge

- **`WorkoutSyncManager.swift`:**
  - Replace non-thread-safe `static let dayFormatter: DateFormatter` with pure `Calendar(identifier: .gregorian)` year/month/day formatting (`"%04d-%02d-%02d"`), making `dateString(for:)` strictly thread-safe.
  - Add `nonisolated static let workoutTrackerBrandName = "AI Workout"`.
  - Extend `computeDailyBurn`:
    ```swift
    nonisolated static func computeDailyBurn(
        localActivityCalories: Int,
        workoutTrackerCalories: Int,
        healthKitWorkoutCalories: Int,
        otherExternalWorkoutCalories: Int = 0,
        healthKitTotalActiveCalories: Int,
        stepsCount: Int,
        isHealthKitEnabled: Bool
    ) -> (workoutCalories: Int, activeCaloriesBurned: Int, stepsCount: Int)
    ```
    where `externalWorkouts = max(0, max(workoutTrackerCalories, healthKitWorkoutCalories)) + max(0, otherExternalWorkoutCalories)` and `totalWorkouts = max(0, localActivityCalories) + externalWorkouts`.
  - Add `static func pendingHealthKitWaterKey(for date: Date) -> String` in `group.com.borisdev.FoodTracker2026` (`"pending_hk_water_ml_yyyy-MM-dd"`) plus `recordPendingWidgetWater(ml:for:)` / `consumePendingWidgetWaterLiters(for:)`, and `syncWaterFromWidget(totalLiters:addedMl:for:)` so widget water updates `WorkoutTracker` App Group AND queues only the widget-added delta for Apple Health flush when the main app syncs (preventing double-writing water added by `WorkoutTracker`).
- **`HealthKitManager.swift`:**
  - Add `struct ExternalWorkoutCaloriesBreakdown: Equatable { let workoutTrackerCalories: Int; let otherExternalCalories: Int }`.
  - Implement `fetchExternalWorkoutBreakdown(for date: Date) async throws -> ExternalWorkoutCaloriesBreakdown`, excluding `FoodTracker` (`ownBundleId` or brand `"FoodTracker"`), bucketing `HKMetadataKeyWorkoutBrandName == "AI Workout"` into `workoutTrackerCalories`, and all other workouts (Apple Watch, Fitness+, etc.) into `otherExternalCalories`. Keep `fetchExternalWorkoutCalories(for:)` returning `workoutTrackerCalories + otherExternalCalories`.
- **`QuickActivityAddView.swift`:**
  - In `saveActivity()`, capture `let previousLocalCals = targetSummary.localActivityCalories` *before* calling `targetSummary.addActivity(log)`, and pass `max(0, targetSummary.workoutCalories - previousLocalCals)` as `healthKitWorkoutCalories:` (with `otherExternalWorkoutCalories: 0`) so previously logged local activities are never counted twice.
- **`HomeDashboardView.swift` (`fetchHealthData`):**
  - Fetch `ExternalWorkoutCaloriesBreakdown` and pass `workoutTrackerCalories: wtAppGroupCals`, `healthKitWorkoutCalories: breakdown.workoutTrackerCalories`, `otherExternalWorkoutCalories: breakdown.otherExternalCalories` into `WorkoutSyncManager.computeDailyBurn`.
  - When `isHKEnabled`, flush any `consumePendingWidgetWaterLiters(for: targetDate)` to `HealthKitManager.shared.saveWater(...)` after `reconcileWater`.

### 2. HealthKit Delete / Downward-Edit Sync & Widget Entitlements

- **SwiftData Models (`FoodTracker/Models/DataModels.swift`):**
  - Add `var healthKitSampleID: String? = nil` to `FoodItem` and `Beverage` (CloudKit-compatible optional with default `nil`).
- **`HealthKitManager.swift`:**
  - Mark `saveWater(liters:date:) async -> UUID?` and `saveDietaryEnergy(calories:date:) async -> UUID?` with `@discardableResult` so callers can store `uuid.uuidString` on `FoodItem`/`Beverage`.
  - Add `deleteDietaryEnergySample(idString: String?, caloriesFallback: Int, date: Date) async` and `deleteWaterSample(idString: String?, litersFallback: Double, date: Date) async`:
    - First attempts exact deletion via `HKQuery.predicateForObject(with: uuid)` scoped to `HKSource.default()`.
    - If `idString == nil` (legacy items) or no match, queries `HKSource.default()` samples on `[startOfDay, endOfDay)` sorted descending by `startDate`, finds the most recent sample matching the fallback value within tolerance (`0.5` kcal / `0.001` L), and deletes that single sample.
  - Add `syncEditedDietaryEnergy(oldID: String?, oldCalories: Int, newCalories: Int, date: Date) async -> String?`:
    - If `oldCalories == newCalories`, keeps `oldID` untouched.
    - Otherwise deletes the old sample (if `oldID != nil` or `oldCalories > 0`) and, if `newCalories > 0`, saves a new sample and returns its `UUID.uuidString`.
- **Call Sites:**
  - Wire `healthKitSampleID` capture and deletion/edit sync across `HomeDashboardView` (`addFoodsToMeal`, `MealDetailView.deleteFoodItem`, `MealDetailView` edit callback, `DailyLogDetailView.deleteFoodItem`), `HistoryView.deleteMeal`, `AddMealView` (`MealSlotPersistence.persist` capturing `oldCalories` and `oldSampleID` *before* `draft.apply(to:)` and returning structured `PersistenceResult` with `insertedItems`, `updatedItems`, `deletedSamples`), `HydrationFlaskCardView` (`addWater` / `removeLastWaterEntry`), `AnalyticsDashboardView` (`addWaterVolume` / `removeLastWater`), `AICoachDashboardView.logQuickWaterGlass`, `AIChefStudioView.logRecipeToToday`, `CreateRecipeView.saveToDiary`, `WeeklyPlanOverview.applyToToday`, `ChefRecipesView.saveToDiary`, and `PremiumQuickAddSheet.saveQuickCalories`.
  - In `DailyLogDetailView.deleteFoodItem`, also delete the parent `Meal` when `(meal.foodItems ?? []).isEmpty`.
- **Widget Entitlements & Intent (`FoodTrackerWidgetExtension/`):**
  - Add `"group.com.borisdev.WorkoutTracker"` to `FoodTrackerWidgetExtension/FoodTrackerWidget.entitlements`.
  - Include `WorkoutSyncManager.swift` in `FoodTrackerWidgetExtension` target sources (`project.pbxproj`) so `WorkoutSyncManager` remains the single source of truth for App Group keys.
  - In `AddWaterIntent.perform()`, compute updated `summary.totalHydrationLiters` and call `WorkoutSyncManager.shared.syncWaterFromWidget(totalLiters:addedMl:for:)` so `WorkoutTracker` sees widget water immediately and `FoodTracker` flushes the HealthKit sample on next active sync.

### 3. `AnonymousAuthBootstrap` Lease Hardening

- **`FoodTracker/Auth/AnonymousAuthBootstrap.swift`:**
  - Replace `interactiveSignInCount: Int` with `activeInteractiveLeases: Set<UUID>` and `endedEarlyLeases: Set<UUID>`.
  - `beginInteractiveSignIn(id: UUID = UUID()) -> UUID`: if `endedEarlyLeases.remove(id) != nil`, skips adding to `activeInteractiveLeases`; otherwise inserts `id`, bumps `inFlightGeneration`, and cancels any pending anonymous `inFlightTask`.
  - `endInteractiveSignIn(_ id: UUID)`: if `activeInteractiveLeases.remove(id) == nil`, inserts `id` into `endedEarlyLeases` (capped/pruned if needed) so a late `begin` cannot leak.
  - `ensureSignedIn()` waits while `!activeInteractiveLeases.isEmpty` with a bounded wait (`maxInteractiveWaitCycles`, returning/throwing if exceeded or cancelled) and checks `Auth.auth().currentUser` on each cycle.
- **`FoodTracker/Auth/SocialAuthService.swift`:**
  - Generate lease `UUID` synchronously before spawning unstructured `Task`s in `prepareAppleRequest` / `handleAppleAuthorization`, and acquire/release explicit `UUID` leases in `signInWithApple()` and `signInWithGoogle()`.

### 4. Fasting Live Activity Completion, Overtime & Deep Link

- **`FoodTracker/Models/LiveActivities/FastingAttributes.swift`:**
  - Add `public var isCompleted: Bool` (default `false`, decoded via `decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false` for backward compatibility with active pre-update Live Activities).
  - Add `FastingActivityTiming.isCompleted(now:targetEndDate:progressPct:) -> Bool`.
- **`FoodTracker/Services/FastingLiveActivityManager.swift`:**
  - Track `lastSentCompleted: Bool`.
  - Extract pure testable `FastingLiveActivityUpdateDecision.shouldDispatch(...)`: returns `true` whenever `isCompleted != lastSentCompleted`, `currentStage != lastSentStage`, or `abs(progressPct - lastSentProgress) >= 0.01`.
  - Update `staleDate` when `!isCompleted` to `targetEndDate` (so iOS wakes the widget extension at `targetEndDate` to render `"Done"` even if app is suspended), and when `isCompleted` to `Date().addingTimeInterval(3600)` (so active overtime Live Activity stays fresh in foreground).
- **`FoodTrackerWidgets/FastingActivityWidget.swift` & Deep Link:**
  - Update `FastingCountdownText(targetEndDate:isCompleted:isStale:)` to render `"Done"` when `isCompleted || isStale || FastingActivityTiming.remainingInterval(...) == nil`.
  - Add `.widgetURL(URL(string: "foodtracker://fasting"))` to `LockScreenFastingView` and `DynamicIsland`, handle `"fasting"` in `AppStateManager.handleWidgetURL(_:)`, and present `FastingDashboardView` sheet in `FoodTrackerApp.swift` (`ContentView`).

### 5. Localized Recipe Tags & Sparse `pt-PT` Food Search

- **`FoodTracker/Services/RecipeTagCatalog.swift`:**
  - Pure mapping from every localized tag variant across all 7 languages (`en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`) to the 15 canonical English tag identifiers (`Breakfast`, `Lunch`, `Dinner`, `Snack`, `Smoothie`, `Quickly Prepared`, `On the Go`, `Few Ingredients`, `Baking`, `Easy`, `Vegetarian`, `Vegan`, `Low Carb`, `High Protein`, `Ketogenic`).
  - Update `ChefRecipesView.swift` (`DiscoverSections.partition`, `openFiltered`, `AdvancedRecipeFilterSheet`) to compare via `RecipeTagCatalog.canonicalTag(for:)` while displaying localized labels (`String(localized:)`).
- **`FoodTracker/Services/LocalFoodDatabaseService.swift`:**
  - Update `search(query:limit:)` (and a testable `searchEntries(primary:fallback:query:limit:primaryLang:)` helper) so non-English locales supplement results with English fallback whenever `results.count < limit` (instead of `< 3`), deduplicating case-insensitively while keeping primary-language hits ranked first.

---

## Testing Scope (TDD)

- `WorkoutSyncManagerTests`: non-double-counting with `previousLocalCals`, Watch + WorkoutTracker split (`max(wt, wtHK) + otherHK`), thread-safe `dateString`, widget water pending HealthKit delta flush.
- `AnonymousAuthBootstrapTests`: out-of-order `endInteractiveSignIn` before `beginInteractiveSignIn` never leaks or deadlocks, balanced leases clear properly.
- `FastingManagerTests`: `FastingActivityTiming.isCompleted`, `FastingAttributes.ContentState` backward-compatible decoding without `isCompleted`, `FastingLiveActivityUpdateDecision` forces dispatch when `isCompleted` flips at `progress == 1.0`, `AppStateManager.handleWidgetURL("foodtracker://fasting")`.
- `RecipeTagCatalogTests`: verifies all tags from all 7 `recipes*.json` files map cleanly to the 15 canonical tags and `DiscoverSections` partitions localized recipes identically to English.
- `LocalFoodDatabaseServiceTests`: verifies `pt-PT` search supplements from `foods_en` up to `limit` without duplicates even when `pt-PT` returns `>= 3` hits.
- `HealthKitManagerTests` / `DataModelsTests`: `MealSlotPersistence.persist` delta/removal/edit tracking, `DailyLogDetailView` empty meal cleanup helper, `FoodItem`/`Beverage` `healthKitSampleID` persistence.
