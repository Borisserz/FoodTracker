# Wave 1 Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or inline TDD (`test-driven-development` RED-GREEN-REFACTOR) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve all Wave 1 release blockers, security/auth vulnerabilities, crash/parsing bugs, barcode camera fallbacks, and localization/InfoPlist mismatches identified in the 2026-11-19 deep audit.

**Architecture:** Fix each subsystem independently with strict RED-GREEN-REFACTOR TDD: (1) AI numeric/DTO safety & menu partial decoding, (2) OpenFoodFacts parsing & AVFoundation barcode fallback + first-time permission handling, (3) Auth/deletion flow & Cloud Functions App Check/quota/schema/OAuth2 hardening, (4) `InfoPlist.xcstrings`, `Localizable.xcstrings`, widget/profile/fasting localization fixes. Live Firebase prod deployment is prepared and verified locally without mutating shared ecosystem production state until user confirmation.

**Tech Stack:** Swift 5 / SwiftUI / VisionKit / AVFoundation / XCTest, Node.js 22 (`node --test`), Firebase Cloud Functions v2, Xcode String Catalogs (`.xcstrings`).

---

### Task 1: AI Numeric Overflow Guard, DTO Clamping & Partial Menu Tolerance

**Files:**
- Modify: `FoodTracker/AI/AINutritionService.swift:18-44, 80-219`
- Modify: `FoodTracker/Services/VertexAIManager.swift:29-84, 162-168, 248-257`
- Test: `FoodTrackerTests/VertexAIManagerTests.swift`

- [ ] **Step 1 (RED):** Add failing unit tests in `FoodTrackerTests/VertexAIManagerTests.swift` verifying:
  1. `FlexibleInt` and `AIFoodResponse` do not crash on extreme values like `1e20`, `"-1e20"`, `"999999999999999999999"` (must fail decoding cleanly or clamp safely instead of `Int(doubleVal.rounded())` trapping).
  2. Negative/extreme macro values in `MenuRecommendation`, `MacroFixAdviceDTO.SnackIdea`, `AIRecipeDTO`, `AIChefRecipeDTO`, `AIWeeklyPlanItemDTO`, and `AIFoodResponse` are clamped to `>= 0` and reasonable upper sanity bounds.
  3. `MenuAIResponse` decodes successfully when `caution` or `avoid` (or `ideal`) is omitted by the LLM (`ideal: MenuRecommendation?`, `caution: MenuRecommendation?`, `avoid: MenuRecommendation?` or fallback).
- [ ] **Step 2 (Verify RED):** Run `xcodebuild test ... -only-testing:FoodTrackerTests/VertexAIManagerTests` and observe failure/crash on overflow / negative / partial menu.
- [ ] **Step 3 (GREEN):**
  - Extract a safe `safeRoundedInt(from doubleVal: Double)` helper (`Int.min...Int.max` guard using `Double(Int.max / 2)` or `doubleVal >= Double(Int.min) && doubleVal < Double(Int.max)`) + `clampedNonNegative(_:max:)` helpers shared across `AINutritionService` and `VertexAIManager`.
  - Clamp parsed calories/macros/weights/cookingTime across `AIFoodResponse`, `MenuRecommendation`, `AIRecipeDTO`, `AIFoodItemDTO`, `AIWeeklyPlanItemDTO`, `AIWeeklyPlanDayDTO`, `AIChefRecipeDTO`, `MacroFixAdviceDTO.SnackIdea`.
  - Make `MenuAIResponse` properties optional (`MenuRecommendation?`) and update `SmartScannerView` menu cards rendering to handle optional tiers cleanly while failing only if all three are `nil`.
- [ ] **Step 4 (Verify GREEN):** Re-run `VertexAIManagerTests` and confirm all pass.

### Task 2: OpenFoodFacts Parsing Fixes & Barcode Scanner AVFoundation Fallback + Permission Fix

**Files:**
- Modify: `FoodTracker/Services/NetworkManager.swift:123-155, 322-365`
- Modify: `FoodTracker/Scan/BarcodeScannerController.swift:4-89`
- Modify: `FoodTracker/Scan/SmartScannerView.swift:38-100, 400-590, 621-655`
- Test: `FoodTrackerTests/NetworkManagerTests.swift`

