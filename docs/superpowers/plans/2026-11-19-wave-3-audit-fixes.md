# FoodTracker Wave 3 Audit Fixes & Test Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:test-driven-development and superpowers:verification-before-completion to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the third and final remediation wave: reach full 8,727+ item parity and native European Portuguese (`pt-PT`) quality in `foods_pt-PT.json`, fix machine-translation bugs and time units in `recipes_*.json`, `RecipeTagCatalog`, and `scripts/`, expand unit test coverage (`VersionManager`, mocked AI pipeline + consent guard, protocol-backed `HealthKitManager`, `WidgetIntents`), and add end-to-end `FoodTrackerUITests` scenarios.

**Architecture:**
- Content remediation pairs strict schema/lexical unit tests with automated batch translation (`pt-PT` terminology enforcement) and canonical tag normalization preserving legacy Firestore aliases.
- Service testability uses lightweight protocol seams (`VersionConfigProviding`, `GeminiProxyExecuting`, `HealthKitStoreExecuting`) with default production singletons so production call sites remain unchanged while tests run deterministically offline.
- XCUITests rely on explicit `accessibilityIdentifier`s with `-uiTestingSkipOnboarding` / `-uiTestingResetOnboarding` launch arguments.

**Tech Stack:** Swift 6 / SwiftUI / SwiftData / HealthKit / XCTest / XCUITest, Python 3 translation tooling, OpenRouter `:free` models.

---

### Task 1: Localization Scripts, Recipe Tags/Times, and Complete `foods_pt-PT.json`

**Files:**
- Modify: `FoodTrackerTests/DataModelsTests.swift`
- Modify: `FoodTrackerTests/RecipeTagCatalogTests.swift`
- Modify: `scripts/translate_json.py`
- Modify: `scripts/translate_xcloc.py`
- Modify: `FoodTracker/Services/RecipeTagCatalog.swift`
- Modify: `FoodTracker/recipes_de.json`, `FoodTracker/recipes_es.json`, `FoodTracker/recipes_fr.json`, `FoodTracker/recipes_it.json`, `FoodTracker/recipes_pt-PT.json`, `FoodTracker/recipes_ru.json`
- Modify: `FoodTracker/foods_pt-PT.json`

- [ ] **Step 1 (RED):** Tighten `testWave4PortugueseFoodCatalogAndRecipeParityAndUnits` in `FoodTrackerTests/DataModelsTests.swift` (require all `foods_en.json` IDs & 24 categories present in `foods_pt-PT.json`, total >= 8,727) and extend `RecipeTagCatalogTests.swift` (assert known ES/PT mistranslations are gone and localized `time` units exist for `ru`/`de`).
- [ ] **Step 2 (Verify RED):** Run `DataModelsTests/testWave4PortugueseFoodCatalogAndRecipeParityAndUnits` and `RecipeTagCatalogTests` to observe failure on missing `pt-PT` food IDs and old tags.
- [ ] **Step 3 (GREEN):**
  - Update `scripts/translate_json.py` (`"pt-PT": "pt-PT"`, `time` unit translation, skip existing complete entries safely) and `scripts/translate_xcloc.py` (`"pt-PT": "pt-PT"`, regex placeholder protection `%lld`/`%@`/`%f`).
  - Fix `recipes_es.json` (`"Batido"`, `"Para llevar"`, `"Horneado"`, casing), `recipes_pt-PT.json` (`"Pequeno-almoço"`, `"Forno"`, `"Poucos ingredientes"`, Brazilian->European Portuguese lexicon cleanup), and localized `time` fields across all 6 localized recipe catalogs. Add the new canonical aliases to `RecipeTagCatalog.swift` (keeping legacy aliases for remote Firestore compatibility).
  - Translate and merge all 7,757 missing `foods_en.json` entries into `FoodTracker/foods_pt-PT.json` using European Portuguese (`pt-PT`) terminology while keeping the 20 regional Portuguese foods intact.
