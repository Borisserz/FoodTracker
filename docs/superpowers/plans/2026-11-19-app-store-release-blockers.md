# App Store Release Blockers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the three App Store Review & release blockers identified in the audit: explicit third-party AI photo consent across all photo upload flows, `PrivacyInfo.xcprivacy`/`Info.plist` compliance fixes, and shared-ecosystem account deletion warning + Google session cleanup.

**Architecture:** Implement a dedicated `@Observable @MainActor` `AIPhotoConsentManager` backed by `UserDefaults` and reset via `LocalDataResetService`, a reusable `AIPhotoConsentSheet` modal + Settings privacy screen, pure testable `AccountDeletionDialogCopy` and `GIDSignIn` cleanup in `AuthManager`, and bundle-level validation tests for `PrivacyInfo.xcprivacy` and `Info.plist`. All new UI strings are localized in `Localizable.xcstrings` for all 7 supported languages (`en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`).

**Tech Stack:** Swift 5 / SwiftUI / Observation / SwiftData / XCTest (`FoodTrackerTests`, `FoodTrackerUITests`), Xcode 16 (`PBXFileSystemSynchronizedRootGroup` for `FoodTracker/`, explicit file references for `FoodTrackerTests/`), `Localizable.xcstrings`.

## Global Constraints

- Do NOT modify `WorkoutTracker` repository files.
- Preserve existing comments/docstrings unrelated to changes.
- Follow TDD strictly: write failing test -> observe failure -> write minimal implementation -> observe pass -> refactor.
- Verify with fresh `xcodebuild test` runs for both `FoodTrackerTests` and `FoodTrackerUITests` and `npm test` in `functions/`.

---

### Task 1: `AIPhotoConsentManager` + `LocalDataResetService` Integration

**Files:**
- Create: `FoodTracker/Services/AIPhotoConsentManager.swift`
- Modify: `FoodTracker/Services/LocalDataResetService.swift:6-81`
- Create: `FoodTrackerTests/AIPhotoConsentTests.swift`
- Modify: `FoodTracker.xcodeproj/project.pbxproj` (register `AIPhotoConsentTests.swift` in `FoodTrackerTests` target)

**Interfaces:**
- Produces: `AIPhotoConsentManager` (`shared`, `defaultsKey`, `init(defaults:)`, `hasConsented: Bool`, `grantConsent()`, `revokeConsent()`, `syncFromDefaults()`).

- [ ] **Step 1: Register `AIPhotoConsentTests.swift` in `FoodTracker.xcodeproj/project.pbxproj` and write failing tests**

```swift
import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class AIPhotoConsentTests: XCTestCase {

    private var suiteName: String!
    private var isolatedDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "AIPhotoConsentTests.\(UUID().uuidString)"
        isolatedDefaults = UserDefaults(suiteName: suiteName)!
        isolatedDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        isolatedDefaults.removePersistentDomain(forName: suiteName)
        isolatedDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testConsentDefaultsToFalseAndPersistsAcrossInstances() {
        let manager = AIPhotoConsentManager(defaults: isolatedDefaults)
        XCTAssertFalse(manager.hasConsented)

        manager.grantConsent()
        XCTAssertTrue(manager.hasConsented)
        XCTAssertTrue(isolatedDefaults.bool(forKey: AIPhotoConsentManager.defaultsKey))

        let reloaded = AIPhotoConsentManager(defaults: isolatedDefaults)
        XCTAssertTrue(reloaded.hasConsented)
    }

    func testRevokeConsentClearsPersistedFlag() {
        let manager = AIPhotoConsentManager(defaults: isolatedDefaults)
        manager.grantConsent()
        XCTAssertTrue(manager.hasConsented)

        manager.revokeConsent()
        XCTAssertFalse(manager.hasConsented)
        XCTAssertFalse(isolatedDefaults.bool(forKey: AIPhotoConsentManager.defaultsKey))
    }

    func testLocalDataResetServiceClearsConsentKeyAndSyncsManager() throws {
        let schema = Schema(SharedModelContainer.appModelTypes)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])

        let manager = AIPhotoConsentManager(defaults: isolatedDefaults)
        manager.grantConsent()
        XCTAssertTrue(isolatedDefaults.bool(forKey: AIPhotoConsentManager.defaultsKey))

        LocalDataResetService.wipeAllData(in: container.mainContext, defaults: isolatedDefaults)
        manager.syncFromDefaults()

        XCTAssertNil(isolatedDefaults.object(forKey: AIPhotoConsentManager.defaultsKey))
        XCTAssertFalse(manager.hasConsented)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,id=1780CCC3-3973-4A1C-A6F7-10EA666DACC7' -only-testing:FoodTrackerTests/AIPhotoConsentTests`
Expected: FAIL to compile (`cannot find 'AIPhotoConsentManager' in scope`).

