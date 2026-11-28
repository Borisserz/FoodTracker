# App Store Submit Checklist — FoodTracker 1.0 (build 2)

## Pre-archive (done in repo)

- [x] P0/P1: spotlight tab-bar probe gated; add-meal scroll fixed; no Champion phantom user
- [x] Unit + UI + Cloud Functions tests green on baseline
- [x] First-run / Coach EN+RU strings in `Localizable.xcstrings`
- [x] Legal URLs live and match `docs/legal/` (updated 20 Nov 2026)
- [x] Review notes drafted: `docs/APP_STORE_REVIEW_NOTES.md`
- [x] Release debug prints gated; system appearance after onboarding
- [x] Marketing version `1.0`, project version `2`

## You do in Xcode / ASC

1. Open Firebase Console → App Check: confirm App Attest for FoodTracker production app.
2. Smoke on a physical device: HealthKit water/meal write, Spotlight on latest iOS, Delete Account (registered).
3. In Xcode (signed in with your Apple ID): Product → Archive → Distribute App → App Store Connect (then run **Validate App** first to verify `FirebaseAnalyticsCore` / `GoogleAppMeasurement` packaging without ITMS-91061).
   - Enable both App Groups (`group.com.borisdev.FoodTracker2026`, `group.com.borisdev.WorkoutTracker`) on both App IDs (App + Widget Extension) in Apple Developer Portal and refresh Distribution profiles before archiving.
   - Do **not** upload old Development-signed archives; always create a fresh Release archive from Organizer.
4. Push updated `docs/legal/Privacy Policy - FoodTracker.html` to the GitHub Pages `workouttracker-privacy` repo so the live Privacy Policy includes the Google Cloud Vertex AI fallback disclosure.
5. Upload to TestFlight (internal) → soak 24–48h; watch Crashlytics.
6. ASC metadata from `AppStoreDescription.md` (EN + RU).
7. Privacy nutrition labels must match `PrivacyInfo.xcprivacy` (tracking = false) and include **Other Diagnostic Data** (Not Linked, App Functionality — declared by FirebaseCrashlytics).
8. Paste Review Notes from `docs/APP_STORE_REVIEW_NOTES.md`.
9. Screenshots: real UI from `Screenshots/AppStore/` (no alpha channel) on 6.9" iPhone only (iPhone-only app — do not upload iPad screenshots).
10. Submit for Review.

Export helper plist (for a machine with Distribution signing): `docs/ExportOptions-AppStore.plist` (team `LSCCP92LMG`).

## Rollback

- Keep previous App Store binary live until the new build is Approved.
- Git rollback point before this launch pack: `0cd2fa9` (pre colleague editorial) or revert specific commits if needed.
