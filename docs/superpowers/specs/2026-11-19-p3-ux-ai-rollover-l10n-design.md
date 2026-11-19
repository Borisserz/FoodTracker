# FoodTracker Point 3 — AI UX, Data Consistency, Midnight Rollover & Localization Design

**Date:** 2026-11-19
**Scope:** Point 3 UX, AI robustness, nutrition math consistency, midnight day-rollover, and full 7-language localization across `FoodTracker` and `Localizable.xcstrings`.

## Goals

1. **AI UX & Parsing Hardening:**
   - Enable 1-tap `"Log"` action on each snack inside `MacroFixResultSheet` (enriching `MacroFixAdviceDTO.SnackIdea` with optional `fats`, `carbs`, `weight` and logging into `Snack` + HealthKit + `WidgetReloader`).
   - Validate/pad/guard `WeeklyMealPlan` generation (`AINutritionService.generateWeeklyPlan`), show `fat`, `carbs`, and `instructions` on `MealPlanItemCard`, guard `applyToToday` against empty days, deactivate prior plans (`isCurrentPlan = false`) on new plan creation in `SmartPlanBuilderFlow`, and deduplicate `ShoppingItem` insertions across `WeeklyPlanOverview` and `ChefRecipesView`.
   - Fix thousands-comma parsing (`"1,250"` -> `1250`) in `VertexAIManager.decodeFlexibleDoubleIfPresent`.
   - Include `"fat"` and `"carbs"` in `AINutritionService.generateCookingSteps` and `MealDetailView.generateRecipe`, suppress duplicate error alert on `429` in `MealDetailView`, and pass `suppressRateLimitAlert: true` in `AIMoodAdvicePopup.getMoodAdvice` (which has an offline baseline fallback).
2. **Midnight Rollover, State Purity & Math Consistency:**
   - Fix midnight rollover in `AIChefStudioView`, `CalendarCarouselView`, and `HomeDashboardView` (avoid pinning stale `Date()` `@Query` predicates when foregrounding across midnight, and update `selectedDate` to today when foregrounding into a new day from yesterday).
   - Remove SwiftData `@Model` mutation (`recalculateLevel()`) from `NutritionProgressManager.init(user:)` so SwiftUI `body` evaluation never mutates `user.level`; move synchronization to explicit `syncLevel()` / `.onAppear` and `addXP(...)`.
   - Apply the 1200 kcal BMR floor before multiplying by `activityMultiplier` in `MetabolicTDEEGaugeView.tdeeValue` to match `User.calculateGoals()` and `MetabolicBlueprintCalculator`.
   - Compute per-serving calories/macros in `CustomRecipe.toAIChefRecipe()`.
   - Preserve positive `user.weight` safely in `NutritionMath.deleteWeightLog` when deleting the final remaining `WeightLog` (avoiding zeroing BMR weight), while clearing `DailySummary.weight` as already implemented.
3. **Complete 7-Language Localization & Reduce Motion:**
   - Add all 44 missing `Localizable.xcstrings` keys across `en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`.
   - Convert plain `String` display properties to localized keys/lookups: `NutritionProgressManager.currentTitle`, `WeeklyPlanOverview.dayNames` / `"Day %lld"`, `FastingManager` (`currentPhase.name`, `remainingTimeString`, notification titles/bodies), `AIWeeklyInsightCard` (`insight` & `getHint`), `AICoachViewModel` defaults, `AICoachDashboardView` `BioHackingTip`, `SmartPlanBuilderFlow` `AIGenerationLoadingView.statuses`, `DailyNoteSheet.moods` & localized mood chat prompt, `CreateRecipeView` `platingTip`, and `AIChefStudioView` `plan.dietType`.
   - Honor `@Environment(\.accessibilityReduceMotion)` in `Stage4BlueprintRevealView` (`SwissBentoOnboardingFlow.swift`), `AnalyticsDashboardView`, `SmartScannerView`, and `AIChefStudioView`.

---

## Architecture & Key Changes

### 1. AI & Planner Robustness
- **`AINutritionService.swift`:**
  - `MacroFixAdviceDTO.SnackIdea`: add optional `fats: Int?`, `carbs: Int?`, `weight: Double?` (using flexible decoding with defaults `0`, `0`, `100.0`) so existing/partial JSON still decodes and enriched prompts return full macros.
  - `generateCookingSteps`: include `"fat": Int` and `"carbs": Int` in the JSON prompt schema (`AIChefRecipeDTO` already decodes `fat` and `carbs`).
  - `generateWeeklyPlan`: require all 7 unique day indices `0...6` or normalize/deduplicate `normalizedPlanDays` cleanly and validate `!planDays.isEmpty` with explicit day coverage; reject empty-meal days during `applyToToday` so `"✅ Applied to Today's Log!"` only triggers when `loggedCount > 0`.
  - `getMoodAdvice`: pass `suppressRateLimitAlert: true` to `fetchFromGemini`.
