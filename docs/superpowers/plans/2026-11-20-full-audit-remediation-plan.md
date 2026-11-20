# FoodTracker Full Audit Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate every P0 App Store release blocker and resolve all P1–P3 security, backend, AI/scanner, HealthKit/Widget/WorkoutTracker sync, SwiftData, math, and UX findings from the full audit.

**Architecture:** Five sequential, independently testable waves ordered by release criticality: (1) App Store P0 blockers, legal HTML, and Privacy Manifest alignment; (2) Cloud Functions hardening, rate-limit integrity, and Firestore Rules; (3) HealthKit/App Group/Widget/Live Activity sync and SwiftData isolation; (4) AI schema/error propagation, OpenFoodFacts/FatSecret normalization, and camera thread-safety; (5) Nutrition math, fasting, recipes, UX polish, performance, and dead-code cleanup.

**Tech Stack:** Swift 5 / SwiftUI / SwiftData / HealthKit / WidgetKit / ActivityKit / VisionKit / AVFoundation / Firebase (Auth, App Check, Firestore, Remote Config, Crashlytics, Analytics) / Node.js 22 Cloud Functions v2 (`node --test`).

## Global Constraints

- Minimum iOS deployment target: `17.6`; Xcode scheme: `FoodTracker`, simulator test destination: `iPhone 17 Pro`.
- All changes must keep `cd functions && npm test`, `FoodTrackerTests`, `FoodTrackerUITests`, and Release builds (`FoodTracker` & `FoodTrackerWidgetExtension`) green.
- App Store guidelines: `1.4.1` (medical citations/warnings), `3.1.1` (100% free, no IAP/subscription language), `5.1.1(i)/5.1.2(i)` (explicit AI consent), `5.1.1(v)` (account deletion).
- Shared Firebase project `serzhanovich-ecosystem-ce700`: NEVER add a `firestore` rules deploy target to `firebase.json`, and preserve WorkoutTracker compatibility on `group.com.borisdev.WorkoutTracker`.
- Keep all existing strings localized across 7 languages (`en`, `ru`, `de`, `es`, `fr`, `it`, `pt-PT`) when adding or modifying user-facing copy in `Localizable.xcstrings`.

---

## Wave 1: App Store P0 Blockers, Legal HTML & Privacy Manifest

### Task 1: Add Production App Attest Entitlement to `FoodTracker`

**Files:**
- Modify: `FoodTracker/FoodTracker.entitlements:1-25`
- Verify: `FoodTracker.xcodeproj/project.pbxproj`
- Test: `FoodTrackerTests/PrivacyManifestTests.swift`

- [ ] **Step 1: Add App Attest production test check to `PrivacyManifestTests.swift`**

Read `FoodTrackerTests/PrivacyManifestTests.swift` and add a test verifying `FoodTracker/FoodTracker.entitlements` (or bundle entitlements check via project test) — wait: unit tests run inside the simulator host where entitlements are stripped unless bundled, so test via a Release archive/build check plus reading entitlements plist in unit tests if project path is only local. Instead, verify the exact plist key via `plutil` and `codesign`/`xcodebuild` in Step 3.

Add `com.apple.developer.devicecheck.appattest-environment` to `FoodTracker/FoodTracker.entitlements`:

```xml
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
	<key>com.apple.developer.devicecheck.appattest-environment</key>
	<string>production</string>
	<key>com.apple.developer.healthkit</key>
```

- [ ] **Step 2: Validate entitlements plist and Release build**