- [ ] **Step 3: Implement `FoodTracker/Services/AIPhotoConsentManager.swift` and update `LocalDataResetService.swift`**

```swift
import Foundation
import Observation

/// Tracks explicit user consent before sending photos to third-party AI vision providers (OpenRouter).
@Observable
@MainActor
final class AIPhotoConsentManager {
    static let shared = AIPhotoConsentManager()
    nonisolated static let defaultsKey = "aiPhotoThirdPartyConsentGranted_v1"

    private let defaults: UserDefaults
    private(set) var hasConsented: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasConsented = defaults.bool(forKey: Self.defaultsKey)
    }

    func grantConsent() {
        defaults.set(true, forKey: Self.defaultsKey)
        hasConsented = true
    }

    func revokeConsent() {
        defaults.set(false, forKey: Self.defaultsKey)
        hasConsented = false
    }

    func syncFromDefaults() {
        hasConsented = defaults.bool(forKey: Self.defaultsKey)
    }
}
```

In `FoodTracker/Services/LocalDataResetService.swift`:
- Add `AIPhotoConsentManager.defaultsKey` to `onboardingAndFeatureDefaultsKeys`.
- Inside `if defaults === UserDefaults.standard { ... }`, call `AIPhotoConsentManager.shared.syncFromDefaults()`.

- [ ] **Step 4: Run `AIPhotoConsentTests` to verify it passes**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,id=1780CCC3-3973-4A1C-A6F7-10EA666DACC7' -only-testing:FoodTrackerTests/AIPhotoConsentTests`
Expected: PASS (`3 tests, 0 failures`).

---

### Task 2: `PrivacyInfo.xcprivacy` & `Info.plist` App Store Compliance

**Files:**
- Modify: `PrivacyInfo.xcprivacy:60-120`
- Modify: `FoodTracker/Info.plist:34-41`
- Create: `FoodTrackerTests/PrivacyManifestTests.swift`
- Modify: `FoodTracker.xcodeproj/project.pbxproj` (register `PrivacyManifestTests.swift`)

- [ ] **Step 1: Register `PrivacyManifestTests.swift` in `project.pbxproj` and write failing bundle compliance tests**

```swift
import XCTest
@testable import FoodTracker

final class PrivacyManifestTests: XCTestCase {

    func testPrivacyManifestUsesValidPhotosAndFitnessKeys() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let collected = try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        let types = collected.compactMap { $0["NSPrivacyCollectedDataType"] as? String }

        XCTAssertTrue(types.contains("NSPrivacyCollectedDataTypePhotosOrVideos"))
        XCTAssertFalse(types.contains("NSPrivacyCollectedDataTypePhotosorVideos"))
        XCTAssertTrue(types.contains("NSPrivacyCollectedDataTypeFitness"))
    }

    func testInfoPlistDoesNotDeclareUnusedRemoteNotificationBackgroundMode() {
        let modes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") as? [String] ?? []
        XCTAssertFalse(modes.contains("remote-notification"))
    }
}
```

- [ ] **Step 2: Run `PrivacyManifestTests` to verify it fails**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,id=1780CCC3-3973-4A1C-A6F7-10EA666DACC7' -only-testing:FoodTrackerTests/PrivacyManifestTests`
Expected: FAIL (`PhotosOrVideos` missing, `Fitness` missing, `remote-notification` present).

- [ ] **Step 3: Fix `PrivacyInfo.xcprivacy` and `FoodTracker/Info.plist`**
- In `PrivacyInfo.xcprivacy`: change `NSPrivacyCollectedDataTypePhotosorVideos` -> `NSPrivacyCollectedDataTypePhotosOrVideos` and add `NSPrivacyCollectedDataTypeFitness` dictionary (`Linked = true`, `Tracking = false`, `Purposes = ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]`).
- In `FoodTracker/Info.plist`: remove `UIBackgroundModes` (`remote-notification`).

- [ ] **Step 4: Run `PrivacyManifestTests` to verify it passes**

Expected: PASS (`2 tests, 0 failures`).

---

### Task 3: Shared-Auth Account Deletion Warning & Google Session Cleanup

**Files:**
- Modify: `FoodTracker/Auth/AuthManager.swift:1-140`
- Modify: `FoodTracker/Views/Profile/ProfileView.swift:721-754`
- Modify: `FoodTrackerTests/SocialAuthServiceTests.swift`

**Interfaces:**
- Produces: `AccountDeletionDialogCopy.confirmationMessage(isAnonymous: Bool) -> String`
- Modifies: `AuthManager.deleteCurrentUser(userProvider:googleSignOut:)` and `AuthManager.runDeletionSequence(reauthenticate:deleteAccount:clearGoogleSession:revokeAppleToken:)`

- [ ] **Step 1: Add failing tests to `FoodTrackerTests/SocialAuthServiceTests.swift`**

