# Wave 1 (P0 App Store Blockers & Crash Prevention) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or inline TDD (`test-driven-development`) to implement this plan task-by-task.

**Goal:** Eliminate all 5 P0 App Store release blockers and SwiftData concurrency risks identified in the deep audit: SwiftData `@ModelActor` thread-confinement safety, `PrivacyInfo.xcprivacy` required-reason/DeviceID declarations, Guideline 5.1.2(i) AI consent across text/mood/search/photo flows, Guideline 1.4.1 medical disclaimers + clickable scientific citations + diet contraindications, and updated `Privacy Policy - FoodTracker.html`.

**Architecture:**
1. Refactor `SummaryRepositoryProtocol` and `UserRepositoryProtocol` so background `@ModelActor` actors return `PersistentIdentifier` / value types only and `@MainActor` ViewModels resolve live `@Model` objects strictly on `mainModelContainer.mainContext`.
2. Expand `PrivacyInfo.xcprivacy` with `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`) and `NSPrivacyCollectedDataTypeDeviceID`.
3. Add a `consentProvider` gate to `AINutritionService` and `NetworkManager`'s AI fallback, stop `AIMoodAdvicePopup`'s automatic unconsented network call on appear, and surface `AIPhotoConsentSheet` on explicit AI Coach / Chef / Plan taps.
4. Create `NutritionMethodologyDisclaimerView` with `MedicalCitationCatalog` (PubMed Mifflin-St Jeor, WHO BMI, USDA Dietary Guidelines, NIH ODS, NEJM Intermittent Fasting) and wire it + `diet.contraindications` across all nutrition/metabolic/fasting/diet screens, adding full 7-language translations in `Localizable.xcstrings`.
5. Produce a ready-to-publish `docs/legal/Privacy Policy - FoodTracker.html` aligned with the app's real architecture.

**Tech Stack:** Swift 5 / SwiftUI / SwiftData / Observation / XCTest (`FoodTrackerTests`), Xcode String Catalog (`Localizable.xcstrings`), Privacy Manifest (`PrivacyInfo.xcprivacy`).

---

### Task 1 (P0-5): Eliminate `@Model` Escapes from `@ModelActor` Repositories

**Files:**
- Modify: `FoodTracker/DataLayer/Repositories/SummaryRepository.swift`
- Modify: `FoodTracker/DataLayer/Repositories/UserRepository.swift`
- Modify: `FoodTracker/Views/Profile/AnalyticsViewModel.swift`
- Test: `FoodTrackerTests/SummaryRepositoryTests.swift`, `FoodTrackerTests/UserRepositoryTests.swift`

- [ ] **Step 1 (RED):** Update `SummaryRepositoryTests.swift` and `UserRepositoryTests.swift` to expect `fetchSummaryID(for:)`, `ensureSummaryID(for:)`, and `fetchPrimaryUserID()` returning `PersistentIdentifier` (asserting resolved models belong to `container.mainContext`) instead of `@Model` instances escaping `@ModelActor`.
- [ ] **Step 2 (Verify RED):** Run `xcodebuild test ... -only-testing:FoodTrackerTests/SummaryRepositoryTests -only-testing:FoodTrackerTests/UserRepositoryTests` and verify compilation fails on missing ID-returning methods.
- [ ] **Step 3 (GREEN):** Replace `@Model`-returning methods in `SummaryRepositoryProtocol`, `SummaryRepository`, `UserRepositoryProtocol`, and `UserRepository` with `PersistentIdentifier`-returning APIs; remove the non-mainContext fallback in `AnalyticsViewModel.swift:27-29`.
- [ ] **Step 4 (Verify GREEN):** Run `SummaryRepositoryTests`, `UserRepositoryTests`, `AnalyticsViewModelTests`, and `ProfileViewModelTests` and verify all pass.

### Task 2 (P0-4): Complete `PrivacyInfo.xcprivacy` Declarations

**Files:**
- Modify: `PrivacyInfo.xcprivacy`
- Test: `FoodTrackerTests/PrivacyManifestTests.swift`

- [ ] **Step 1 (RED):** Add `testPrivacyManifestDeclaresFileTimestampReasonAndDeviceID` to `PrivacyManifestTests.swift` checking `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`) and `NSPrivacyCollectedDataTypeDeviceID`.
- [ ] **Step 2 (Verify RED):** Run `PrivacyManifestTests` and observe failure.
- [ ] **Step 3 (GREEN):** Update `PrivacyInfo.xcprivacy` to include `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`) and `NSPrivacyCollectedDataTypeDeviceID` (`Linked: false`, `Tracking: false`, `Purpose: NSPrivacyCollectedDataTypePurposeAppFunctionality`).
- [ ] **Step 4 (Verify GREEN):** Run `PrivacyManifestTests` and confirm PASS.

### Task 3 (P0-3): Enforce AI Consent Across `AINutritionService`, `AIMoodAdvicePopup`, and `NetworkManager`