- **`AICoachDashboardView.swift`:**
  - `MacroFixResultSheet`: accept `selectedDate: Date`, `onSnackLogged: (() -> Void)?` (or `@Environment(\.modelContext)` + `@Query users: [User]`), render fat/carb pills and a `"Log Snack"` button per card that inserts a `FoodItem` into today/selected `Snack` slot, saves, reloads widgets, and syncs HealthKit (`healthKitSampleID`).
- **`SmartPlanBuilderFlow.swift` & `WeeklyPlanOverview.swift`:**
  - In `SmartPlanBuilderFlow.startGeneration()`, set `existingPlan.isCurrentPlan = false` on all previously saved `WeeklyMealPlan` records before inserting `newPlan` (`isCurrentPlan = true`).
  - In `WeeklyPlanOverview`, filter/render actual days or show clear empty-day placeholder, show `fat`, `carbs`, and `instructions` on `MealPlanItemCard`, guard `applyToToday()` when `meals.isEmpty`, and deduplicate `ShoppingItem` insertions case-insensitively against existing `ShoppingItem` records (extract shared `ShoppingItem.insertDeduplicated(items:recipeTitle:in:)` helper used by both `WeeklyPlanOverview` and `ChefRecipesView`).
- **`VertexAIManager.swift` & `HomeDashboardView.swift`:**
  - Extract/reuse thousands-comma decimal parser (`"1,250"` -> `1250.0`, `"1,25"` -> `1.25`) in `VertexAIManager.decodeFlexibleDoubleIfPresent`.
  - In `MealDetailView.generateRecipe`: pass `fat: dto.fat, carbs: dto.carbs`, use `"fork.knife"` hero icon fallback, and check `!GeminiProxyClient.shouldSuppressSecondaryErrorAlert` before setting `recipeGenerationError`.

### 2. Midnight Rollover, State Purity & Math
- **`AIChefStudioView.swift`:** Replace the frozen `Date()` `#Predicate` in `init()` with `@Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]` (with `fetchLimit` or lightweight scan) and refresh on `scenePhase == .active` using current `Date()` so `todaySummary` never stays `nil` past midnight.
- **`CalendarView.swift` (`CalendarCarouselView`):** Replace frozen `Date()` `#Predicate` in `init` with a query over `DailySummary` + `@Environment(\.scenePhase)` trigger (`@State private var currentDayStart = Calendar.current.startOfDay(for: Date())`) so `days` and status dots update immediately after midnight.
- **`HomeDashboardView.swift`:** Track `lastActiveDayStart` and advance `selectedDate` to the new `today` on `.active` if the user was viewing yesterday when midnight passed.
- **`NutritionProgressManager.swift`, `ProfileView.swift`, `DailyXPQuestsCardView.swift`:** Remove `recalculateLevel()` from `init(user:)`; expose `syncLevel()` called from `.onAppear` and `addXP(from:)`.
- **`MetabolicTDEEGaugeView.swift`:** Clamp `bmr = max(1200, rawBMR)` before multiplying by `multiplier`.
- **`CreateRecipeView.swift` (`CustomRecipe.toAIChefRecipe()`):** Divide `totalCalories`, `protein`, `fat`, `carbs` by `max(servings, 1)` to report per-serving nutrition consistently with `CustomRecipe.perServingNutrition`.

### 3. Localization & Reduce Motion
- Populate all 44 missing keys + all newly converted UI strings (`FastingManager`, `AIWeeklyInsightCard`, `BioHackingTip`, `SmartPlanBuilderFlow` statuses, `DailyNoteSheet` moods, `NutritionProgressManager` titles, `CreateRecipeView` `platingTip`, `MacroFixResultSheet` `"Log Snack"` / `"Logged!"`) in `Localizable.xcstrings` for all 7 languages (`en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`).
- Gate `.symbolEffect(.pulse)` (`AnalyticsDashboardView`, `SmartScannerView`, `AIChefStudioView`) and `Stage4BlueprintRevealView` 50Hz timer in `SwissBentoOnboardingFlow.swift` on `!reduceMotion`.

---

## Testing Scope (TDD)

- `VertexAIManagerTests`: `decodeFlexibleDoubleIfPresent` with `"1,250"`, `"1,250.5"`, and `"12,5"`.
- `AINutritionService` / `DataModelsTests`:
  - `MacroFixAdviceDTO` decodes both legacy 3-field snacks and full macro/weight snacks.
  - `ShoppingItem.insertDeduplicated` avoids creating duplicate items across `WeeklyPlanOverview` and `ChefRecipesView`.
  - `CustomRecipe.toAIChefRecipe()` returns per-serving macros for multi-serving recipes.
  - `MetabolicTDEEGaugeView.computeTDEE` (extracted pure static helper) applies the 1200 BMR floor matching `User.calculateGoals()`.
  - `NutritionProgressManager.init(user:)` does not mutate `user.level` during read/init, while `syncLevel()` updates it.
- `FastingManagerTests`: `currentPhase.name` and `remainingTimeString` behavior preserved + localized display formatting.
- Full `FoodTrackerTests`, `FoodTrackerUITests`, and `functions` `npm test`.