Add tests verifying:
1. `AccountDeletionDialogCopy.confirmationMessage(isAnonymous: false)` returns non-empty copy mentioning `WorkoutTracker` / shared ecosystem account, distinct from `AccountDeletionDialogCopy.confirmationMessage(isAnonymous: true)`.
2. `AuthManager.runDeletionSequence` clears Google Sign-In session only after `deleteAccount` succeeds, and does NOT clear it if `deleteAccount` throws.
3. `AuthManager.deleteCurrentUser` accepts injectable `googleSignOut` and does not invoke it when `userProvider` returns `nil`.

- [ ] **Step 2: Run `SocialAuthServiceTests` to verify it fails**

Expected: FAIL to compile (`cannot find 'AccountDeletionDialogCopy' in scope`).

- [ ] **Step 3: Implement `AccountDeletionDialogCopy` & `googleSignOut` cleanup in `AuthManager.swift` and wire into `ProfileView.swift`**
- Import `GoogleSignIn` in `AuthManager.swift`.
- Add `enum AccountDeletionDialogCopy` with `static func confirmationMessage(isAnonymous: Bool) -> String`.
- Update `AuthManager.deleteCurrentUser` to accept `googleSignOut: @MainActor () -> Void = { GIDSignIn.sharedInstance.signOut() }` and invoke `googleSignOut()` right after `try? Auth.auth().signOut()`.
- Update `AuthManager.runDeletionSequence` to accept `clearGoogleSession: () -> Void = {}` (or keep default no-op when called directly, and invoke after `try await deleteAccount()`).
- Update `ProfileView.swift` (`AccountSettingsView`) `.confirmationDialog` message to `Text(AccountDeletionDialogCopy.confirmationMessage(isAnonymous: authManager.isAnonymous))`.

- [ ] **Step 4: Run `SocialAuthServiceTests` to verify it passes**

Expected: PASS (all tests in `SocialAuthServiceTests`).

---

### Task 4: `AIPhotoConsentSheet`, Gating in All 3 Photo Flows, Settings Privacy Screen, and 7-Language Localization

**Files:**
- Create: `FoodTracker/Views/Components/AIPhotoConsentSheet.swift`
- Modify: `FoodTracker/Scan/SmartScannerView.swift`
- Modify: `FoodTracker/App/AIChefStudioView.swift:1384-1624`
- Modify: `FoodTracker/Views/Components/BeforeAfterView.swift:357-401,520-590`
- Modify: `FoodTracker/Views/Profile/ProfileView.swift` (`SettingsView` + new `AIPhotoPrivacySettingsView`)
- Modify: `Localizable.xcstrings` (all 7 languages: `en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`)

- [ ] **Step 1: Write `AIPhotoConsentSheet.swift`**
  - Reusable SwiftUI modal disclosing photo downsampling, transmission via encrypted HTTPS through FoodTracker's proxy to **OpenRouter** and third-party AI vision models, transient non-retention (`data_collection: deny`), and revocability in Settings.
  - Exposes `"Allow & Analyze"` (calls `consentManager.grantConsent()`, dismisses, invokes `onAllow`) and `"Not Now"` (dismisses, invokes `onDecline`).

- [ ] **Step 2: Gate `SmartScannerView`, `AICameraScannerView`, and `BeforeAfterView`**
  - `SmartScannerView`: introduce `PendingPhotoConsentRequest` and `routeScannedPhoto(_:mode:)` called by camera capture and `PhotosPicker` (barcode `.barcode` mode unaffected); on decline, clear `cameraManager.capturedImage` and `pendingPhotoConsentRequest`.
  - `AICameraScannerView`: check `AIPhotoConsentManager.shared.hasConsented` before `evaluateCookingStep`; on decline, call `resetForRetry()`.
  - `BeforeAfterView`: check `AIPhotoConsentManager.shared.hasConsented` inside `triggerAnalysis(force:)` before `analyzeBeforeAfterPhotos`; on allow, re-run `triggerAnalysis(force: true)`.

- [ ] **Step 3: Add `AI Photo Privacy` row & `AIPhotoPrivacySettingsView` in `SettingsView` (`ProfileView.swift`)**
  - Add row showing `AIPhotoConsentManager.shared.hasConsented ? String(localized: "Enabled") : String(localized: "Off")` and toggle screen with full third-party disclosure.

- [ ] **Step 4: Localize all new strings across all 7 languages in `Localizable.xcstrings`**
  - Populate `en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT` entries and verify valid JSON + no missing keys.

- [ ] **Step 5: Run full verification suite**
  - `cd functions && npm test` (expect 32/32 pass)
  - `xcodebuild test ... -only-testing:FoodTrackerTests` (expect all pass, 0 failures)
  - `xcodebuild test ... -only-testing:FoodTrackerUITests` (expect 2/2 pass, 0 failures)
