# FoodTracker App Store Release Blockers — Design

**Date:** 2026-11-19
**Scope:** Point 1 release & App Store Review blockers in `FoodTracker` (`SmartScannerView`, `AICameraScannerView`, `BeforeAfterView`, `ProfileView`, `AuthManager`, `LocalDataResetService`, `PrivacyInfo.xcprivacy`, `Info.plist`, and `Localizable.xcstrings`), without modifying `WorkoutTracker`.

## Goals

1. **Explicit AI Photo Consent (Guidelines 5.1.1 / 5.1.2):** Gate all photo-to-AI upload paths (`SmartScannerView`, `AICameraScannerView`, and `BeforeAfterView`) behind a persisted explicit user consent disclosure naming OpenRouter and third-party AI vision providers, with an in-Settings toggle to inspect or revoke consent anytime.
2. **Privacy Manifest & Info.plist Accuracy:** Fix the `NSPrivacyCollectedDataTypePhotosOrVideos` key casing typo and add `NSPrivacyCollectedDataTypeFitness` in `PrivacyInfo.xcprivacy`; remove unused `UIBackgroundModes: ["remote-notification"]` from `FoodTracker/Info.plist`.
3. **Ecosystem-Safe Account Deletion UX & Google Cleanup:** Warn registered (Apple/Google) users before deletion that their shared ecosystem account (including WorkoutTracker sign-in) will be deleted, and clear `GIDSignIn.sharedInstance` state during account deletion.

---

## Architecture & Component Design

### 1. Explicit AI Photo Processing Consent

#### Persistence & State (`FoodTracker/Services/AIPhotoConsentManager.swift`)
- `@Observable @MainActor final class AIPhotoConsentManager` with `static let shared = AIPhotoConsentManager()`.
- Accepts injectable `UserDefaults` (default `.standard`) and exposes:
  - `static let defaultsKey = "aiPhotoThirdPartyConsentGranted_v1"`
  - `private(set) var hasConsented: Bool` (kept synchronized with `defaults.bool(forKey: Self.defaultsKey)`)
  - `func grantConsent()` -> sets `true` in `defaults` and updates `hasConsented`.
  - `func revokeConsent()` -> sets `false` in `defaults` and updates `hasConsented`.
  - `func syncFromDefaults()` -> refreshes `hasConsented` after external resets (e.g., `LocalDataResetService.wipeAllData`).
- Register `AIPhotoConsentManager.defaultsKey` in `LocalDataResetService.onboardingAndFeatureDefaultsKeys` and call `AIPhotoConsentManager.shared.syncFromDefaults()` inside `if defaults === UserDefaults.standard` of `LocalDataResetService.wipeAllData` so wiping local data removes the key in any `UserDefaults` and synchronizes the shared singleton.

#### Consent Modal (`FoodTracker/Views/Components/AIPhotoConsentSheet.swift`)
- Reusable SwiftUI sheet (`AIPhotoConsentSheet`) accepting `onAllow: () -> Void` and `onDecline: () -> Void` (plus `interactiveDismissDisabled()` or treating sheet dismissal as decline so no upload occurs without explicit approval).
- Content (localized across all 7 languages: `en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`):
  - Title: `"AI Photo Analysis Consent"`
  - Clear explanation of what is sent: downsampled copies of meal, menu, cooking-step, or body-comparison photos only when you request analysis.
  - Explicit third-party recipient disclosure: sent over encrypted HTTPS via FoodTracker's proxy to **OpenRouter** and third-party AI vision providers to estimate nutrition or provide visual feedback.
  - Data handling note: photos are processed transiently and not retained for model training (`data_collection: deny`), and consent can be revoked anytime in **Settings → AI Photo Privacy**.
  - Primary CTA: `"Allow & Analyze"` -> calls `AIPhotoConsentManager.shared.grantConsent()`, dismisses, and executes `onAllow()`.
  - Secondary CTA: `"Not Now"` -> calls `onDecline()` and dismisses without uploading anything.

#### Call-Site Gating
1. **`SmartScannerView` (`FoodTracker/Scan/SmartScannerView.swift`):**
   - Barcode scanning (`.barcode` mode via on-device VisionKit `DataScannerViewController`) remains completely ungated and unaffected.
   - Hold `@State private var pendingPhotoConsentRequest: PendingPhotoConsentRequest?` where `PendingPhotoConsentRequest` captures `(image: UIImage, mode: ScanMode)`.
   - Extract a shared helper `routeScannedPhoto(_ image: UIImage, mode: ScanMode)` called by both `onChange(of: cameraManager.capturedImage)` and `onChange(of: selectedPhotoItem)`:
     - If `AIPhotoConsentManager.shared.hasConsented` is `true`, dispatch immediately to `analyzeMenuWithAI(image)` or `analyzeMealWithAI(image)`.
     - If `false`, store `pendingPhotoConsentRequest` and present `AIPhotoConsentSheet`.
     - On Allow: consume `pendingPhotoConsentRequest` and run the corresponding analysis.
     - On Decline / Dismiss: clear `pendingPhotoConsentRequest` and `cameraManager.capturedImage = nil` so the camera returns to ready state with zero network calls.
2. **`AICameraScannerView` (`FoodTracker/App/AIChefStudioView.swift`):**
   - Hold `@State private var pendingConsentImage: UIImage?` and `@State private var showPhotoConsentSheet = false`.
   - Inside `analyzeCapturedStepImage(_ image: UIImage)` (reached from both live camera capture and `PhotosPicker`), check `AIPhotoConsentManager.shared.hasConsented`:
     - If `false`, store `pendingConsentImage = image`, set `showPhotoConsentSheet = true`, and return before setting `isAnalyzing = true` or calling `VertexAIManager.shared.evaluateCookingStep`.
     - On Allow: clear `pendingConsentImage` and call `performStepEvaluation(image)`.
     - On Decline / Dismiss: call `resetForRetry()`.
