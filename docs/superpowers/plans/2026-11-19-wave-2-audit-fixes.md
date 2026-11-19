# Wave 2 Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or inline TDD (`test-driven-development` RED-GREEN-REFACTOR) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Wave 2 fixes across Micronutrients, WorkoutTracker/HealthKit/Widget/Live Activity sync, UI/Persistence races, Onboarding/Nutrition math edge cases, and `FirebaseAnalyticsCore` (eliminating AdSupport/ATT conflict).

**Architecture:** Four self-contained TDD tasks: (1) End-to-end Micronutrient enrichment across LocalDB, OpenFoodFacts, FatSecret, and AI DTOs, (2) WorkoutSync water merge + non-water isolation, fresh Widget `ModelContext`, and Live Activity overtime UI, (3) HealthKit sync parity, midnight workout attribution, 90-day body mass window, and `UNUserNotificationCenterDelegate`, (4) `SharedModelContainer` `.applicationSupportDirectory` fallback, `PremiumQuickAddSheet` `onDismiss` chain, `Interactive Feature Tour` navigation reset, `NutritionSettingsEditor` clamping, future weight-date guard, `WeightTrackerCardView` goal-aware colors, onboarding target-weight guard, and `FirebaseAnalyticsCore`.

**Tech Stack:** Swift 5 / SwiftUI / SwiftData / HealthKit / ActivityKit / WidgetKit / UserNotifications / XCTest, Node.js 22 (`functions/`).

---

### Task 1: End-to-End Micronutrient Pipeline (LocalDB + OpenFoodFacts + FatSecret + AI)

**Files:**
- Create: `FoodTracker/Services/MicronutrientEstimator.swift`
- Modify: `FoodTracker/Services/LocalFoodDatabaseService.swift:15-24`
- Modify: `FoodTracker/Services/NetworkManager.swift:329-460`
- Modify: `FoodTracker/Services/VertexAIManager.swift:29-50, 223-257`
- Modify: `FoodTracker/AI/AINutritionService.swift:80-130, 290-358`
- Modify: `functions/index.js:970-1060`
- Test: `FoodTrackerTests/MicronutrientPipelineTests.swift`, `functions/test_proxy.js`

- [ ] **Step 1 (RED):** Write failing tests in `FoodTrackerTests/MicronutrientPipelineTests.swift` and `functions/test_proxy.js`:
  - `LocalFoodEntry.toFoodItem(weight: 200)` for salmon, spinach, milk, orange, and pure water produces realistic non-zero scaled micronutrients for foods and `0` for plain water.
  - `NetworkManager.extractOpenFoodFactsItem` parses OFF micronutrient keys (`iron_100g`, `calcium_100g`, `potassium_100g`, `magnesium_100g`, `vitamin-c_100g`, `vitamin-d_100g`, `omega-3-fat_100g`) respecting `_unit` (`g`, `mg`, `µg`/`mcg`).
  - `VertexAIManager.AIFoodResponse` & `AINutritionService.AIFoodItemDTO` decode optional clamped micronutrients (`0...10_000`) when returned and default cleanly to `0` when omitted.
  - `functions/test_proxy.js`: `normalizeFatSecretFood` passes through optional `calcium`, `iron`, `potassium`, `magnesium`, `vitaminC`, `vitaminD`, `omega3` when present in FatSecret servings.
- [ ] **Step 2 (Verify RED):** Run `npm test` in `functions/` and `xcodebuild test ... -only-testing:FoodTrackerTests/MicronutrientPipelineTests`.
- [ ] **Step 3 (GREEN):** Implement `MicronutrientEstimator` + wire `LocalFoodDatabaseService`, `NetworkManager`, `VertexAIManager`, `AINutritionService`, and `functions/index.js`.
- [ ] **Step 4 (Verify GREEN):** Re-run tests and confirm all pass.

### Task 2: WorkoutSync Water Reconciliation, Fresh Widget `ModelContext`, & Live Activity Overtime

**Files:**
- Modify: `FoodTracker/Models/DataModels.swift:317` (add `totalPureWaterLiters`)
- Modify: `FoodTracker/Services/WorkoutSyncManager.swift:186-258`
- Modify: `FoodTrackerWidgetExtension/WidgetTimelineProvider.swift:123-206`
- Modify: `FoodTrackerWidgetExtension/WidgetIntents.swift:12-62`
- Modify: `FoodTrackerWidgets/FastingActivityWidget.swift:95-137`
- Test: `FoodTrackerTests/DataModelsTests.swift`, `FoodTrackerTests/FastingManagerTests.swift`

