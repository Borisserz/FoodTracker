# Wave 3 (AI Modals, Food Search/Micros, Nutrition Math, Gamification, Localization & Server Hardening) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or inline TDD (`test-driven-development`) to implement this plan task-by-task.

**Goal:** Fix all remaining P1 and high-value P2 issues across AI modal error surfacing, food search cache & OpenFoodFacts/FatSecret micronutrient/unit parsing, BMR/TDEE/macro/recipe/gamification math, SwiftUI localization leaks (`Text(String)`), Cloud Functions `auth_time`/GTIN-13/XFF hardening, and Firestore Rules timestamp validation.

**Architecture:**
1. Add `GeminiProxyClient.consumeRateLimitAlertMessage()` so modal views (`SmartScannerView`, `AIChefStudioView`, `SmartPlanBuilderFlow`, `BeforeAfterView`, `HomeDashboardView`, `AICoachChatView`, `AICoachViewModel`) surface HTTP 429 alerts locally instead of hiding both root and local alerts.
2. Expand `NetworkManager.CachedFoodSnapshot` with all 7 micronutrients, replace single `hasExplicitMicros` flag with per-nutrient fallback in `NetworkManager` and `AINutritionService`, convert OpenFoodFacts Vitamin D `IU`/`UI` to `mcg` (`* 0.025`), and pad 8–12 digit barcodes to 13-digit GTIN-13 in `functions/index.js`.
3. Fix clinical Mifflin-St Jeor BMR/TDEE floor order (apply `1200` kcal intake floor after multiplying by activity), cap protein overflow in `User.recalculateMacrosPreservingRatios`, compute real recipe weights & AI dish micronutrients, fix `AddMealSummaryCard` remaining daily budget, require >= 75% calorie goal for `+150` `finishDayXP` and >= 3 meal slots for `"Log all meals"` quest, and surface `nextGlassTimeMinutes` in `HydrationFixResultSheet`.
4. Convert `Text(stringVar)` to `Text(LocalizedStringKey(stringVar))` across UI components and add all missing interpolated keys across all 7 languages in `Localizable.xcstrings`.
5. Enforce recent `auth_time` (<= 300s for non-anonymous accounts) on `foodDeleteAccount`, refine `resolveIpQuotaKey` for GFE load balancer XFF hops in `functions/index.js`, and add `is timestamp` checks on `createdAt`/`blockedAt` in `firestore.rules`.

**Tech Stack:** Swift 5 / SwiftUI / SwiftData / XCTest (`FoodTrackerTests`), Node.js 22 (`node --test`), Firestore Security Rules, `Localizable.xcstrings`.
