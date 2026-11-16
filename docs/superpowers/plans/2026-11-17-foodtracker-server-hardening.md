# FoodTracker High-Priority Server Hardening Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy `foodSearchProxy` and `foodDeleteAccount` Cloud Functions, move FatSecret credentials to Secret Manager, sanitize `remote_config.json`, and update iOS `NetworkManager` and `AuthManager`.

**Architecture:** Extract shared `verifyAppCheck` / `verifyFirebaseUser` helpers in `functions/index.js`, add FatSecret OAuth token caching + normalization helpers, and export `foodSearchProxy` and `foodDeleteAccount` alongside `foodAiProxy`. Update `AIProxyEndpoint`, `NetworkManager`, and `AuthManager` on iOS without adding new SPM dependencies.

**Tech Stack:** Node.js 22, Firebase Functions v2, `node:test`, Swift 5, `URLSession`, `xcodebuild`.

---

### Task 1: TDD for `foodSearchProxy` & `foodDeleteAccount` in `functions/`

**Files:**
- Modify: `functions/test_proxy.js`
- Modify: `functions/index.js`

- [ ] **Step 1: Add failing unit tests in `functions/test_proxy.js`**
  Test `foodSearchProxy` and `foodDeleteAccount` exports, `parseNumericValue`, `isTokenValid`, `normalizeFatSecretFood`, `normalizeFatSecretSearch`, `normalizeFatSecretBarcode`, and `parseSearchPayload`.
- [ ] **Step 2: Run `cd functions && npm test` to verify RED**
- [ ] **Step 3: Implement `verifyAppCheck`, `verifyFirebaseUser`, FatSecret normalization + token cache, `foodSearchProxy`, and `foodDeleteAccount` in `functions/index.js`**
- [ ] **Step 4: Run `cd functions && npm test` to verify GREEN**
- [ ] **Step 5: Commit `functions/index.js` and `functions/test_proxy.js`**

### Task 2: Configure FatSecret Secrets, Deploy New Functions, & Verify Live Endpoints

**Files:**
- None modified.

- [ ] **Step 1: Store `FATSECRET_CLIENT_ID` and `FATSECRET_CLIENT_SECRET` in Secret Manager via stdin pipe**
- [ ] **Step 2: Deploy strictly `foodtracker:foodSearchProxy` and `foodtracker:foodDeleteAccount`**
  Run: `firebase deploy --only functions:foodtracker:foodSearchProxy,functions:foodtracker:foodDeleteAccount --project serzhanovich-ecosystem-ce700 --non-interactive`
- [ ] **Step 3: Verify `firebase functions:list` (50 total functions; existing 48 untouched) and `curl` 401 gate checks**

### Task 3: TDD for iOS `AIProxyEndpoint`, `NetworkManager`, `AuthManager`, & `remote_config.json` Cleanup

**Files:**
- Modify: `FoodTracker/Services/AIProxyEndpoint.swift`
- Modify: `FoodTracker/Services/NetworkManager.swift`
- Modify: `FoodTracker/Auth/AuthManager.swift`
- Modify: `FoodTrackerTests/GeminiProxyClientTests.swift`
- Modify: `FoodTrackerTests/NetworkManagerTests.swift`
- Modify: `remote_config.json`

- [ ] **Step 1: Add unit assertions / tests for `AIProxyEndpoint.searchFallbackURL`, `deleteAccountFallbackURL`, and `NetworkManager` proxy decoding**
- [ ] **Step 2: Run `swiftc` RED check for new `AIProxyEndpoint` properties**
- [ ] **Step 3: Update `AIProxyEndpoint.swift`, `NetworkManager.swift`, `AuthManager.swift`, and sanitize `remote_config.json`**
- [ ] **Step 4: Run `swiftc` assertions + full `xcodebuild` iOS build**
- [ ] **Step 5: Commit iOS changes and sanitized `remote_config.json`**
