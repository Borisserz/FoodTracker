# FoodTracker OpenRouter AI Proxy — Design

**Date:** 2026-11-16
**Scope:** FoodTracker backend (`functions/`, `firebase.json`) and iOS AI client layer (`FoodTracker/Services/`, `FoodTracker/AI/`). Shared Firebase project `serzhanovich-ecosystem-ce700` — strictly isolated from WorkoutTracker (`vertexProxy`), `imageProxy`, and other apps.

## Goal

Build a dedicated, reliable, zero-cost AI backend for FoodTracker powered by OpenRouter `:free` models (supporting both text nutrition coaching/planning and multimodal food/menu photo analysis), with App Check + Firebase Auth protection, per-user weekly rate limiting, multi-key rotation, 10-model fallback, and hardened iOS client integration.

## Shared-Project Safety Rules

- `serzhanovich-ecosystem-ce700` hosts 47 Cloud Functions across multiple apps (`WorkoutTracker`, `FoodTracker`, `Yoga1`, `Autora`, `Wardrobe`, `FitRPG`, `CoolAV.by`).
- `firebase.json` isolates FoodTracker's functions under `"codebase": "foodtracker"`.
- `functions/index.js` exports **only** FoodTracker's `foodAiProxy` (removing copied WorkoutTracker exports `vertexProxy`, `moderateSharedWorkout`, `onReportCreated`, `deleteAccount` from this repo so an accidental deploy cannot overwrite them).
- Deployments use `firebase deploy --only functions:foodAiProxy --project serzhanovich-ecosystem-ce700`.
- `firestore.rules` and `remote_config.json` are **never** deployed wholesale from this repository.
- API keys never enter git-tracked files; they live exclusively in Firebase Secret Manager (`OPENROUTER_API_KEY`, preserving any existing key and appending new keys comma-separated) and gitignored `functions/.secret.local` for local smoke testing.

## Server Architecture (`functions/index.js`)

```
iOS FoodTracker (GeminiProxyClient → AIProxyEndpoint)
  │  POST https://... (Remote Config `food_ai_proxy_url` → fallback Cloud Run URL)
  │  Headers: X-Firebase-AppCheck, Authorization: Bearer <idToken>
  │  Body: Gemini-compatible { systemInstruction, contents (text + optional inlineData), generationConfig }
  ▼
Cloud Function `foodAiProxy` (Node.js 22, v2 onRequest, us-central1, 512MiB, 300s)
  ├── 1. Verify App Check token (`getAppCheck().verifyToken`)
  ├── 2. Verify Firebase ID token (`getAuth().verifyIdToken`) → `uid`
  ├── 3. Pre-check rolling 7-day quota in `food_ai_usage/{uid}`
  │      (limit from `config/food_ai_settings.weeklyLimit`, default 200; returns 429 + Retry-After)
  ├── 4. Detect multimodal (`inlineData` present) vs text request
  ├── 5. Translate Gemini body → OpenAI Chat Completions (text or `image_url` data URI)
  ├── 6. Walk model fallback chain × rotated `OPENROUTER_API_KEY` pool
  │      - Adapt `response_format` per model capability (`json_schema` / `json_object` / omitted)
  │      - When JSON expected, validate parseable JSON via `stripModelJSON` before accepting
  ├── 7. Record successful call in `food_ai_usage/{uid}` (failed upstream attempts never burn quota)
  └── 8. Return Gemini-shaped JSON `{ candidates: [{ content: { parts: [{ text }] } }] }` (or SSE when `?stream=true`)
```

### Model Chains & Dynamic Override

Default model chains verified against OpenRouter's live `:free` catalog, overridable at runtime via Firestore `config/food_ai_settings` (`textModels`, `visionModels`, `weeklyLimit`):