**Files:**
- Modify: `FoodTracker/AI/AINutritionService.swift`
- Modify: `FoodTracker/Services/NetworkManager.swift`
- Modify: `FoodTracker/Views/Home/AIMoodAdvicePopup.swift`
- Modify: `FoodTracker/Views/Components/AIPhotoConsentSheet.swift`
- Modify: `FoodTracker/Views/Profile/ProfileView.swift` (`AIPhotoPrivacySettingsView`)
- Modify: `FoodTracker/AI/AICoachDashboardView.swift`
- Modify: `FoodTracker/AI/AICoachChatView.swift`
- Modify: `FoodTracker/App/AIChefStudioView.swift`
- Modify: `FoodTracker/Views/SmartBuilder/SmartPlanBuilderFlow.swift`
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift`
- Test: `FoodTrackerTests/VertexAIManagerTests.swift`, `FoodTrackerTests/NetworkManagerTests.swift`, `FoodTrackerTests/AICoachViewModelTests.swift`

- [ ] **Step 1 (RED):** Add failing tests:
  - `VertexAIManagerTests.testAINutritionServiceBlocksNetworkWhenConsentNotGranted`
  - `NetworkManagerTests.testSearchSkipsAIFallbackWhenConsentNotGranted`
  - `AIPhotoConsentTests.testMoodAdviceAutoFetchDecisionRequiresConsent`
- [ ] **Step 2 (Verify RED):** Run `VertexAIManagerTests`, `NetworkManagerTests`, `AIPhotoConsentTests`.
- [ ] **Step 3 (GREEN):**
  - Add `consentProvider` to `AINutritionService` and enforce it in `fetchFromGemini` / `fetchRawTextFromGemini`.
  - Gate `NetworkManager` AI search fallback behind `aiFallbackConsentProvider` (defaulting to `AIPhotoConsentManager.shared.hasConsented`).
  - Gate `AIMoodAdvicePopup`'s `.task` auto-fetch behind `AIPhotoConsentManager.shared.hasConsented`; when unconsented, display offline `MoodAdviceBaseline` immediately with an explicit `"Personalize with AI"` CTA that presents `AIPhotoConsentSheet`.
  - Present `AIPhotoConsentSheet` on explicit AI triggers in `AICoachDashboardView`, `AICoachChatView`, `AIChefStudioView`, `SmartPlanBuilderFlow`, and `HomeDashboardView` (`generateRecipe`), and update `AIPhotoConsentSheet` & `AIPhotoPrivacySettingsView` copy to cover both AI Photos and Nutrition/Context Data.
  - Ensure `AICoachViewModelTests` & `VertexAIManagerTests` grant consent appropriately in isolated test setup/teardown.
- [ ] **Step 4 (Verify GREEN):** Re-run `VertexAIManagerTests`, `NetworkManagerTests`, `AIPhotoConsentTests`, `AICoachViewModelTests`.

### Task 4 (P0-1): Medical Disclaimers, Clickable Scientific Citations & `diet.contraindications` + 7-Lang Localization

**Files:**
- Create: `FoodTracker/Views/Components/NutritionMethodologyDisclaimerView.swift`
- Modify: `FoodTracker/Views/Onboarding/SwissBento/SwissBentoOnboardingFlow.swift`
- Modify: `FoodTracker/Views/Goals/GoalsTabView.swift`
- Modify: `FoodTracker/Views/Profile/ProfileView.swift`
- Modify: `FoodTracker/Views/FastingDashboardView.swift`
- Modify: `FoodTracker/Views/Profile/AnalyticsDashboardView.swift`
- Modify: `FoodTracker/Views/Foods/SuperFoodsView.swift`
- Modify: `FoodTracker/Views/SmartBuilder/WeeklyPlanOverview.swift`
- Modify: `FoodTracker/Views/Home/AIMoodAdvicePopup.swift`
- Modify: `FoodTracker/Views/Components/BeforeAfterView.swift`
- Modify: `Localizable.xcstrings`
- Test: `FoodTrackerTests/FoodTrackerTests.swift`

- [ ] **Step 1 (RED):** Add tests in `FoodTrackerTests.swift` verifying:
  - `MedicalCitationCatalog` contains valid HTTPS URLs for Mifflin-St Jeor, WHO BMI, USDA Dietary Guidelines, NIH ODS, and NEJM Intermittent Fasting.
  - All `DietPlan.defaultDiets` expose non-empty `contraindications`.
  - All new Wave 1 disclaimer, citation, contraindication, and AI consent strings exist in `Localizable.xcstrings` with non-empty translations across all 7 languages (`en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`).
- [ ] **Step 2 (Verify RED):** Run `FoodTrackerTests/FoodTrackerTests` and confirm failure.
- [ ] **Step 3 (GREEN):** Implement `NutritionMethodologyDisclaimerView.swift`, integrate across all target screens, render `diet.contraindications` in `PremiumDietDetailView` (`SuperFoodsView.swift`), and add all 7-language translations to `Localizable.xcstrings`.
- [ ] **Step 4 (Verify GREEN):** Run `FoodTrackerTests/FoodTrackerTests` and verify pass.

### Task 5 (P0-2): Updated Privacy Policy HTML (`docs/legal/Privacy Policy - FoodTracker.html`)

**Files:**
- Create: `docs/legal/Privacy Policy - FoodTracker.html`

- [ ] **Step 1:** Author `docs/legal/Privacy Policy - FoodTracker.html` preserving the live page's responsive CSS and updating Sections 1, 3, 4, 5, and 7 to accurately describe OpenRouter proxy processing with explicit AI consent & zero retention, Sign in with Apple / Google Sign-In, `foodDeleteAccount`, `X-Device-Install-ID`, FatSecret, OpenFoodFacts, and `iCloud.com.borisdev.FoodTracker2026`.
- [ ] **Step 2 (Final Verification):** Run full `FoodTrackerTests` (`xcodebuild test`), `FoodTrackerUITests` (`xcodebuild test`), and `functions/` (`npm test`).
