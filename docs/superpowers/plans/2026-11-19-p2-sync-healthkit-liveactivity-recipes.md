# FoodTracker Point 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix activity burn double-counting & Watch/WorkoutTracker merge, per-item HealthKit delete/edit & widget water sync, `AnonymousAuthBootstrap` task-reordering race, Fasting Live Activity completion/deep-link, localized `ChefRecipesView` tags, `DailyLogDetailView` empty meal cleanup, and sparse `pt-PT` food search.

**Architecture:** Five cohesive workstreams built test-first: pure/injectable logic helpers (`WorkoutSyncManager`, `AnonymousAuthBootstrap`, `FastingLiveActivityUpdateDecision`, `RecipeTagCatalog`, `LocalFoodDatabaseService.searchEntries`, `MealSlotPersistence.persistWithSyncOps`) paired with SwiftData model tracking (`healthKitSampleID`), WidgetExtension App Group sync, and SwiftUI view wiring.

**Tech Stack:** Swift 5 / SwiftUI / SwiftData / ActivityKit / HealthKit / XCTest (`FoodTrackerTests`, `FoodTrackerUITests`).

## Global Constraints

- Do NOT modify `WorkoutTracker` repository files.
- Keep `WorkoutSyncManager.swift` free of UIKit/App-only imports so it compiles cleanly in both `FoodTracker` and `FoodTrackerWidgetExtension`.
- Keep new SwiftData fields optional with `= nil` default for CloudKit lightweight migration safety.
- Follow TDD strictly: failing test -> verify failure -> minimal implementation -> verify pass.

---

### Task 1: Activity Burn Double-Count Fix, Watch/WorkoutTracker Split & Widget Water Sync

**Files:**
- Modify: `FoodTracker/Services/WorkoutSyncManager.swift`
- Modify: `FoodTracker/Services/HealthKitManager.swift`
- Modify: `FoodTracker/Views/Components/QuickActivityAddView.swift:156-207`
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift:389-447`
- Modify: `FoodTrackerWidgetExtension/FoodTrackerWidget.entitlements`
- Modify: `FoodTrackerWidgetExtension/WidgetIntents.swift:12-27`
- Modify: `FoodTracker.xcodeproj/project.pbxproj` (add `WorkoutSyncManager.swift` to `FoodTrackerWidgetExtension` target sources)
- Modify: `FoodTrackerTests/DataModelsTests.swift`

- [ ] **Step 1: Add failing tests in `DataModelsTests.swift`** for:
  - `QuickActivityReconciliationHelper.priorExternalWorkoutCalories(totalWorkoutCalories:previousLocalActivityCalories:)` (verifying adding a second local activity does NOT double-count the first).
  - `WorkoutSyncManager.computeDailyBurn` with `otherExternalWorkoutCalories` (Apple Watch 300 + WorkoutTracker 400 = 700 external + 150 local = 850).
  - `WorkoutSyncManager.syncWaterFromWidget` + `consumePendingWidgetWaterLiters` (updates shared WorkoutTracker defaults AND accumulates widget delta without touching unrelated dates).
- [ ] **Step 2: Run tests to verify RED**.
- [ ] **Step 3: Implement** thread-safe `WorkoutSyncManager.dateString(for:)`, `otherExternalWorkoutCalories`, `pendingHealthKitWaterKey` / `syncWaterFromWidget` / `consumePendingWidgetWaterLiters`, `HealthKitManager.fetchExternalWorkoutBreakdown`, `QuickActivityAddView` fix, `HomeDashboardView.fetchHealthData` flush, `FoodTrackerWidget.entitlements` + `WidgetIntents.swift` + `project.pbxproj`.
- [ ] **Step 4: Run tests to verify GREEN**.

---

### Task 2: HealthKit Sample Tracking & Delete/Downward-Edit Sync + Empty Meal Cleanup

**Files:**
- Modify: `FoodTracker/Models/DataModels.swift:174-224` (`Beverage.healthKitSampleID`, `FoodItem.healthKitSampleID`)
- Modify: `FoodTracker/Services/HealthKitManager.swift` (returning `UUID?` from `saveWater`/`saveDietaryEnergy`, adding `deleteDietaryEnergySample`, `deleteWaterSample`, `syncEditedDietaryEnergy`)
- Modify: `FoodTracker/Views/AddMealView.swift` (`MealSlotPersistence.persistWithSyncOps` capturing `oldCalories`/`oldSampleID` before `draft.apply(to:)`)
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift` (`addFoodsToMeal`, `MealDetailView.deleteFoodItem`, `MealDetailView` edit callback, `DailyLogDetailView.deleteFoodItem` deleting empty `Meal` + HK sync)
- Modify: `FoodTracker/Views/History/HistoryView.swift:182-188` (`deleteMeal`)
- Modify: `FoodTracker/Views/Components/Motion/HydrationFlaskCardView.swift:182-225`
- Modify: `FoodTracker/Views/Profile/AnalyticsDashboardView.swift:778-818`
- Modify: `FoodTracker/AI/AICoachDashboardView.swift:201-217`
- Modify: `FoodTracker/App/AIChefStudioView.swift:976-1009`
- Modify: `FoodTracker/Views/CreateRecipeView.swift:1138-1160`
- Modify: `FoodTracker/Views/SmartBuilder/WeeklyPlanOverview.swift:170-204`
- Modify: `FoodTracker/Views/Chefs/ChefRecipesView.swift:1314-1335`
- Modify: `FoodTracker/Views/Components/PremiumQuickAddSheet.swift:186-214`
- Modify: `FoodTrackerTests/DataModelsTests.swift`