- [ ] **Step 4 (Verify GREEN):** Run `DataModelsTests` & `RecipeTagCatalogTests` + `python3 -m py_compile scripts/translate_json.py scripts/translate_xcloc.py`.

---

### Task 2: Protocol-Backed Unit Tests (`VersionManager`, Mocked AI & Consent, `HealthKitManager`, `WidgetIntents`)

**Files:**
- Modify: `FoodTracker/AppCore/VersionManager.swift`
- Modify: `FoodTracker/Services/GeminiProxyClient.swift`
- Modify: `FoodTracker/Services/VertexAIManager.swift`
- Modify: `FoodTracker/AI/AINutritionService.swift`
- Modify: `FoodTracker/Services/HealthKitManager.swift`
- Modify: `FoodTrackerWidgetExtension/WidgetIntents.swift` & `FoodTracker/Models/DataModels.swift` (`WidgetStorageActions`)
- Create: `FoodTrackerTests/VersionManagerTests.swift` (add to `FoodTracker.xcodeproj/project.pbxproj`)
- Modify: `FoodTrackerTests/VertexAIManagerTests.swift`
- Modify: `FoodTrackerTests/FoodTrackerTests.swift`

- [ ] **Step 1 (RED):** Write failing tests in `VersionManagerTests.swift`, `VertexAIManagerTests.swift` (mock `GeminiProxyExecuting` + `hasConsented == false` guard + clamping + `AINutritionService` mock JSON & failure fallback), and `FoodTrackerTests.swift` (`MockHealthKitStore` testing `saveWater`, `saveDietaryEnergy`, midnight `saveWorkout`, 90-day `fetchLatestBodyMassKg`, plus `WidgetStorageActions` water + shopping intent roundtrip).
- [ ] **Step 2 (Verify RED):** Run those targeted tests to confirm compile/failure RED.
- [ ] **Step 3 (GREEN):** Implement minimal clean protocol abstractions (`VersionConfigProviding`, `GeminiProxyExecuting`, `HealthKitStoreExecuting`, photo consent check in `VertexAIManager` vision methods) and register `VersionManagerTests.swift` in `FoodTracker.xcodeproj/project.pbxproj`.
- [ ] **Step 4 (Verify GREEN):** Run all affected test suites and confirm 0 failures.

---

### Task 3: End-to-End `FoodTrackerUITests` Expansion

**Files:**
- Modify: `FoodTracker/Views/Home/HomeDashboardView.swift` (non-invasive `accessibilityIdentifier`s where needed)
- Modify: `FoodTracker/Views/Components/HydrationTrackerCardView.swift` or quick-add controls (if needed for stable selectors)
- Modify: `FoodTracker/Scan/SmartScannerView.swift` / `ProfileView.swift`
- Modify: `FoodTrackerUITests/FoodTrackerUITests.swift`

- [ ] **Step 1 (RED):** Add UI test scenarios in `FoodTrackerUITests.swift` for quick water increment on Home, opening Quick Add / logging a meal, opening Smart Scanner, and navigating to Profile & triggering delete-account confirmation alert (then cancelling safely).
- [ ] **Step 2 (Verify RED):** Run `FoodTrackerUITests` and confirm new tests fail until stable accessibility identifiers are wired if missing.
- [ ] **Step 3 (GREEN):** Wire missing `accessibilityIdentifier`s in the views and refine UI test queries/waits for deterministic execution on Simulator.
- [ ] **Step 4 (Verify GREEN):** Run full `FoodTrackerUITests` and verify 100% pass.

---

### Task 4: Final Full Verification (`verification-before-completion`)

- [ ] Run `cd functions && node --check index.js && npm test`
- [ ] Run `python3 -m py_compile scripts/translate_json.py scripts/translate_xcloc.py` + JSON validation
- [ ] Run full `FoodTrackerTests` on `iPhone 17` Simulator
- [ ] Run full `FoodTrackerUITests` on `iPhone 17` Simulator