- [ ] **Step 1 (RED):** Add failing tests in `DataModelsTests.swift` & `FastingManagerTests.swift`:
  1. Concurrent additions (`lastSynced = 1.0`, WorkoutTracker sets `1.25`, FoodTracker adds `+0.25L`) merge to `1.50L` instead of dropping WorkoutTracker's `+0.25L`.
  2. Non-water beverages (`"Coffee"` 300ml) do not re-push `0.3L` as water after WorkoutTracker resets `water_liters_` to `0.0`.
  3. `FastingActivityTiming.overtimeInterval` / overtime display helper handles post-`targetEndDate` state instead of `"Done"`.
- [ ] **Step 2 (Verify RED):** Run `DataModelsTests` and `FastingManagerTests`.
- [ ] **Step 3 (GREEN):** Update `WorkoutSyncManager.reconcileWaterWithOutcome`, switch `WidgetTimelineProvider` and `WidgetIntents` to fresh `ModelContext(container)`, and update `FastingActivityWidget` overtime rendering.
- [ ] **Step 4 (Verify GREEN):** Re-run `DataModelsTests` and `FastingManagerTests`.

### Task 3: HealthKit Parity, Midnight Workout Attribution, 90-Day Weight Window & Notification Delegate

**Files:**
- Modify: `FoodTracker/App/FoodTrackerApp.swift:7-34` (`AppDelegate: UNUserNotificationCenterDelegate`)
- Modify: `FoodTracker/Services/HealthKitManager.swift:238-267, 354-367`
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift:1180-1209`
- Modify: `FoodTracker/Views/Chefs/ChefRecipesView.swift:1292`
- Modify: `FoodTracker/Views/CreateRecipeView.swift:1157`
- Test: `FoodTrackerTests/FoodTrackerTests.swift`

- [ ] **Step 1 (RED):** Add unit tests for `HealthKitManager.clampedWorkoutInterval(date:durationMinutes:)` (verifying 00:20 AM 60-min workout clamps `startDate` to `startOfDay` rather than bleeding into yesterday) and `HealthKitManager.bodyMassLookbackStartDate(from:)` (90-day cutoff).
- [ ] **Step 2 (Verify RED):** Run `FoodTrackerTests/FoodTrackerTests`.
- [ ] **Step 3 (GREEN):** Implement helpers in `HealthKitManager`, wire `UNUserNotificationCenterDelegate` in `AppDelegate`, add `saveDietaryEnergy` in `MealDetailView.addFoodsToMeal`, and align `ChefRecipesView` / `CreateRecipeView` HealthKit gating to `isHealthKitEnabled`.
- [ ] **Step 4 (Verify GREEN):** Re-run `FoodTrackerTests/FoodTrackerTests`.

### Task 4: UI/Persistence Races, Nutrition/Onboarding Edge Cases & `FirebaseAnalyticsCore`

**Files:**
- Modify: `FoodTracker/Models/SharedModelContainer.swift:28-40`
- Modify: `FoodTracker/Views/Components/PremiumQuickAddSheet.swift:119-160`
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift:409-426`
- Modify: `FoodTracker/AppCore/AppStateManager.swift:18-67`
- Modify: `FoodTracker/Views/Profile/ProfileView.swift:8-23, 289-375, 442-451`
- Modify: `FoodTracker/Views/Goals/GoalsTabView.swift:600`
- Modify: `FoodTracker/Views/Components/WeightTrackerCardView.swift:48-57`
- Modify: `FoodTracker/Views/Onboarding/SwissBento/SwissBentoOnboardingFlow.swift:340-415`
- Modify: `FoodTracker/AppCore/MetabolicBlueprintCalculator.swift:85-98`
- Modify: `FoodTracker.xcodeproj/project.pbxproj` (`FirebaseAnalytics` -> `FirebaseAnalyticsCore`)
- Test: `FoodTrackerTests/DataModelsTests.swift`, `FoodTrackerTests/OnboardingBlueprintTests.swift`, `FoodTrackerTests/ProfileViewModelTests.swift`

- [ ] **Step 1 (RED):** Add unit tests for:
  1. `MetabolicBlueprintCalculator.calculate` with `"Lose Weight"` when `metrics.weight < metrics.targetWeight` (e.g. `weight = 65, targetWeight = 70`) ensures `targetWeightKg < weight`.
  2. `NutritionSettingsEditor.rebalancedPercentages` / macro slider rebalancing helper never produces negative percentages or sums != 100.
  3. `WeightTrackerTrendHelper.trend(current:previous:goalType:)` returns `.green` for gain when `goalType == "gain"` and `.red` for gain when `goalType == "lose"`.
  4. `SharedModelContainer.fallbackStoreDirectoryURL` resolves to Application Support (not `tmp`).
- [ ] **Step 2 (Verify RED):** Run targeted unit tests.
- [ ] **Step 3 (GREEN):** Implement all fixes + switch `FirebaseAnalytics` -> `FirebaseAnalyticsCore` in `project.pbxproj`.
- [ ] **Step 4 (Verify GREEN + Full Suite):** Run `cd functions && node --check index.js && npm test` and full `xcodebuild test ... -only-testing:FoodTrackerTests`.