**Text Chain (10 models, structured-first → `openrouter/free`):**
1. `inclusionai/ling-3.2-flash:free`
2. `baidu/ernie-5.5-flash-preview:free`
3. `liquid/lfm-3-1.7b:free`
4. `particle-ai/particle-1:free`
5. `dots-studio/dots-3-note-preview:free`
6. `nvidia/nemotron-3.5-super-vl:free`
7. `google/gemma-4-31b-it:free`
8. `google/gemma-4-26b-a4b-it:free`
9. `recursive/flint-v1.0:free`
10. `openrouter/free`

**Vision Chain (multimodal models only — prevents guaranteed `400` errors on text-only models):**
1. `nvidia/nemotron-3.5-super-vl:free`
2. `inclusionai/ling-3.2-flash:free`
3. `particle-ai/particle-1:free`
4. `dots-studio/dots-3-note-preview:free`
5. `google/gemma-4-31b-it:free`
6. `google/gemma-4-26b-a4b-it:free`
7. `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free`
8. `thinkingmachines/inkling-2-small:free`
9. `openrouter/free`

When iterating models, any model without `response_format` support omits `response_format` and relies on prompt instructions + server `stripModelJSON` + JSON validation retry.

### Multimodal Translation

In `geminiBodyToOpenAI`:
- For text-only parts, `message.content` stays a plain string for maximum compatibility across free models.
- When any `inlineData` part (`{ mimeType, data }`) is present, `message.content` becomes an OpenAI content array combining `{ type: "text", text }` and `{ type: "image_url", image_url: { url: "data:<mimeType>;base64,<data>" } }`.

## iOS Client Updates

1. **`FoodTracker/Services/AIProxyEndpoint.swift` (new):**
   - Resolves Remote Config key `food_ai_proxy_url` (HTTPS + non-empty host validation), falling back to the deployed `foodAiProxy` Cloud Run URL.
2. **`FoodTracker/Services/AIResponseParsing.swift` (new):**
   - Pure helper `extractJSON(from:)` that strips markdown fences and locates the first balanced top-level `{...}` or `[...]` JSON payload even when a free model wraps JSON in prose.
3. **`FoodTracker/Services/GeminiProxyClient.swift`:**
   - Uses `AIProxyEndpoint` + `RemoteConfigManager` instead of hardcoded `vertexProxy` URL.
   - Uses a configured `URLSession` (`timeoutIntervalForRequest = 60`, `timeoutIntervalForResource = 120`, `waitsForConnectivity = true`).
   - Ensures anonymous Firebase sign-in via `AnonymousAuthBootstrap.shared.ensureSignedIn()` if `Auth.auth().currentUser == nil`.
   - Parses `429` (`Retry-After` header or JSON `retryAfter`) into `GeminiProxyError.rateLimited`.
   - Uses `AIResponseParsing.extractJSON(from:)` before `JSONDecoder`.
4. **`FoodTracker/Services/VertexAIManager.swift` & `FoodTracker/AI/AINutritionService.swift`:**
   - Fix double-escaped `\\(currentLanguage)` → `\(currentLanguage)` in `languageInstruction` so AI responses actually honor the user's locale.

## Verification

1. **Node.js unit & live smoke suite (`functions/smoke_openrouter.js`):**
   - Deterministic unit tests for Gemini→OpenAI translation (text + `inlineData` vision), `stripModelJSON`, schema adaptation, and model selection.
   - Live OpenRouter smoke calls covering: plain chat, structured JSON (daily verdict, recipe, weekly plan), and multimodal base64 JPEG meal/menu recognition across configured API keys.
2. **Live Cloud Function verification:**
   - Deploy `--only functions:foodAiProxy`, confirm unauthenticated/missing App Check requests return `401`, check Firebase logs, and verify live endpoint response.
3. **iOS build & pure logic tests:**
   - Add pure Swift tests for `AIProxyEndpoint`, `AIResponseParsing`, and `GeminiProxyError` parsing; compile `FoodTracker` target with `xcodebuild`.