- [ ] **Step 1: Add failing tests in `DataModelsTests.swift`** for `MealSlotPersistence.persistWithSyncOps` (recording inserted items, calorie-edited items with pre-mutation `oldCalories` & `oldSampleID`, and deleted items/slots) and `DailyLogDetailView` empty meal cleanup helper (`DailySummary.removeFoodItemAndCleanupEmptyMeal` or similar).
- [ ] **Step 2: Run tests to verify RED**.
- [ ] **Step 3: Implement** `healthKitSampleID` on `FoodItem` and `Beverage`, `HealthKitManager` delete/edit methods, `MealSlotPersistence.persistWithSyncOps`, and wire all food/water add/edit/delete sites.
- [ ] **Step 4: Run tests to verify GREEN**.

---

### Task 3: `AnonymousAuthBootstrap` Lease-Based Race Elimination

**Files:**
- Modify: `FoodTracker/Auth/AnonymousAuthBootstrap.swift`
- Modify: `FoodTracker/Auth/SocialAuthService.swift:22-128`
- Modify: `FoodTrackerTests/SocialAuthServiceTests.swift`

- [ ] **Step 1: Add failing tests in `SocialAuthServiceTests.swift`** exercising `AnonymousAuthBootstrap` lease tracking (`beginInteractiveSignIn(id:)` / `endInteractiveSignIn(_:)` in normal order AND out-of-order `end` before `begin`).
- [ ] **Step 2: Run tests to verify RED**.
- [ ] **Step 3: Implement** `Set<UUID>` leases + `endedEarlyLeases` tombstones + bounded wait in `AnonymousAuthBootstrap`, and update `SocialAuthService` (`prepareAppleRequest`, `handleAppleAuthorization`, `signInWithApple`, `signInWithGoogle`).
- [ ] **Step 4: Run tests to verify GREEN**.

---

### Task 4: Fasting Live Activity Completion, Overtime & Deep Link

**Files:**
- Modify: `FoodTracker/Models/LiveActivities/FastingAttributes.swift`
- Modify: `FoodTracker/Services/FastingLiveActivityManager.swift`
- Modify: `FoodTrackerWidgets/FastingActivityWidget.swift`
- Modify: `FoodTracker/AppCore/AppStateManager.swift:26-45`
- Modify: `FoodTracker/App/FoodTrackerApp.swift:222-235`
- Modify: `FoodTrackerTests/FastingManagerTests.swift`
- Modify: `FoodTrackerTests/AppStateManagerTests.swift`

- [ ] **Step 1: Add failing tests in `FastingManagerTests.swift` and `AppStateManagerTests.swift`** for:
  - `FastingActivityTiming.isCompleted(now:targetEndDate:progressPct:)`
  - `FastingAttributes.ContentState` backward-compatible decoding when `isCompleted` key is omitted
  - `FastingLiveActivityUpdateDecision.shouldDispatch(...)` dispatching when `isCompleted` flips `false -> true` even when `currentStage` and `progressPct == 1.0` did not change
  - `AppStateManager.handleWidgetURL(URL(string: "foodtracker://fasting")!)`
- [ ] **Step 2: Run tests to verify RED**.
- [ ] **Step 3: Implement** `ContentState.isCompleted`, `FastingLiveActivityUpdateDecision`, `FastingLiveActivityManager` completion/staleDate logic, `FastingActivityWidget` `"Done"` + `widgetURL`, and `FoodTrackerApp` fasting sheet presentation.
- [ ] **Step 4: Run tests to verify GREEN**.

---

### Task 5: Localized `ChefRecipesView` Tags & Sparse `pt-PT` Food Search

**Files:**
- Create: `FoodTracker/Services/RecipeTagCatalog.swift`
- Modify: `FoodTracker/Views/Chefs/ChefRecipesView.swift:256-367,698-708`
- Modify: `FoodTracker/Services/LocalFoodDatabaseService.swift:89-105`
- Create: `FoodTrackerTests/RecipeTagCatalogTests.swift`
- Modify: `FoodTrackerTests/DataModelsTests.swift`
- Modify: `FoodTracker.xcodeproj/project.pbxproj` (register `RecipeTagCatalogTests.swift` in `FoodTrackerTests`)

- [ ] **Step 1: Register `RecipeTagCatalogTests.swift` in `project.pbxproj` and add failing tests** covering all 7 `recipes*.json` files (`DiscoverSections.partition` non-empty across all 7 languages, every bundled recipe tag maps to one of the 15 canonical tags) + `LocalFoodDatabaseService.searchEntries` supplementing from `foods_en` up to `limit` even when primary has `>= 3` hits.
- [ ] **Step 2: Run tests to verify RED**.
- [ ] **Step 3: Implement** `RecipeTagCatalog`, update `ChefRecipesView` (`DiscoverSections`, `openFiltered`, `AdvancedRecipeFilterSheet`), and update `LocalFoodDatabaseService.search`.
- [ ] **Step 4: Run tests to verify GREEN**.

---

### Final Verification

- Run `cd functions && npm test` (expect 32/32 pass).
- Run `xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,id=1780CCC3-3973-4A1C-A6F7-10EA666DACC7'` (full `FoodTrackerTests` + `FoodTrackerUITests` pass, 0 failures).
