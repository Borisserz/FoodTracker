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
3. In Xcode (signed in with your Apple ID): Product → Archive → Distribute App → App Store Connect.
   - CLI archive already succeeded at `/tmp/FoodTracker.xcarchive` (1.0 / 2).
   - CLI export failed here: missing iOS Distribution cert / App Group on Store profile / no ASC account in this environment. Fix App Groups on the App ID + refresh Store profiles, then distribute from Organizer.
4. Upload to TestFlight (internal) → soak 24–48h; watch Crashlytics.
5. ASC metadata from `AppStoreDescription.md` (EN + RU).
6. Privacy nutrition labels must match `PrivacyInfo.xcprivacy` (tracking = false).
7. Paste Review Notes from `docs/APP_STORE_REVIEW_NOTES.md`.
8. Screenshots: real UI on 6.9" iPhone only (iPhone-only app).
9. Submit for Review.

Export helper plist (for a machine with Distribution signing): `docs/ExportOptions-AppStore.plist` (team `LSCCP92LMG`).

## Rollback

- Keep previous App Store binary live until the new build is Approved.
- Git rollback point before this launch pack: `0cd2fa9` (pre colleague editorial) or revert specific commits if needed.
