# Wave 2 (WorkoutTracker Sync, HealthKit, Widgets & Fasting) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or inline TDD (`test-driven-development`) to implement this plan task-by-task.

**Goal:** Fix all P1/P2 synchronization, HealthKit, WidgetKit, and Fasting bugs identified in the deep audit: pure-water vs all-beverage sync mismatch, partial water trim HealthKit replacement, imported WorkoutTracker water deletion safety, widget pre-write reconciliation, WeightLog HealthKit deletion + date check, fasting notification deep-linking & phase 4h alignment, and cold-start Live Activity reattach order.

**Architecture:**
1. Standardize `WorkoutSyncManager.syncWater(...)` callers in `AICoachDashboardView` and `AnalyticsDashboardView` to `totalPureWaterLiters`.
2. Tag WorkoutTracker-imported water entries (`external:workouttracker`) so deleting them never falls back to deleting FoodTracker's own HealthKit samples, and emit replacement volume info when partially trimming a HealthKit-backed water sample so `HomeDashboardView` re-creates the remaining HealthKit sample.
3. Reconcile `WorkoutSyncManager` inside `WidgetStorageActions.addWaterGlassAndRecordPendingDelta` before adding a widget glass, and route `AddWaterIntent` through that single helper.
4. Persist `healthKitSampleID` on `WeightLog`, delete the matching HealthKit `.bodyMass` sample on `NutritionMath.deleteWeightLog`, and guard `HealthKitWeightSyncHelper.shouldImportHealthKitWeight` against importing stale historical samples over newer local weights.
5. Align `FastingManager` notification identifiers/category (`FASTING_PHASE`) with `AppDelegate.notificationDeepLinkRoute`, fix the `phase_4h` notification copy (`Digestion Mode`), and avoid calling `liveActivityManager.updateActivity` before `reattachActivity` during `loadState()`.

**Tech Stack:** Swift 5 / SwiftUI / SwiftData / HealthKit / WidgetKit / ActivityKit / UserNotifications / XCTest.

---

### Task 1 (P1-1): Pure Water Sync in `AICoachDashboardView` & `AnalyticsDashboardView`
- **Modify:** `FoodTracker/AI/AICoachDashboardView.swift:221`, `FoodTracker/Views/Profile/AnalyticsDashboardView.swift:861, 894`
- **Verify:** Existing and new `WorkoutSyncManager` tests pass; static check confirms all `syncWater` calls pass `totalPureWaterLiters`.

### Task 2 (P1-2 & P2-4): Partial Water Trim Replacement & Safe Deletion of Imported WorkoutTracker Water
- **Modify:** `FoodTracker/Services/WorkoutSyncManager.swift`, `FoodTracker/Services/HealthKitManager.swift`, `FoodTracker/Views/Home/HomeDashboardView.swift`
- **Tests:** `DataModelsTests.swift` (partial trim clears `healthKitSampleID` & emits `replacementVolumeMl`; imported WorkoutTracker water carries `"external:workouttracker"` sentinel), `FoodTrackerTests.swift` (`HealthKitManager.deleteWaterSample` ignores `"external:*"` sentinel without fallback-deleting unrelated local samples).

### Task 3 (P1-3): Reconcile External WorkoutTracker Water Before Adding Widget Glass
- **Modify:** `FoodTracker/Models/DataModels.swift` (`WidgetStorageActions.addWaterGlassAndRecordPendingDelta`), `FoodTrackerWidgetExtension/WidgetIntents.swift` (`AddWaterIntent`)
- **Tests:** `FoodTrackerTests.swift` (`WidgetIntentStorageTests.testPerformAddWaterReconcilesExternalWorkoutTrackerWaterBeforeWriting`).

### Task 4 (P2-3): `WeightLog.healthKitSampleID` Deletion Sync & Stale Historical Weight Guard
- **Modify:** `FoodTracker/Models/DataModels.swift` (`WeightLog`), `FoodTracker/Services/HealthKitManager.swift`, `FoodTracker/Utils/NutritionMath.swift`, `FoodTracker/Views/Home/HomeDashboardView.swift`
- **Tests:** `DataModelsTests.swift` (`HealthKitWeightSyncHelper` stale-date guard), `FoodTrackerTests.swift` (`HealthKitManager.deleteBodyMassSample`).

### Task 5 (P1-4 & P1-5): Fasting Notification Deep-Link, Phase 4h Copy & Cold-Start Live Activity Order
- **Modify:** `FoodTracker/App/FoodTrackerApp.swift`, `FoodTracker/Services/FastingManager.swift`
- **Tests:** `FoodTrackerTests.swift` (`testNotificationActionRouterMapsFastingNotificationsToFastingRoute` extended for `"phase_4h"`, `"fasting_goal_reached"`, and `"FASTING_PHASE"`), `FastingManagerTests.swift` (verify `restorePersistedState` calls `reattachActivity` BEFORE any `updateActivity`, and `FastingManager.phaseNotificationCopy(forHours:)` returns `"Digestion Mode"` at 4h).