- [ ] **Step 1 (RED):** Add failing unit tests in `FoodTrackerTests/NetworkManagerTests.swift` for `extractOpenFoodFactsItem` / `fetchProductOutcome`:
  1. Partial `_100g` (e.g., `proteins_100g` present, `energy-kcal_100g` missing, `energy-kcal_serving` present) uses serving or per-field values rather than returning `0 kcal`.
  2. `energy_unit: "kcal"` with `energy_100g: 250` does NOT divide by `4.184`.
  3. `serving_size: "1 bottle (1 L)"` and `"1 kg"` parse to `1000.0` grams/ml instead of `100.0`.
  4. Genuine 0-kcal drink with explicit `"energy-kcal_100g": 0` returns `.found` with `0` kcal, while empty `"nutriments": {}` still returns `.notFound` (preserving FatSecret fallback).
- [ ] **Step 2 (Verify RED):** Run `NetworkManagerTests` and observe failures.
- [ ] **Step 3 (GREEN):**
  - Update `NetworkManager.extractWeight` to support `kg` (`* 1000`) and `l|liter|liters|л` (`* 1000`).
  - Update `NetworkManager.extractOpenFoodFactsItem` to inspect `energy_unit` (`"kcal"` vs `"kJ"`), fall back to `*_serving` whenever `cals <= 0` and serving data exists (or per-nutrient fallback), and distinguish empty `nutriments` from explicit `0`-calorie entries.
  - Update `SmartScannerView.searchBarcodeInDatabase` to switch on `await NetworkManager.shared.fetchProductOutcome(barcode:)` directly instead of reading mutable `lastBarcodeLookupError`.
  - Update `DataScannerRepresentable.Coordinator.dataScanner(_:becameUnavailableWithError:)` to notify `SmartScannerView` so first-time `.denied`/`.restricted` updates `barcodePermissionStatus` immediately instead of leaving a black screen.
  - Add an `AVCaptureMetadataOutput` fallback scanner view (`AVBarcodeScannerView`) inside `BarcodeScannerController.swift` and wire it in `SmartScannerView` when `!(DataScannerViewController.isSupported && DataScannerViewController.isAvailable)` so barcode scanning works without VisionKit DataScanner; also track & cancel `PhotosPicker` load `Task` on `onDisappear` (and in `AIChefStudioView`).
- [ ] **Step 4 (Verify GREEN):** Re-run `NetworkManagerTests` and full `FoodTrackerTests`.

### Task 3: Auth/Account Deletion Ordering & Cloud Functions Hardening

**Files:**
- Modify: `FoodTracker/Auth/AuthManager.swift:33, 123-137`
- Modify: `FoodTracker/Views/Profile/ProfileView.swift:755-765`
- Modify: `FoodTracker/Auth/AnonymousAuthBootstrap.swift:15-80`
- Modify: `FoodTracker/Auth/SocialAuthService.swift:28-39`
- Modify: `FoodTracker/Services/GeminiProxyClient.swift:239-281`
- Modify: `FoodTracker/Services/NetworkManager.swift:463-522`
- Modify: `functions/index.js:10-25, 185-235, 523-554, 714-731, 842-855, 1146-1193, 1504-1565`
- Test: `FoodTrackerTests/SocialAuthServiceTests.swift`, `functions/test_proxy.js`

- [ ] **Step 1 (RED):**
  - In `functions/test_proxy.js`, add failing tests for:
    1. `verifyAppCheck` rejects tokens from wrong `appId` when `ALLOWED_APP_CHECK_APP_IDS` is enforced and accepts FoodTracker's `appId`.
    2. `validateAiProxyBody` rejects oversized `responseSchema` (> 16 KB serialized).
    3. `loadAISettings` / `sanitizeModelOverrides` strips non-`:free` models.
    4. `resolveIpQuotaKey` normalizes `::ffff:` and ignores CGNAT `100.64.0.0/10` / `fc00::/7` / `fe80::/10` in XFF.
    5. `resolveUserWeeklyLimit` applies tighter quota for `anonymous` Firebase Auth provider vs non-anonymous users.
    6. `assertFatSecretResponseSuccess` throws on FatSecret OAuth 2.0 HTTP-200 `{ error: { ... } }` payloads.
  - In `FoodTrackerTests/SocialAuthServiceTests.swift`, update/add tests verifying `AuthManager.accountDeletionTimeoutInterval >= 120.0`, `AuthManager.deleteCurrentUser` succeeds when server cleanup succeeds without failing on redundant client delete, and `SocialAuthService` double-tap nonce guard.
