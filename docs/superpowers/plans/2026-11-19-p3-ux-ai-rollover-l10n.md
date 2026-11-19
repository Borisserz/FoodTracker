# FoodTracker Point 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development and superpowers:verification-before-completion. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Point 3 across FoodTracker: AI snack logging and schema hardening, weekly meal planner & shopping list deduplication, midnight rollover fixes, `NutritionProgressManager` purity, `MetabolicTDEEGaugeView` & `CustomRecipe` math alignment, Reduce Motion gating, and complete 7-language localization (`en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`).

**Architecture:** All nutrition math and data deduplication helpers live in `FoodTracker` model/utility extensions so both SwiftUI views and `XCTestCase` unit tests verify the exact shared logic. UI-layer localization preserves canonical English model/test keys (`FastingManager`, `NutritionProgressManager`) where tested or keyed.

**Tech Stack:** SwiftUI, SwiftData, HealthKit, WidgetKit, Localization String Catalog (`Localizable.xcstrings`), XCTest.

---

### Task 1: RED Tests for Point 3 Invariants

**Files:**
- Modify: `FoodTrackerTests/VertexAIManagerTests.swift`
- Modify: `FoodTrackerTests/DataModelsTests.swift`
- Modify: `FoodTrackerTests/NutritionProgressManagerTests.swift`

- [ ] **Step 1: Add failing tests**
  - `VertexAIManagerTests`: `testDecodeFlexibleDoubleHandlesThousandsCommas` asserting `"1,250"` -> `1250.0`, `"1,250.5"` -> `1250.5`, `"12,5"` -> `12.5`.
  - `DataModelsTests`:
    - `testShoppingItemInsertDeduplicatedCaseInsensitive`
    - `testCustomRecipeToAIChefRecipeUsesPerServingNutrition`
    - `testMacroFixSnackIdeaDecodesOptionalMacrosAndLegacyPayload`
    - `testNormalizedWeeklyPlanDaysSortsDeduplicatesAndCoversWeek`
    - `testMetabolicTDEEGaugeComputeTDEEApplies1200Floor`
    - `testDeleteLastWeightLogPreservesPositiveUserWeight`
  - `NutritionProgressManagerTests`:
    - `testInitDoesNotMutateUserLevelUntilSyncLevel`
- [ ] **Step 2: Run targeted XCTest suite and verify RED**

### Task 2: AI UX, Parsing Hardening & Meal Planner Consistency

**Files:**
- Modify: `FoodTracker/Services/VertexAIManager.swift`
- Modify: `FoodTracker/AI/AINutritionService.swift`
- Modify: `FoodTracker/AI/AICoachViewModel.swift`
- Modify: `FoodTracker/AI/AICoachDashboardView.swift`
- Modify: `FoodTracker/Views/Home/AIMoodAdvicePopup.swift`
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift`
- Modify: `FoodTracker/Views/SmartBuilder/SmartPlanBuilderFlow.swift`
- Modify: `FoodTracker/Views/SmartBuilder/WeeklyPlanOverview.swift`
- Modify: `FoodTracker/Views/Chefs/ChefRecipesView.swift`
- Modify: `FoodTracker/Models/DataModels.swift`

- [ ] **Step 1: Fix `VertexAIManager.decodeFlexibleDoubleIfPresent` using `AINutritionService.parseFlexibleDecimalString`**
- [ ] **Step 2: Enrich `MacroFixAdviceDTO.SnackIdea`, prompt, and 1-tap `MacroFixResultSheet` logging (with `Snack` slot, HealthKit `healthKitSampleID`, and `WidgetReloader.reloadAll()`)**
- [ ] **Step 3: Harden `AINutritionService.generateWeeklyPlan`, `generateCookingSteps` (`fat`/`carbs`), `getMoodAdvice` (`suppressRateLimitAlert: true`), `MealDetailView.generateRecipe`, and `AIMoodAdvicePopup`**
- [ ] **Step 4: Deactivate older plans in `SmartPlanBuilderFlow`, use cancellable `Task` in `AIGenerationLoadingView`, show `fat`/`carbs`/`instructions` + empty-day guard in `WeeklyPlanOverview`, and share `ShoppingItem.insertDeduplicated` between `WeeklyPlanOverview` and `ChefRecipesView`**

### Task 3: Midnight Rollover, State Purity, Math Alignment & Reduce Motion

**Files:**
- Modify: `FoodTracker/AppCore/NutritionProgressManager.swift`
- Modify: `FoodTracker/Views/Profile/ProfileView.swift`
- Modify: `FoodTracker/Views/Components/Redesign/DailyXPQuestsCardView.swift`
- Modify: `FoodTracker/Views/Components/Redesign/MetabolicTDEEGaugeView.swift`
- Modify: `FoodTracker/Views/CreateRecipeView.swift`
- Modify: `FoodTracker/App/AIChefStudioView.swift`
- Modify: `FoodTracker/Views/Home/CalendarView.swift`
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift`
- Modify: `FoodTracker/Views/Onboarding/SwissBento/SwissBentoOnboardingFlow.swift`
- Modify: `FoodTracker/Views/Profile/AnalyticsDashboardView.swift`
- Modify: `FoodTracker/Scan/SmartScannerView.swift`