3. **`BeforeAfterView` (`FoodTracker/Views/Components/BeforeAfterView.swift`):**
   - Preserve the existing local-only persistence (`BeforeAfterStorage`) and explicit `"Analyze Transformation with AI"` button.
   - Inside `triggerAnalysis(force:)`, before setting `isAnalyzing = true` or calling `VertexAIManager.shared.analyzeBeforeAfterPhotos`, check `AIPhotoConsentManager.shared.hasConsented`:
     - If `false`, set `showPhotoConsentSheet = true` and return.
     - On Allow: re-invoke `triggerAnalysis(force: true)` cleanly now that `hasConsented == true`.
     - On Decline / Dismiss: leave local Before/After photos untouched with zero network calls.

#### Settings Toggle (`FoodTracker/Views/Profile/ProfileView.swift`)
- Add a row/toggle in `SettingsView` (`"AI Photo Privacy"`) backed by `AIPhotoConsentManager.shared`:
  - Shows current state (`Enabled` / `Off`) and opens a dedicated `AIPhotoPrivacySettingsView` with a `Toggle("Allow AI Photo Analysis", ...)` plus the same concise OpenRouter / third-party disclosure text so users can grant or revoke consent directly from Settings.

---

### 2. Privacy Manifest & Info.plist Compliance

1. **`PrivacyInfo.xcprivacy`:**
   - Replace `<string>NSPrivacyCollectedDataTypePhotosorVideos</string>` with `<string>NSPrivacyCollectedDataTypePhotosOrVideos</string>`.
   - Add an entry in `NSPrivacyCollectedDataTypes` for `<string>NSPrivacyCollectedDataTypeFitness</string>` (`NSPrivacyCollectedDataTypeLinked = true`, `NSPrivacyCollectedDataTypeTracking = false`, `NSPrivacyCollectedDataTypePurposes = ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]`) to accurately reflect `ActivityLog` workouts, `HKWorkout`, `stepCount`, and `activeEnergyBurned`.
2. **`FoodTracker/Info.plist`:**
   - Remove the `UIBackgroundModes` (`["remote-notification"]`) entry because FoodTracker neither calls `registerForRemoteNotifications()` nor carries an `aps-environment` entitlement. Local fasting/meal/water notifications via `UNUserNotificationCenter` and foreground/active-app SwiftData CloudKit sync continue operating normally without `UIBackgroundModes`.

---

### 3. Shared-Auth Account Deletion Warning & Google Session Cleanup

1. **Account Deletion Confirmation Copy (`FoodTracker/Views/Profile/ProfileView.swift` -> `AccountSettingsView`):**
   - Introduce a pure testable helper `AccountDeletionDialogCopy` (e.g., inside `AuthManager.swift`):
     - `static func confirmationMessage(isAnonymous: Bool) -> String`
     - When `isAnonymous == false` (Apple or Google account in shared `serzhanovich-ecosystem-ce700` Firebase Auth): returns localized warning explicitly stating that deleting the account permanently removes their shared ecosystem account (including WorkoutTracker sign-in) and clears all FoodTracker data from this device.
     - When `isAnonymous == true` (Guest): returns localized FoodTracker-scoped guest deletion warning stating that their guest session and all local meals, recipes, weight logs, and settings will be cleared from this device.
   - `AccountSettingsView` renders `Text(AccountDeletionDialogCopy.confirmationMessage(isAnonymous: authManager.isAnonymous))` inside `.confirmationDialog(...)`.
2. **Google Sign-In Session Cleanup (`FoodTracker/Auth/AuthManager.swift`):**
   - Add an injectable `googleSignOut: () -> Void` parameter (defaulting to `{ GIDSignIn.sharedInstance.signOut() }`) to `AuthManager.deleteCurrentUser(...)` so `deleteCurrentUser` clears the cached Google Sign-In session right after `Auth.auth().signOut()` (matching `SocialAuthService.signOut()`), and can be asserted in unit tests without needing live Firebase/Google credentials.

---

## Localization & Testing Scope

- **Localization:** Add all new strings to `Localizable.xcstrings` for all 7 locales (`en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`).
- **TDD Unit Tests (`FoodTrackerTests`):**
  - `AIPhotoConsentManagerTests`: default `false`, `grantConsent()` persists across fresh `UserDefaults` instances, `revokeConsent()` clears persistence, `LocalDataResetService.wipeAllData` removes the consent key and `syncFromDefaults()` updates in-memory state.
  - `SocialAuthServiceTests`: `AuthManager.deleteCurrentUser` / `runDeletionSequence` clears `GIDSignIn` session only after deletion succeeds, and `AccountDeletionDialogCopy.confirmationMessage(isAnonymous:)` returns distinct non-empty localized warnings for registered vs guest accounts.
  - `PrivacyManifestTests`: validates the compiled app bundle (`Bundle.main`) `PrivacyInfo.xcprivacy` contains `NSPrivacyCollectedDataTypePhotosOrVideos` (no `PhotosorVideos` typo) and `NSPrivacyCollectedDataTypeFitness`, and `Bundle.main.infoDictionary?["UIBackgroundModes"]` does not contain `"remote-notification"`.
- **Verification:** Run full `FoodTrackerTests`, `FoodTrackerUITests`, and `functions` `npm test` after completion.
