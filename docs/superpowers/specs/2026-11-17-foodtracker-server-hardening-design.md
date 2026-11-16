# FoodTracker High-Priority Server Hardening — Design

**Date:** 2026-11-17
**Scope:** High-priority security & App Store compliance upgrades in `functions/index.js`, `FoodTracker/Services/`, `FoodTracker/Auth/AuthManager.swift`, and `remote_config.json`.

## Goals

1. **`foodSearchProxy`:** Move FatSecret API OAuth2 credentials and token management off the iOS client into an App Check-protected Cloud Function (`foodSearchProxy`), fixing broken infinite token caching and removing plaintext API secrets from `remote_config.json`.
2. **`foodDeleteAccount`:** Add a server-side account-data deletion endpoint (`foodDeleteAccount`) for App Store Guideline 5.1.1(v) that deletes FoodTracker's per-user Firestore state (`food_ai_usage/{uid}`) before deleting the Firebase Auth user, without touching shared `WorkoutTracker` collections (`users/{uid}`).

## Shared-Project Safety

- Keep `"codebase": "foodtracker"` in `firebase.json`.
- Deploy strictly with `firebase deploy --only functions:foodtracker:foodSearchProxy,functions:foodtracker:foodDeleteAccount --project serzhanovich-ecosystem-ce700`.
- `foodDeleteAccount` deletes **only** `food_ai_usage/{uid}` (never `users/{uid}` or `shared_workouts`), preventing cross-app data loss if a user shares an Apple/Google Auth UID across FoodTracker and WorkoutTracker.
- Do **not** overwrite live Firebase Remote Config from `remote_config.json` while older client versions may still exist; sanitize only the git-tracked `remote_config.json`.

## Architecture

### 1. Shared Request Auth Helpers (`functions/index.js`)
- `verifyAppCheck(req, res)`: validates `X-Firebase-AppCheck` header via `getAppCheck().verifyToken`, returning `401` on missing/invalid tokens.
- `verifyFirebaseUser(req, res)`: validates `Authorization: Bearer <idToken>` via `getAuth().verifyIdToken`, returning `uid` or `401`.

### 2. `foodSearchProxy` (`onRequest`, `nodejs22`, `us-central1`, `256MiB`, `30s`)
- Secrets: `FATSECRET_CLIENT_ID`, `FATSECRET_CLIENT_SECRET` via `defineSecret`.
- Gate: `POST` only + `verifyAppCheck`.
- Token cache: module-level `{ token, expiresAtMs }` with 60s expiry margin and automatic single `forceRefresh` retry on FatSecret HTTP `401`.
- Request modes:
  - `{"mode": "search", "query": "...", "maxResults": 15}` → calls FatSecret `foods/search/v1`, returns `{"items": [NormalizedFood]}`.
  - `{"mode": "barcode", "barcode": "..."}` → calls FatSecret `food/barcode/find-by-id/v2`, returns `{"item": NormalizedFood | null}`.
- Normalization (`normalizeFatSecretFood`): handles `servings.serving` as array or object, converts numeric strings with commas/dots, defaults serving weight to `100.0` when `metric_serving_amount <= 0`.

### 3. `foodDeleteAccount` (`onRequest`, `nodejs22`, `us-central1`, `256MiB`, `60s`)
- Gate: `POST` only + `verifyAppCheck` + `verifyFirebaseUser` → `uid`.
- Deletes `food_ai_usage/{uid}` idempotently (`ref.delete()`).
- Returns `200 {"ok": true}`.

### 4. iOS Client Updates
- **`AIProxyEndpoint.swift`:** Add `resolve(configured:fallback:)`, `foodSearchRemoteConfigKey = "food_search_proxy_url"`, `searchFallbackURL`, `deleteAccountRemoteConfigKey = "food_delete_account_url"`, `deleteAccountFallbackURL`.
- **`NetworkManager.swift`:** Remove FatSecret credentials/OAuth code, add injectable `var session: URLSession` and `appCheckTokenProvider`, route `searchFromFatSecret` and `fetchBarcodeFromFatSecretBarcode` to `foodSearchProxy`. OpenFoodFacts remains direct on-device.
- **`AuthManager.swift`:** Call `foodDeleteAccount` with Firebase ID token + App Check token **before** `user.delete()` inside `deleteCurrentUser()`.
- **`remote_config.json`:** Replace plaintext `fatsecret_client_id`, `fatsecret_secret`, `pexels_api_key` with empty strings and include `food_ai_proxy_url`, `food_search_proxy_url`, `food_delete_account_url`.