Run:
```bash
plutil -lint FoodTracker/FoodTracker.entitlements
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project FoodTracker.xcodeproj -scheme FoodTracker -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```
Expected: `FoodTracker.entitlements: OK` and `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual Apple Developer / Firebase Console verification note**

Confirm App ID `com.borisdev.FoodTracker2026` has **App Attest** enabled in Apple Developer Portal and registered in Firebase Console → App Check (`1:667537183554:ios:00b48bad38f5be0d786edb`), removing any stale debug tokens.

- [ ] **Step 4: Commit**

```bash
git add FoodTracker/FoodTracker.entitlements
git commit -m "fix(security): enable App Attest production entitlement for Release builds"
```

---

### Task 2: Fix Broken Support URL and Reconcile Legal HTML Pages

**Files:**
- Modify: `FoodTracker/AppCore/Constants.swift:3-9`
- Modify: `docs/legal/Privacy Policy - FoodTracker.html:160-165`
- Modify: `docs/legal/Support - FoodTracker.html:32-34, 73-82`
- Modify: `docs/legal/Terms of Use - FoodTracker.html:32-34, 48-58, 97-102`
- Test: `FoodTrackerTests/PrivacyManifestTests.swift`

- [ ] **Step 1: Write failing test for `Constants.Legal` URLs**

Add to `FoodTrackerTests/PrivacyManifestTests.swift`:
```swift
func testLegalURLsEncodeValidFilenames() {
    XCTAssertEqual(
        Constants.Legal.supportURL.absoluteString,
        "https://borisserz.github.io/workouttracker-privacy/Support%20-%20FoodTracker.html"
    )
    XCTAssertEqual(
        Constants.Legal.privacyPolicyURL.absoluteString,
        "https://borisserz.github.io/workouttracker-privacy/Privacy%20Policy%20-%20FoodTracker.html"
    )
    XCTAssertEqual(
        Constants.Legal.eulaURL.absoluteString,
        "https://borisserz.github.io/workouttracker-privacy/Terms%20of%20Use%20-%20FoodTracker.html"
    )
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/PrivacyManifestTests/testLegalURLsEncodeValidFilenames
```
Expected: FAIL because `supportURL` currently contains `Support-%20FoodTracker.html`.

- [ ] **Step 3: Fix `Constants.swift` and update all three HTML pages**

In `FoodTracker/AppCore/Constants.swift:7`:
```swift
        static let supportURL = URL(string: "https://borisserz.github.io/workouttracker-privacy/Support%20-%20FoodTracker.html")!
```

In `docs/legal/Privacy Policy - FoodTracker.html:163`:
```html
<a href="Support - FoodTracker.html">Support</a>
```

In `docs/legal/Support - FoodTracker.html`:
- Update line 33: `<p class="muted">Last updated: 20 November 2026</p>`
- Update lines 74–75:
```html
<summary>What are the AI Coach and AI Chef features?</summary>
<p>The AI Coach provides proactive nutrition advice, while the AI Chef helps you discover recipes or estimate calories. After your explicit in-app consent, requests are routed over HTTPS through our authenticated backend proxy to OpenRouter and third-party AI model providers with data collection denied. Please avoid submitting unnecessary personal identifiers in AI prompts. See our <a href="Privacy Policy - FoodTracker.html">Privacy Policy</a> for details.</p>
```
- Update lines 79–80:
```html
<summary>How do I delete my data?</summary>
<p>You can permanently delete your account and app data inside the app under <strong>Settings (gear icon) → Account → Delete account</strong>. Private iCloud CloudKit records belong to your Apple ID and can be managed in iOS Settings → Apple Account → iCloud. This action cannot be undone.</p>
```

In `docs/legal/Terms of Use - FoodTracker.html`:
- Update line 33: `<p class="muted">Last updated: 20 November 2026</p>`
- Replace lines 48–57 with:
```html
<h2>2. Pricing &amp; Availability</h2>
<p>
FoodTracker is currently provided free of charge without paid subscriptions or in-app purchases. If optional paid features are introduced in a future update, separate terms and Apple App Store purchase disclosures will apply.
</p>
```
- Update line 100:
```html
<a href="Support - FoodTracker.html">Support</a>
```

- [ ] **Step 4: Run test to verify it passes and commit**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/PrivacyManifestTests
git add FoodTracker/AppCore/Constants.swift "docs/legal/Privacy Policy - FoodTracker.html" "docs/legal/Support - FoodTracker.html" "docs/legal/Terms of Use - FoodTracker.html" FoodTrackerTests/PrivacyManifestTests.swift
git commit -m "fix(legal): fix supportURL encoding and align legal HTML disclosures"
```
Expected: PASS. (Remember to push updated `docs/legal/*.html` to GitHub Pages `workouttracker-privacy`.)

---

### Task 3: Align Firebase Analytics Configuration & `PrivacyInfo.xcprivacy`

**Files:**
- Modify: `PrivacyInfo.xcprivacy:120-131`
- Modify: `FoodTracker/GoogleService-Info.plist:23-24` (if Analytics is intended; **OR** remove `Analytics.logEvent` in `FoodTracker/Services/TrackingManager.swift:52-60` and `NSPrivacyCollectedDataTypeProductInteraction` in `PrivacyInfo.xcprivacy:97-107` if Crashlytics-only is chosen)

> **Decision note:** Keeping `FirebaseAnalyticsCore` disabled (`IS_ANALYTICS_ENABLED = false`) and using Crashlytics-only avoids unneeded App Store Nutrition Label disclosures, **or** setting `IS_ANALYTICS_ENABLED = true` activates `TrackingManager` event funnels. Below implements the cleanest **Analytics Enabled (`ProductInteraction` only, removing unused `PerformanceData`)** path — swap to Crashlytics-only if preferred.

- [ ] **Step 1: Remove unused `NSPrivacyCollectedDataTypePerformanceData` from `PrivacyInfo.xcprivacy`**

Remove lines 120–131 (`NSPrivacyCollectedDataTypePerformanceData` dict) from `PrivacyInfo.xcprivacy` since `FirebasePerformance` is not linked in `FoodTracker.xcodeproj`.

- [ ] **Step 2: Enable `IS_ANALYTICS_ENABLED` in `FoodTracker/GoogleService-Info.plist`**

In `FoodTracker/GoogleService-Info.plist:23-24`:
```xml
	<key>IS_ANALYTICS_ENABLED</key>
	<true></true>
```

- [ ] **Step 3: Validate plist & run `PrivacyManifestTests`**

Run:
```bash
plutil -lint PrivacyInfo.xcprivacy FoodTracker/GoogleService-Info.plist
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/PrivacyManifestTests
```
Expected: `OK` and PASS.

- [ ] **Step 4: Commit**

```bash
git add PrivacyInfo.xcprivacy FoodTracker/GoogleService-Info.plist
git commit -m "fix(privacy): align PrivacyInfo.xcprivacy and GoogleService-Info analytics flags"
```

---

### Task 4: Add Guideline 1.4.1 Citations on AI Coach Dashboard & Prolonged Fasting Warning

**Files:**
- Modify: `FoodTracker/AI/AICoachDashboardView.swift:168-175`
- Modify: `FoodTracker/Views/FastingDashboardView.swift:119-128, 338, 434-439`
- Modify: `Localizable.xcstrings` (if any new key is introduced)

- [ ] **Step 1: Replace plain disclaimer `Text` with `NutritionMethodologyDisclaimerView` in `AICoachDashboardView.swift:168-175`**

```swift
                                NutritionMethodologyDisclaimerView(
                                    citations: [.dietaryGuidelines, .bmrAndTdee],
                                    compact: true
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
```

- [ ] **Step 2: Localize category badge and show safety warning for >= 24h custom fasts in `FastingDashboardView.swift`**

1. At `FoodTracker/Views/FastingDashboardView.swift:338`:
```swift
                                Text(plan.category.localizedName.uppercased())
```
2. At `FoodTracker/Views/FastingDashboardView.swift:434-438`, trigger `ExpertSafetyWarning` by duration as well as category:
```swift
                        if plan.category == .beginner {
                            AllowedDrinksSection(color: plan.color)
                        } else if plan.category == .expert || plan.fastingHours >= 24 {
                            ExpertSafetyWarning(color: plan.color)
                        }
```
3. In `CustomFastingDurationCard` (`FoodTracker/Views/FastingDashboardView.swift` where `customHours` is started), if `customHours >= 24`, require confirmation alert before calling `FastingManager.shared.startCustomFast(hours: customHours)` displaying electrolyte + medical contraindication guidance (`"Extended fasts (24h+) deplete electrolytes and are not suitable if pregnant, diabetic, underage, or with a history of eating disorders."`). Add localization entries for all 7 languages in `Localizable.xcstrings`.

- [ ] **Step 3: Build & run unit tests**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/FastingManagerTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add FoodTracker/AI/AICoachDashboardView.swift FoodTracker/Views/FastingDashboardView.swift Localizable.xcstrings
git commit -m "fix(compliance): add medical citations to AI coach and safety warning for 24h+ custom fasts"
```

---

## Wave 2: Backend Hardening, OpenRouter Smoke Verification & Firestore Rules

### Task 5: Verify OpenRouter `:free` ZDR (`data_collection: "deny"`) Compatibility

**Files:**
- Inspect/Run: `functions/smoke_openrouter.js`
- Modify (only if smoke identifies failing models): `functions/index.js:58-82, 84-100`

- [ ] **Step 1: Run `smoke_openrouter.js` against live OpenRouter key**

Run:
```bash
cd functions && npm run smoke
```
Expected: Observe pass/fail rate per model in `TEXT_MODEL_CHAIN` and `VISION_MODEL_CHAIN` with `provider: { data_collection: "deny" }`.

- [ ] **Step 2: Prune dead/non-ZDR `:free` models or adjust fallback chain**

If any model consistently returns `404 No endpoints found matching your data policy` or `404 No endpoints available`, remove or reorder it in `TEXT_MODEL_CHAIN` / `VISION_MODEL_CHAIN` (`functions/index.js:58-82`) and keep `TEXT_MODEL_CHAIN` / `VISION_MODEL_CHAIN` test assertions in `functions/test_proxy.js` updated.

- [ ] **Step 3: Run backend tests**

Run: `cd functions && npm test`
Expected: All tests PASS.

- [ ] **Step 4: Commit (if `functions/index.js` changed)**

```bash
git add functions/index.js functions/test_proxy.js
git commit -m "fix(backend): prune failing OpenRouter models under data_collection deny"
```

---

### Task 6: Harden `functions/index.js` Quotas, Auth Provider Check, Empty JSON Rejections & `systemInstruction`

**Files:**
- Modify: `functions/index.js:247-278, 864-874, 930-939, 1204-1245, 1731-1735`
- Test: `functions/test_proxy.js`

- [ ] **Step 1: Write failing tests in `functions/test_proxy.js`**

Add 4 tests covering:
1. `verifyFirebaseUser` with `requireRecentAuthSec: 300` rejects a token whose `firebase.sign_in_provider` is missing/empty when `auth_time` is older than 300s.
2. `deleteFoodAccountData` preserves `food_ai_usage/{uid}` and `food_search_usage/{uid}` (or keeps device quota intact without resetting anonymous quota abuse) — wait: for `foodDeleteAccount` GDPR/App Store 5.1.1(v) deletion, UID-keyed docs MUST be deleted; instead, enforce `deviceLimit` independently of UID deletion and tighten anonymous `deviceLimit` in `foodAiProxy` / `foodSearchProxy`! Let's write a test verifying anonymous device cap cannot exceed `120/week` (2x anonymous user cap instead of `400`) and `ipLimit` cannot be bypassed by rotating `X-Device-Install-ID`.
3. `callOpenRouterText` treats `"{}"` or `"[]"` when `expectJSON === true` as an invalid empty JSON payload and falls back to the next model / refunds quota.
4. `validateAiProxyBody` rejects non-JSON/unrecognized `responseMimeType` and trims/caps `systemInstruction` + enforces server food-domain system prefix or schema bounds.

```javascript
test("verifyFirebaseUser enforces recent auth_time even when sign_in_provider claim is missing", async () => {
  const staleSec = Math.floor(Date.now() / 1000) - 600;
  const req = { header: (k) => (k === "Authorization" ? "Bearer tok" : "") };
  let statusCode = 0;
  let body = null;
  const res = {
    status(c) { statusCode = c; return this; },
    json(b) { body = b; return this; },
  };
  const uid = await _test.verifyFirebaseUser(
    req,
    res,
    async () => ({ uid: "u1", auth_time: staleSec, firebase: {} }),
    { requireRecentAuthSec: 300 }
  );
  assert.equal(uid, null);
  assert.equal(statusCode, 401);
  assert.equal(body.error, "requires_recent_login");
});

test("isMeaningfulJsonOutput rejects empty object and empty array", () => {
  assert.equal(_test.isMeaningfulJsonOutput("{}"), false);
  assert.equal(_test.isMeaningfulJsonOutput("[]"), false);
  assert.equal(_test.isMeaningfulJsonOutput('{"mealName":"Oats"}'), true);
  assert.equal(_test.isMeaningfulJsonOutput('[{"name":"Apple"}]'), true);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd functions && npm test`
Expected: FAIL (`_test.isMeaningfulJsonOutput` undefined, `verifyFirebaseUser` skips check when provider empty).

- [ ] **Step 3: Implement hardening in `functions/index.js`**

1. Add `isMeaningfulJsonOutput(text)` and call it in `callOpenRouterText` (`functions/index.js:864-874`):
```javascript
function isMeaningfulJsonOutput(text) {
  const parsed = JSON.parse(text);
  if (Array.isArray(parsed)) return parsed.length > 0;
  if (parsed && typeof parsed === "object") return Object.keys(parsed).length > 0;
  return false;
}
```
Inside `callOpenRouterText`:
```javascript
        if (expectJSON) {
          try {
            if (!isMeaningfulJsonOutput(outText)) {
              throw new Error("Empty JSON container");
            }
          } catch (e) {
            lastError = new Error(
              `Invalid JSON output from ${model}: ${e.message}`
            );
            console.warn(lastError.message);
            break;
          }
        }
```
2. Fix `verifyFirebaseUser` (`functions/index.js:932`):
```javascript
    if (requireRecentAuthSec > 0 && provider !== "anonymous") {
```
3. Tighten anonymous device cap in `resolveUserQuotaLimit` / `resolveDeviceQuotaLimit` (cap anonymous `deviceLimit` at `120` AI / `500` Search per week, preventing repeated delete-account resets from unlocking 400/week), validate `generationConfig.responseMimeType` against `["text/plain", "application/json"]`, and deduplicate `getFatSecretAccessToken` concurrent fetches with a shared `fatSecretTokenInFlight` promise + configurable `timeoutMs` (`boundedFatSecretTimeout()`). Also detect FatSecret auth mode from `process.env.FATSECRET_AUTH_MODE` or cache detected `oauth2` mode in memory after the first `error.code === 2/8` so subsequent requests skip the failing OAuth1 round-trip.

4. Export `isMeaningfulJsonOutput` in `_test` (`functions/index.js`).

- [ ] **Step 4: Run tests and verify pass**

Run: `cd functions && npm test`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add functions/index.js functions/test_proxy.js
git commit -m "fix(backend): reject empty JSON outputs, fix missing provider recent-auth bypass, harden quotas and FatSecret token locking"
```

---

### Task 7: Harden `firestore.rules` Against Storage Abuse in `shared_workouts.exercises` & Auth Client Handling

**Files:**
- Modify: `firestore.rules:101-104, 136-142, 163`
- Modify: `FoodTracker/Auth/SocialAuthService.swift:178-192, 199-204, 244-250`
- Test: `FoodTrackerTests/SocialAuthServiceTests.swift`

- [ ] **Step 1: Strengthen `firestore.rules` (and coordinate deploy to shared ecosystem repo)**

In `firestore.rules:101-104` and `136-142`:
```javascript
    function isApprovedWorkout(workoutId) {
      let path = /databases/$(database)/documents/shared_workouts/$(workoutId);
      return exists(path) && get(path).data.status == "approved";
    }
```
For `exercises` (`136-142`), validate bounded structure on `exercises[0]` (map size `<= 20` keys) and reject oversized `workoutId` path segments (`!data.workoutId.matches('.*(/|\\.\\.).*')`). *(Note: Firestore CEL cannot iterate dynamic lists of length 100 without a Cloud Function write endpoint — document moving `shared_workouts` creation behind a Cloud Function if strict per-item validation for `exercises[1..99]` is needed.)*

- [ ] **Step 2: Fix `SocialAuthService.signOut()` and `.accountExistsWithDifferentCredential` handling**

1. In `FoodTracker/Auth/SocialAuthService.swift:181`, handle `.accountExistsWithDifferentCredential` with a localized user-facing error (`AuthError.accountExistsWithOtherProvider`) instead of surfacing raw Firebase error codes.
2. When `signOut()` runs from `AccountSettingsView` (`ProfileView.swift:776`), clear user-scoped local caches/state via `LocalDataResetService.wipeAllData(in: context)` (or prompt user before switching accounts so local SwiftData from Account A does not leak to Account B on a shared device).
3. Add a unit test in `FoodTrackerTests/SocialAuthServiceTests.swift` for `AuthError` mapping and `signInWithGoogle` re-entrancy guard (`isGoogleSignInInFlight`).

- [ ] **Step 3: Run auth unit tests**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/SocialAuthServiceTests
```
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add firestore.rules FoodTracker/Auth/SocialAuthService.swift FoodTracker/Views/Profile/ProfileView.swift FoodTrackerTests/SocialAuthServiceTests.swift Localizable.xcstrings
git commit -m "fix(auth,rules): harden firestore rules validation, handle provider collision and wipe local state on signOut"
```

---

## Wave 3: HealthKit, WorkoutTracker, Widgets, Live Activities & SwiftData Integrity

### Task 8: Fix `AddMealView` + `EditableFoodDraft` Mutation & HealthKit Sync Gap

**Files:**
- Modify: `FoodTracker/Views/AddMealView.swift:78-94, 451-455`
- Modify: `FoodTracker/Utils/NutritionMath.swift:85-106`
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift:2449-2457`
- Test: `FoodTrackerTests/DataModelsTests.swift`

- [ ] **Step 1: Write failing test in `DataModelsTests.swift`**

Verify that creating an `EditableFoodDraft` from a catalog/custom template `FoodItem` does not mutate the original template `FoodItem` when `makeFoodItem()` is used, and that `User.deduplicatedPrimary` is not invoked inside view body rendering.

```swift
func testEditableFoodDraftTemplateDoesNotMutateSourceFoodItem() {
    let customTemplate = FoodItem(name: "Homemade Granola", weight: 100, calories: 450, protein: 12, fats: 18, carbs: 60)
    var draft = EditableFoodDraft(food: customTemplate, isNewMealEntry: true)
    draft.weight = 50
    let logged = draft.makeFoodItem()

    XCTAssertEqual(customTemplate.weight, 100)
    XCTAssertEqual(customTemplate.calories, 450)
    XCTAssertEqual(logged.weight, 50)
    XCTAssertEqual(logged.calories, 225)
    XCTAssertNil(draft.existingItem)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/DataModelsTests/testEditableFoodDraftTemplateDoesNotMutateSourceFoodItem
```
Expected: FAIL (`isNewMealEntry` parameter does not exist).

- [ ] **Step 3: Implement non-mutating template draft & remove `ModelContext` write from `HomeDashboardView.body`**

1. In `FoodTracker/Utils/NutritionMath.swift:85-106`, add `isNewMealEntry: Bool = false` to `EditableFoodDraft.init(food:isNewMealEntry:)`:
```swift
    init(food: FoodItem, isNewMealEntry: Bool = false) {
        self.init(
            id: isNewMealEntry ? UUID() : food.id,
            existingItem: isNewMealEntry ? nil : food,
            name: food.name,
            ...
```
2. In `FoodTracker/Views/AddMealView.swift:452`, pass `isNewMealEntry: true`:
```swift
                    let newDrafts = newItems.map { EditableFoodDraft(food: $0, isNewMealEntry: true) }
```
Now newly added foods always insert fresh `FoodItem`s, preserve the user's custom food database intact, and enter `insertedItems` so `HealthKitManager.shared.saveDietaryEnergy` syncs them!
3. In `FoodTracker/Views/Home/HomeDashboardView.swift:2449-2451`, replace `User.deduplicatedPrimary(in: context)` inside `.fullScreenCover` body with read-only `currentUser` (`users.first` or `.task`-deduplicated state).

- [ ] **Step 4: Run tests to verify pass and commit**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/DataModelsTests
git add FoodTracker/Utils/NutritionMath.swift FoodTracker/Views/AddMealView.swift FoodTracker/Views/Home/HomeDashboardView.swift FoodTrackerTests/DataModelsTests.swift
git commit -m "fix(swiftdata): prevent template FoodItem mutation in AddMealView and remove ModelContext write in view body"
```
Expected: PASS.

---

### Task 9: Fix Pending Widget Water Loss, ActivityLog HealthKit Deletion, and Copied Meals Sync

**Files:**
- Modify: `FoodTracker/Models/DataModels.swift:274-289, 356-368, 392-437`
- Modify: `FoodTracker/Services/HealthKitManager.swift:329-360`
- Modify: `FoodTracker/Services/WorkoutSyncManager.swift:160-183`
- Modify: `FoodTracker/Views/Components/QuickActivityAddView.swift:179-213`
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift:503-527, 1278-1292, 1916-1938`
- Test: `FoodTrackerTests/DataModelsTests.swift`, `FoodTrackerTests/FoodTrackerTests.swift`

- [ ] **Step 1: Write failing tests for peek/ack pending widget water and `ActivityLog` HK metadata**

In `FoodTrackerTests/FoodTrackerTests.swift`:
```swift
func testPeekPendingWidgetWaterDoesNotClearUntilAcknowledged() {
    let suiteName = "test.widget.water.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let today = Date()
    let key = WorkoutSyncManager.pendingHealthKitWaterEntriesKey(for: today)
    defaults.set([250.0, 300.0], forKey: key)

    let peeked = WorkoutSyncManager.shared.peekPendingWidgetWaterEntriesLiters(for: today, appGroupDefaults: defaults)
    XCTAssertEqual(peeked, [0.25, 0.30])
    XCTAssertEqual(defaults.array(forKey: key) as? [Double], [250.0, 300.0])

    WorkoutSyncManager.shared.acknowledgePendingWidgetWaterEntries(syncedIndices: [0], for: today, appGroupDefaults: defaults)
    let remaining = WorkoutSyncManager.shared.peekPendingWidgetWaterEntriesLiters(for: today, appGroupDefaults: defaults)
    XCTAssertEqual(remaining, [0.30])
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/FoodTrackerTests/testPeekPendingWidgetWaterDoesNotClearUntilAcknowledged
```
Expected: FAIL (`peekPendingWidgetWaterEntriesLiters` not defined).

- [ ] **Step 3: Implement peek/ack widget water, ActivityLog HK UUID deletion, and copied meal HK sync**

1. **`WorkoutSyncManager.swift`**: Add `peekPendingWidgetWaterEntriesLiters(for:appGroupDefaults:)` and `acknowledgePendingWidgetWaterEntries(syncedIndices:for:appGroupDefaults:)`. Update `HomeDashboardView.swift:503-527` to peek first, call `HealthKitManager.shared.saveWater`, and acknowledge ONLY the indices where `saveWater` returned a non-nil `UUID`.
2. **`DataModels.swift` (`ActivityLog`)**: Add `var healthKitWorkoutID: String?` and `var healthKitEnergySampleID: String?` (lightweight SwiftData additive schema change in `FoodTrackerSchemaV1`). Update `HealthKitManager.saveWorkout(...)` to return `(workoutID: String?, energySampleID: String?)`, store them on `ActivityLog` in `QuickActivityAddView.swift`, and add `HealthKitManager.deleteWorkoutAndEnergySamples(workoutID:energySampleID:caloriesFallback:date:)` called from `DailyLogDetailView.deleteActivity(_:)`.
3. **`DailySummary.copyMeal` / `copyDay`**: Return the newly inserted `[FoodItem]` (or call `HealthKitManager.shared.saveDietaryEnergy` for each copied item with `calories > 0` in `MealDetailView.copyCurrentMeal` and `DailyLogDetailView.copyDay` when `users.first?.isHealthKitEnabled == true`).

- [ ] **Step 4: Run tests and verify pass**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/FoodTrackerTests -only-testing:FoodTrackerTests/DataModelsTests
git add FoodTracker/Models/DataModels.swift FoodTracker/Services/HealthKitManager.swift FoodTracker/Services/WorkoutSyncManager.swift FoodTracker/Views/Components/QuickActivityAddView.swift FoodTracker/Views/Home/HomeDashboardView.swift FoodTrackerTests/FoodTrackerTests.swift FoodTrackerTests/DataModelsTests.swift
git commit -m "fix(healthkit): make widget water queue crash-safe, delete HK workouts on ActivityLog removal, sync copied meals"
```
Expected: PASS.

---

### Task 10: Fix App Group Water Reconciliation on Undo/Reset, Imperial Volume, Widget Privacy & Live Activity Races

**Files:**
- Modify: `FoodTracker/Views/Components/Motion/HydrationFlaskCardView.swift:224-254`
- Modify: `FoodTracker/Views/Profile/AnalyticsDashboardView.swift:923-954`
- Modify: `FoodTracker/Services/LocalDataResetService.swift:73`
- Modify: `FoodTracker/Services/WorkoutSyncManager.swift:402-414`
- Modify: `FoodTrackerWidgetExtension/WidgetIntents.swift:18-19`
- Modify: `FoodTrackerWidgetExtension/WidgetTimelineProvider.swift:76-142`
- Modify: `FoodTrackerWidgetExtension/WidgetViews.swift:167-203`
- Modify: `FoodTracker/Services/FastingLiveActivityManager.swift:151-224`
- Modify: `FoodTracker/Services/FastingManager.swift:266, 371-417`
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift:709-725`
- Test: `FoodTrackerTests/WidgetIntentStorageTests.swift`

- [ ] **Step 1: Write failing test for Imperial widget water volume consistency (`250.0 ml` vs `236.588 ml`) and reset behavior**

Check `FoodTrackerTests/FoodTrackerTests.swift` / `WidgetIntentStorageTests` and add test verifying `WorkoutSyncManager.clearLocalSyncMetadata` also resets today's `water_liters_YYYY-MM-DD` (or stores a reset watermark so wiped app doesn't immediately re-import old WorkoutTracker water) and that widget `AddWaterIntent` uses matching standard glass volume (`250.0` ml or `8.0 * 29.5735` consistently across both app and widget).

- [ ] **Step 2: Implement fixes across sync, widgets, and Live Activity**

1. **Undo Water Reconcile**: In `HydrationFlaskCardView.removeLastWaterEntry()` and `AnalyticsDashboardView.removeLastWater()`, track the delta removed (`-removedLiters`) or call `reconcileWaterWithOutcome` before overwriting `syncWater`, preserving any water logged in WorkoutTracker since last sync.
2. **Data Reset Water Re-Import Fix**: In `LocalDataResetService.wipeAllData`, write a `lastResetTimestamp` or update `wt_last_synced_water_YYYY-MM-DD` to match the existing `water_liters_YYYY-MM-DD` so `reconcileWaterWithOutcome` treats prior WorkoutTracker water as already seen rather than re-importing pre-wipe water!
3. **Imperial Glass Consistency**: Align `HydrationFlaskCardView` / `AnalyticsDashboardView` `+8 fl oz` and `AddWaterIntent` to use one shared constant (`NutritionMath.standardGlassMl(useMetric:)`: `useMetric ? 250.0 : 236.588`).
4. **Widget `placeholder(in:)` + `.privacySensitive()` + Localized `"g"`**: Make `WidgetTimelineProvider.placeholder(in:)` and `ShoppingListTimelineProvider.placeholder(in:)` return static sample entries without opening SwiftData; add `.privacySensitive()` to sensitive calorie/macro values in `WidgetViews.swift`; localize `"\(entry.protein)g"` via `LocalizedStringKey("\(entry.protein)g")` in `MacroRingsWidgetView`.
5. **Widget Deep Link Date Reset**: In `HomeDashboardContentView.handleWidgetScrollIfNeeded`, reset `selectedDate = Calendar.current.startOfDay(for: Date())` for `.hydration` / `.macros` / `.metabolic` widget URLs.
6. **Live Activity Serialization & Notification Category**: Serialize `FastingLiveActivityManager` `start`/`update`/`end` operations through a single serial async chain/actor or pending task queue so `endActivity` always runs after any in-flight `start`/`update`; register `UNNotificationCategory(identifier: FastingManager.fastingNotificationCategoryID, ...)` via `setNotificationCategories`.

- [ ] **Step 3: Run all unit tests & Release widget build**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project FoodTracker.xcodeproj -scheme FoodTrackerWidgetExtension -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```
Expected: All tests PASS and `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add FoodTracker/ FoodTrackerWidgetExtension/ FoodTrackerTests/
git commit -m "fix(sync,widgets): harden water undo/reset sync, widget placeholders/l10n, and Live Activity serialization"
```

---

## Wave 4: AI Proxy Client, Scanner, Camera & Nutrition API Normalization

### Task 11: Propagate `responseSchema`, Real AI Errors, and Fix `isGenerating` Cancellation Stuck State

**Files:**
- Modify: `FoodTracker/Services/GeminiProxyClient.swift:144-155, 220-260`
- Modify: `FoodTracker/Services/VertexAIManager.swift:274-385`
- Modify: `FoodTracker/AI/AICoachChatView.swift:280-308`
- Modify: `FoodTracker/Views/SmartBuilder/SmartPlanBuilderFlow.swift:397-426`
- Modify: `FoodTracker/App/AIChefStudioView.swift:496-524`
- Test: `FoodTrackerTests/GeminiProxyClientTests.swift`, `FoodTrackerTests/VertexAIManagerTests.swift`

- [ ] **Step 1: Write failing tests in `GeminiProxyClientTests.swift` & `VertexAIManagerTests.swift`**

Test that `GeminiProxyClient` includes `responseSchema` in `generationConfig` when provided, and that `VertexAIManager` exposes structured failure reasons (`networkUnavailable`, `timedOut`, `rateLimited`) instead of discarding errors.

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/GeminiProxyClientTests -only-testing:FoodTrackerTests/VertexAIManagerTests
```
Expected: FAIL.

- [ ] **Step 3: Implement schema forwarding, error propagation, and cancellation cleanup**

1. Pass optional `responseSchema: [String: Any]?` in `GeminiProxyClient.performRequest` when `forceJSON == true` for core structured DTOs (Meal Scan, Menu Scan, Fridge Recipe, Weekly Plan).
2. Store typed error on `VertexAIManager` / return error message into `SmartScannerView`, `BeforeAfterView`, `AICoachChatView`, `SmartPlanBuilderFlow`, and `AIChefStudioView` using `AINutritionService.lastUserFacingError` / localized `URLError` mapping (offline, timeout, 429).
3. In `AICoachChatView.swift:286`, `SmartPlanBuilderFlow.swift:403`, and `AIChefStudioView.swift`, reset `isGenerating = false` unconditionally in a `defer` or cancellation handler (e.g. `onDisappear` resets `isGenerating = false` when cancelling `activeTask`) so switching tabs never locks the UI!

- [ ] **Step 4: Run tests and verify pass**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/GeminiProxyClientTests -only-testing:FoodTrackerTests/VertexAIManagerTests
git add FoodTracker/Services/GeminiProxyClient.swift FoodTracker/Services/VertexAIManager.swift FoodTracker/AI/AICoachChatView.swift FoodTracker/Views/SmartBuilder/SmartPlanBuilderFlow.swift FoodTracker/App/AIChefStudioView.swift FoodTrackerTests/
git commit -m "fix(ai): forward responseSchema, surface AI network errors, and reset isGenerating on task cancellation"
```
Expected: PASS.

---

### Task 12: Fix Camera Thread Safety, 48MP Thumbnailing, Non-Metric FatSecret Servings, OFF Micronutrients & UPC-E Expansion

**Files:**
- Modify: `FoodTracker/Scan/BarcodeScannerController.swift:26-34, 153-255`
- Modify: `FoodTracker/Scan/SmartScannerView.swift:81-87, 483-495, 594-599, 912-919`
- Modify: `FoodTracker/Services/NetworkManager.swift:372-415, 609-614, 652-698`
- Modify: `functions/index.js:954-960, 1071-1136`
- Test: `functions/test_proxy.js`, `FoodTrackerTests/NetworkManagerTests.swift`, `FoodTrackerTests/MicronutrientPipelineTests.swift`

- [ ] **Step 1: Write failing tests for UPC-E expansion, non-metric FatSecret serving weight `0`, and OpenFoodFacts `*_100g` micronutrient scaling**

In `functions/test_proxy.js`:
```javascript
test("normalizeFatSecretBarcodeInput expands 8-digit UPC-E to 13-digit GTIN", () => {
  assert.equal(_test.normalizeFatSecretBarcodeInput("04252614"), "0042520000614");
});

test("normalizeFatSecretFood preserves weightGrams = 0 when metric_serving_amount is missing", () => {
  const item = _test.normalizeFatSecretFood({
    food_name: "Pizza Slice",
    servings: { serving: { serving_description: "1 slice", calories: "280", protein: "12", fat: "10", carbohydrate: "34" } },
  });
  assert.equal(item.weightGrams, 0);
  assert.equal(item.servingDescription, "1 slice");
});
```
In `FoodTrackerTests/NetworkManagerTests.swift`: add test verifying `"calcium_100g": 0.12` with `"calcium_unit": "mg"` normalizes to `120 mg` (`*_100g` is always grams in OFF v0 JSON, regardless of label display `*_unit`).

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
cd functions && npm test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/NetworkManagerTests
```
Expected: FAIL.

- [ ] **Step 3: Implement camera, barcode, and nutrition API fixes**

1. **`BarcodeScannerController.swift`**: Move `shouldRun` reads/writes strictly onto `sessionQueue`; add `deinit` / `dismantleUIViewController` teardown clearing `previewLayer?.session` and inputs/outputs; remove `.qr` and `.pdf417` from barcode food types; defer `regionOfInterest` calculation to `viewDidLayoutSubviews` when bounds are non-zero.
2. **`SmartScannerView.swift`**: Fall back to `AVBarcodeScannerRepresentable` on runtime `DataScannerViewController` `becameUnavailableWithError`; guard late `photoOutput` delivery with a `captureGeneration` token after 4s timeout; downsample photo `Data` via `CGImageSourceCreateThumbnailAtIndex` (`kCGImageSourceThumbnailMaxPixelSize = 1024`) to avoid 48MP bitmap memory spikes; move `downsampledImage` off the `AVCapturePhotoOutput` callback onto a background `Task`.
3. **`functions/index.js` & `NetworkManager.swift`**:
   - Implement `expandUPCEtoUPCA` inside `normalizeFatSecretBarcodeInput` (`functions/index.js:954-960`) and normalize scanned barcodes in `NetworkManager.fetchBarcodeFromOFF`.
   - When FatSecret serving has no `metric_serving_amount`, keep `weightGrams = 0` and pass `servingDescription` so `FoodDetailNutritionView` displays `"1 serving"` instead of `"100 g"`.
   - Convert FatSecret `% Daily Value` micronutrient fields (`calcium`, `iron`, `vitamin_c`, `vitamin_d`) from `% DV` to `mg`/`mcg` using FDA Daily Values (Ca `1300 mg`, Fe `18 mg`, Vit C `90 mg`, Vit D `20 mcg`).
   - In `NetworkManager.extractOFFMicronutrientMg`/`Mcg`, treat `*_100g` and `*_serving` values in OpenFoodFacts JSON as grams (`* 1000` for mg, `* 1_000_000` for mcg) instead of multiplying by label `*_unit` (matching `extractOFFGramField`).

- [ ] **Step 4: Run backend and iOS tests**

Run:
```bash
cd functions && npm test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests/NetworkManagerTests -only-testing:FoodTrackerTests/MicronutrientPipelineTests
git add functions/ FoodTracker/Scan/ FoodTracker/Services/NetworkManager.swift FoodTrackerTests/
git commit -m "fix(scanner,nutrition): fix camera race/memory, UPC-E expansion, FatSecret 0g servings, and OFF micronutrient units"
```
Expected: PASS.

---

## Wave 5: Core Nutrition Math, Fasting, Recipes, UX Polish & Tech Debt

### Task 13: Fix Overflow Crashes, Micronutrient RDAs, Goals Maintain Mode, Fasting `5:2 Diet` & Recipe Scaling

**Files:**
- Modify: `FoodTracker/Utils/NutritionMath.swift:220`
- Modify: `FoodTracker/Views/CreateRecipeView.swift:207, 730-745`
- Modify: `FoodTracker/Views/Profile/AnalyticsDashboardView.swift:373-377`
- Modify: `FoodTracker/Views/Components/ReusableComponents.swift:754-757`
- Modify: `FoodTracker/Views/Goals/GoalsTabView.swift:32-43`
- Modify: `FoodTracker/Views/FastingDashboardView.swift:80`
- Modify: `FoodTracker/Services/FastingManager.swift:400`
- Modify: `FoodTracker/Views/Foods/FoodDetailNutritionView.swift:368-399`
- Modify: `FoodTracker/Views/Chefs/ChefRecipesView.swift:585-625, 1057-1070`
- Test: `FoodTrackerTests/MicronutrientPipelineTests.swift`, `FoodTrackerTests/NutritionProgressManagerTests.swift`

- [ ] **Step 1: Write failing tests for overflow clamping, maintain goal progress, and weekly personalized RDAs**

Add tests in `FoodTrackerTests/NutritionProgressManagerTests.swift` and `FoodTrackerTests/MicronutrientPipelineTests.swift` verifying:
- `NutritionMath.scaledValues` clamps `calories` safely (`min(Double(Int.max / 2), ...)` or `1_000_000`) instead of trapping on `Int(1e25)`.
- `"maintain"` goal progress returns tolerance-based score rather than always `1.0`.
- `AddIngredientModalView` helper computes micronutrients via `MicronutrientEstimator.estimate(...)` and clamps integer calories.

- [ ] **Step 2: Apply fixes across nutrition math, fasting, recipes, and UI**

1. **Overflow Protection**: Add `NutritionMath.clampedInt(_ value: Double, maxValue: Int = 999_999) -> Int` and use it in `NutritionMath.scaledValues` (`line 220`) and `AddIngredientModalView.saveIngredient()` (`CreateRecipeView.swift:734`), plus call `MicronutrientEstimator.estimate` for new custom ingredients.
2. **Personalized Micro RDAs**: Update `AnalyticsDashboardView.swift:376` to use `micro.rda(for: user)`; pass user iron RDA (`8 mg` male / `18 mg` female) into `MicronutrientsFocusCard` (`ReusableComponents.swift:757`).
3. **Goals Maintain Progress**: In `GoalsTabView.swift:32-43`, for `goalType == "maintain"` compute progress based on proximity to `target` (within `±1.0 kg` = `1.0`, decaying smoothly) instead of returning `1.0` unconditionally.
4. **Fasting `5:2 Diet` & 24h/36h Milestones**: Clarify `5:2` as a 24h fasting protocol (`fastingHours: 24, eatingHours: 0`) or dedicated 5:2 schedule copy, and add `24h` and `36h` milestones to `FastingManager.scheduleFastingNotifications` (`line 400`). Surface notification denied status banner in `FastingDashboardView`.
5. **Recipe & Serving UI**:
   - In `FoodDetailNutritionView.swift:391-399`, clamp slider binding to `min(max(weight, 5), 1000)` and allow `>1000g` text input cleanly without snapping back.
   - In `ChefRecipesView.swift:585-625`, label calories explicitly as `"kcal / serving"`; in `CreateRecipeView.swift`, trim `recipeName`, show per-serving calories in `Step4VerificationView`, and add swipe-to-delete / edit for custom foods.
   - Localize/respect `useMetricSystem` for weight units (`g` vs `oz`, height `ft' in"`).

- [ ] **Step 3: Run full test suite**

Run:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FoodTrackerTests
git add FoodTracker/ FoodTrackerTests/
git commit -m "fix(core): clamp numeric overflows, align micro RDAs, fix maintain goal progress and recipe/fasting UX"
```
Expected: PASS.

---

### Task 14: Data Export Expansion, Keyboard Toolbars, Performance & Dead-Code Cleanup

**Files:**
- Modify: `FoodTracker/Utils/DataExportService.swift:17-41`
- Modify: `FoodTracker/Views/Profile/ProfileView.swift:595-621`
- Modify: `FoodTracker/Services/RecipeDataLoader.swift:15-18`
- Modify: `FoodTracker/Services/AcademyDataLoader.swift:41-46`
- Modify: `FoodTracker/Views/More/MoreTabView.swift:71-121`
- Modify: `FoodTracker/Views/AddMealView.swift`, `FoodTracker/Views/Foods/FoodDetailNutritionView.swift`, `FoodTracker/Views/Goals/GoalsTabView.swift` (keyboard `Done` toolbar)
- Delete or clean up unused symbols: `FoodTracker/Utils/MotionManager.swift`, legacy unused properties in `AppStateManager.swift`, `ProfileViewModel.swift`, `AICoachViewModel.swift`
- Test: `FoodTrackerTests/DataModelsTests.swift`

- [ ] **Step 1: Expand `DataExportService.generateCSV` & show export errors**

Include `Hydration (L),Fiber (g),Sugar (g),Active Burned (kcal),Steps,Weight (kg)` columns in `DataExportService.swift`, test CSV escaping and column output in `DataModelsTests.swift`, and present an error alert in `ProfileView.swift` when export fails instead of `print`-only.

- [ ] **Step 2: Move `RecipeDataLoader` / `AcademyDataLoader` JSON decode off main thread, add `.toolbar` Done buttons, fix `MoreTabView` `AnyView`/ReduceMotion**

- Decode bundled JSON in `Task.detached(priority: .userInitiated)` and publish on `@MainActor`.
- Add `ToolbarItemGroup(placement: .keyboard)` `Done` buttons for `.decimalPad` / `.numberPad` views.
- Check `@Environment(\.accessibilityReduceMotion)` in `MoreTabView.swift:71-81` and replace computed `AnyView` array allocation with typed enum destination switching.
- Remove dead `MotionManager.swift` (and its unused reference in `DataModelsTests.swift:689`) plus unused repository fields in `ProfileViewModel`/`AICoachViewModel`.

- [ ] **Step 3: Full Verification Run (Backend + Unit + UI + Both Release Builds)**

Run all checks after final edits:
```bash
cd functions && npm test
cd ..
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project FoodTracker.xcodeproj -scheme FoodTracker -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild build -project FoodTracker.xcodeproj -scheme FoodTrackerWidgetExtension -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```
Expected: Backend 100% PASS, `FoodTrackerTests` 100% PASS, `FoodTrackerUITests` 100% PASS, both Release builds `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore(polish): expand CSV export, add keyboard toolbars, async JSON loading, and remove dead code"
```