- [ ] **Step 2 (Verify RED):** Run `cd functions && npm test` and `xcodebuild test ... -only-testing:FoodTrackerTests/SocialAuthServiceTests` and confirm expected failures.
- [ ] **Step 3 (GREEN):**
  - Harden `functions/index.js` (`verifyAppCheck` `appId` check, anonymous provider quota cap, `responseSchema` size cap, `concurrency: 20` on `foodAiProxy`, `:free` filter in `loadAISettings`, `resolveIpQuotaKey` IP normalization, OAuth 2.0 `data?.error` check).
  - Fix `AuthManager.swift` (`accountDeletionTimeoutInterval = 130.0`, remove blocking `try await user.delete()` throw after server already returned 200), `ProfileView.swift:762-763` (`LocalDataResetService.wipeAllData(in: context)` before `AnonymousAuthBootstrap.shared.ensureSignedIn()`), `SocialAuthService.prepareAppleRequest` (debounce concurrent Apple requests cleanly without overwriting in-flight nonce), and `AnonymousAuthBootstrap` (avoid cancelling callers on `beginInteractiveSignIn` unless needed / handle cleanly).
- [ ] **Step 4 (Verify GREEN):** Run `cd functions && npm test` and `SocialAuthServiceTests`.

### Task 4: Localization, `InfoPlist.xcstrings`, Widget & Profile String Fixes

**Files:**
- Modify: `FoodTracker/InfoPlist.xcstrings`
- Modify: `Localizable.xcstrings`
- Modify: `FoodTracker/Services/FastingManager.swift:89-98`
- Modify: `FoodTracker/Views/Profile/ProfileView.swift:114-116, 1253-1261`
- Modify: `FoodTracker/Views/More/MoreTabView.swift:111, 296`
- Modify: `FoodTracker/Views/Profile/AnalyticsDashboardView.swift:1394, 1439-1440`
- Modify: `FoodTrackerWidgetExtension/WidgetViews.swift:66-70`
- Test: `FoodTrackerTests/FoodTrackerTests.swift`

- [ ] **Step 1 (RED):** Expand `FoodTrackerTests.testLocalizableStringsCatalogCoversAuditMissingKeysAcrossAllSevenLocales` (plus a new `testInfoPlistHealthUpdateDescriptionMentionsWorkoutsAndWeightAcrossLocales` test) to assert all Widget, Live Activity, WidgetIntent, `Hello, %@!`, `P: %lldg`, and `InfoPlist.xcstrings` `NSHealthUpdateUsageDescription` keys exist and are non-empty across all 7 locales.
- [ ] **Step 2 (Verify RED):** Run `xcodebuild test ... -only-testing:FoodTrackerTests/FoodTrackerTests` and observe failures for the missing keys and incomplete `InfoPlist.xcstrings`.
- [ ] **Step 3 (GREEN):**
  - Update `FoodTracker/InfoPlist.xcstrings` `NSHealthUpdateUsageDescription` across all 7 languages to accurately describe water, calories, workouts, and body weight.
  - Add all missing Widget/Live Activity/Intent/UI keys to `Localizable.xcstrings` across all 7 languages.
  - Fix `ProfileView.swift:114-116` (`MacroDotLabel` accepting `LocalizedStringKey`), `MoreTabView.swift:111` (`String(localized: "Hello, \(user.name)!")`), `FastingManager.swift:89-98` (`remainingTimeString` delegating to `localizedRemainingTimeString`), `AnalyticsDashboardView.swift:1394, 1439-1440` and `WidgetViews.swift:66-70` (`String(localized: ...)`).
- [ ] **Step 4 (Verify GREEN + Full Verification):** Run `cd functions && node --check index.js && npm test` and full `xcodebuild test ... -only-testing:FoodTrackerTests`, plus `git diff --stat`.