- [ ] **Step 1: Remove `recalculateLevel()` from `NutritionProgressManager.init(user:)`, add `syncLevel()`, call from `.onAppear` in `ProfileView` and `DailyXPQuestsCardView`**
- [ ] **Step 2: Add static `MetabolicTDEEGaugeView.computeTDEE(for:currentWeight:)` with `max(1200, bmr)` floor and update `CustomRecipe.toAIChefRecipe()` per-serving math**
- [ ] **Step 3: Replace frozen `Date()` `@Query` predicates in `AIChefStudioView` & `CalendarCarouselView`, and add foreground midnight rollover in `HomeDashboardContentView`**
- [ ] **Step 4: Gate `Stage4BlueprintRevealView` 50Hz timer and `.symbolEffect(.pulse)` modifiers on `!reduceMotion`**

### Task 4: Complete 7-Language Localization & `Localizable.xcstrings` Sync

**Files:**
- Modify: `FoodTracker/AppCore/NutritionProgressManager.swift`
- Modify: `FoodTracker/AI/AICoachViewModel.swift`
- Modify: `FoodTracker/AI/AICoachDashboardView.swift`
- Modify: `FoodTracker/Views/SmartBuilder/SmartPlanBuilderFlow.swift`
- Modify: `FoodTracker/Views/SmartBuilder/WeeklyPlanOverview.swift`
- Modify: `FoodTracker/Views/Profile/AnalyticsDashboardView.swift`
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift`
- Modify: `FoodTracker/Views/CreateRecipeView.swift`
- Modify: `FoodTracker/Services/FastingManager.swift`
- Modify: `FoodTracker/Views/FastingDashboardView.swift`
- Modify: `FoodTracker/Views/History/HistoryView.swift`
- Modify: `FoodTracker/App/AIChefStudioView.swift`
- Modify: `FoodTracker/Resources/Localizable.xcstrings`

- [ ] **Step 1: Localize UI strings & notification strings while preserving canonical test keys (`FastingManager`, `NutritionProgressManager`)**
- [ ] **Step 2: Populate all 44 existing missing keys + all new Point 3 UI keys in `Localizable.xcstrings` across `en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`**
- [ ] **Step 3: Run Python localization completeness audit script (`0` missing, `0` incomplete)**

### Task 5: Full Verification (`functions`, `FoodTrackerTests`, `FoodTrackerUITests`)

- [ ] **Step 1: Run `cd /Users/borisserzhanovich/Projects/FoodTracker/functions && npm test`**
- [ ] **Step 2: Run full `FoodTrackerTests` + `FoodTrackerUITests` on iPhone 17 Simulator after final edit**
