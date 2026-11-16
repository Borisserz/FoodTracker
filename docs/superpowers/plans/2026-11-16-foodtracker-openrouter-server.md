# FoodTracker OpenRouter AI Proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and deploy an isolated OpenRouter-powered Cloud Function (`foodAiProxy`) for FoodTracker with 10-model fallback (text + multimodal vision) and update the FoodTracker iOS client to use it reliably.

**Architecture:** `FoodTracker/functions/index.js` exports only `foodAiProxy` under `"codebase": "foodtracker"` in `firebase.json` so deployments to `serzhanovich-ecosystem-ce700` never touch WorkoutTracker (`vertexProxy`) or the other 46 functions. `foodAiProxy` verifies App Check + Firebase Auth, enforces rolling 7-day per-user limits in `food_ai_usage/{uid}` (counting only successful responses), translates Gemini requests (including `inlineData` images) to OpenAI Chat Completions, and walks model chains + rotated `OPENROUTER_API_KEY` secrets. On iOS, `GeminiProxyClient` resolves the endpoint via `AIProxyEndpoint` + Remote Config, extracts balanced JSON with `AIResponseParsing`, and `VertexAIManager`/`AINutritionService` fix the double-escaped `\\(currentLanguage)` bug.

**Tech Stack:** Node.js 22, Firebase Functions v2 (`firebase-functions ^5.1.0`, `firebase-admin ^12.6.0`), Node built-in `node:test`, OpenRouter API, Swift 5 / SwiftUI / Firebase iOS SDK 12.12.1, `xcodebuild`.

## Global Constraints

- Shared Firebase project `serzhanovich-ecosystem-ce700` — NEVER overwrite or delete `vertexProxy`, `imageProxy`, `moderateSharedWorkout`, `onReportCreated`, `deleteAccount`, or any non-FoodTracker function.
- NEVER deploy `firestore.rules` or `remote_config.json` wholesale from this repository.
- Deploy strictly with `firebase deploy --only functions:foodAiProxy --project serzhanovich-ecosystem-ce700`.
- NEVER commit API keys to git; store keys only in Firebase Secret Manager (`OPENROUTER_API_KEY`, preserving any existing key and appending new keys comma-separated) and gitignored `functions/.secret.local`.
- Preserve all existing code comments/docstrings unrelated to our changes.

---

### Task 1: Isolate Firebase Codebase & Package Config

**Files:**
- Modify: `firebase.json`
- Modify: `functions/package.json`
- Modify: `functions/.gitignore`

**Interfaces:**
- Produces: Firebase CLI `"codebase": "foodtracker"` isolation and Node 22 runtime config with `npm test` / `npm run smoke` scripts.

- [ ] **Step 1: Update `firebase.json` to isolate the functions codebase**

```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": [
    {
      "source": "functions",
      "codebase": "foodtracker",
      "ignore": [
        "node_modules",
        ".git",
        "firebase-debug.log",
        "firebase-debug.*.log",
        "*.local",
        "test_proxy.js",
        "smoke_openrouter.js"
      ]
    }
  ]
}
```

- [ ] **Step 2: Update `functions/package.json` for Node 22 and test scripts**

```json
{
  "name": "foodtracker-ai-proxy",
  "description": "OpenRouter AI proxy for FoodTracker with App Check, vision fallback, and per-user quotas",
  "engines": { "node": "22" },
  "main": "index.js",
  "scripts": {
    "test": "node --test test_proxy.js",
    "smoke": "node smoke_openrouter.js"
  },
  "dependencies": {
    "firebase-admin": "^12.6.0",
    "firebase-functions": "^5.1.0"
  },
  "private": true
}
```

- [ ] **Step 3: Harden `functions/.gitignore` so local secrets and logs are never tracked**

```gitignore
node_modules/
*.local
.env
.secret.local
*.log
```

- [ ] **Step 4: Commit config updates**

```bash
git add firebase.json functions/package.json functions/.gitignore
git commit -m "chore(functions): isolate foodtracker codebase and configure Node 22"
```

---

### Task 2: TDD for `foodAiProxy` (Translation, 10-Model Fallback, Vision & Rate Limiting)

**Files:**
- Create: `functions/test_proxy.js`
- Modify: `functions/index.js`

**Interfaces:**
- Produces in `functions/index.js`:
  - `exports.foodAiProxy` (HTTPS v2 `onRequest`)
  - `module.exports._test`: `{ TEXT_MODEL_CHAIN, VISION_MODEL_CHAIN, STRUCTURED_MODELS, JSON_OBJECT_MODELS, parseApiKeys, hasImageContent, modelChainForRequest, geminiBodyToOpenAI, stripModelJSON, openAIToGeminiResponse, openAIStreamChunkToGemini, callOpenRouterText }`

- [ ] **Step 1: Write failing unit tests in `functions/test_proxy.js`**

```js
const test = require("node:test");
const assert = require("node:assert/strict");

process.env.GCLOUD_PROJECT = "serzhanovich-ecosystem-ce700";

const mod = require("./index.js");
const t = mod._test;

test("exports _test helpers and only foodAiProxy Cloud Function", () => {
  assert.ok(t, "_test helpers must be exported");
  assert.equal(typeof mod.foodAiProxy, "function");
  assert.equal(mod.vertexProxy, undefined);
  assert.equal(mod.moderateSharedWorkout, undefined);
  assert.equal(mod.onReportCreated, undefined);
  assert.equal(mod.deleteAccount, undefined);
});

test("model chains cover 10 text models and multimodal vision models", () => {
  assert.equal(t.TEXT_MODEL_CHAIN.length, 10);
  assert.ok(t.VISION_MODEL_CHAIN.length >= 8);
  assert.ok(t.TEXT_MODEL_CHAIN.includes("openrouter/free"));
  assert.ok(t.VISION_MODEL_CHAIN.includes("openrouter/free"));
});

test("parseApiKeys trims, deduplicates, and preserves order", () => {
  assert.deepEqual(
    t.parseApiKeys(" key1 , key2,key1 , , key3 "),
    ["key1", "key2", "key3"]
  );
});

test("hasImageContent detects inlineData parts", () => {
  const textOnly = { contents: [{ role: "user", parts: [{ text: "hi" }] }] };
  const withImage = {
    contents: [
      {
        role: "user",
        parts: [
          { text: "Analyze food" },
          { inlineData: { mimeType: "image/jpeg", data: "YWJj" } },
        ],
      },
    ],
  };
  assert.equal(t.hasImageContent(textOnly), false);
  assert.equal(t.hasImageContent(withImage), true);
});

test("modelChainForRequest chooses vision vs text chain and supports Firestore overrides", () => {
  const textReq = { contents: [{ role: "user", parts: [{ text: "hello" }] }] };
  const imgReq = {
    contents: [
      {
        role: "user",
        parts: [{ inlineData: { mimeType: "image/jpeg", data: "YWJj" } }],
      },
    ],
  };
  assert.deepEqual(t.modelChainForRequest(textReq), t.TEXT_MODEL_CHAIN);
  assert.deepEqual(t.modelChainForRequest(imgReq), t.VISION_MODEL_CHAIN);
  assert.deepEqual(
    t.modelChainForRequest(imgReq, { visionModels: ["custom/vl:free"] }),
    ["custom/vl:free"]
  );
});

test("geminiBodyToOpenAI converts multimodal inlineData into image_url content array", () => {
  const body = {
    systemInstruction: { parts: [{ text: "You are a nutritionist." }] },
    contents: [
      {
        role: "user",
        parts: [
          { text: "Analyze this meal." },
          { inlineData: { mimeType: "image/jpeg", data: "BASE64DATA" } },
        ],
      },
    ],
    generationConfig: {
      temperature: 0.4,
      responseMimeType: "application/json",
    },
  };
  const out = t.geminiBodyToOpenAI(body, {
    streaming: false,
    model: "nvidia/nemotron-3.5-super-vl:free",
  });
  assert.equal(out.messages[0].role, "system");
  assert.equal(out.messages[0].content, "You are a nutritionist.");
  assert.equal(out.messages[1].role, "user");
  assert.deepEqual(out.messages[1].content, [
    { type: "text", text: "Analyze this meal." },
    {
      type: "image_url",
      image_url: { url: "data:image/jpeg;base64,BASE64DATA" },
    },
  ]);
  assert.deepEqual(out.response_format, { type: "json_object" });
});

test("geminiBodyToOpenAI omits response_format for models without support", () => {
  const body = {
    contents: [{ role: "user", parts: [{ text: "Return JSON" }] }],
    generationConfig: { responseMimeType: "application/json" },
  };
  const out = t.geminiBodyToOpenAI(body, {
    streaming: false,
    model: "thinkingmachines/inkling-2-small:free",
  });
  assert.equal(out.response_format, undefined);
});

test("stripModelJSON extracts fenced or prose-wrapped JSON cleanly", () => {
  assert.equal(
    t.stripModelJSON('Here is the result:\n```json\n{"calories": 250, "note": "a } b"}\n```\nEnjoy!'),
    '{"calories": 250, "note": "a } b"}'
  );
  assert.equal(
    t.stripModelJSON('[{"name":"Apple"}] trailing text'),
    '[{"name":"Apple"}]'
  );
});

test("openAIToGeminiResponse handles array message content and JSON extraction", () => {
  const resp = t.openAIToGeminiResponse(
    {
      choices: [
        {
          message: {
            content: [{ type: "text", text: '```json\n{"ok":true}\n```' }],
          },
        },
      ],
    },
    { expectJSON: true }
  );
  assert.equal(resp.candidates[0].content.parts[0].text, '{"ok":true}');
});

test("openAIStreamChunkToGemini converts SSE delta lines and DONE", () => {
  const chunk = t.openAIStreamChunkToGemini(
    'data: {"choices":[{"delta":{"content":"Hello"}}]}'
  );
  assert.equal(
    chunk,
    '{"candidates":[{"content":{"parts":[{"text":"Hello"}]}}]}'
  );
  assert.equal(t.openAIStreamChunkToGemini("data: [DONE]"), "[DONE]");
  assert.equal(t.openAIStreamChunkToGemini(": keep-alive"), null);
});
```

- [ ] **Step 2: Run unit tests to verify RED**

Run: `cd functions && node --test test_proxy.js`
Expected: FAIL (`mod._test` is `undefined`, `mod.foodAiProxy` is `undefined`).

- [ ] **Step 3: Implement `functions/index.js` with `foodAiProxy` and `_test`**

Write `functions/index.js`:
- Keeps ONLY `exports.foodAiProxy` and `module.exports._test`.
- Defines `TEXT_MODEL_CHAIN` (10 verified live `:free` models ending in `openrouter/free`) and `VISION_MODEL_CHAIN` (multimodal `:free` models ending in `openrouter/free`).
- Translates both text and `inlineData` images (`image_url` data URI).
- Adapts `response_format` per model capability (`STRUCTURED_MODELS` / `JSON_OBJECT_MODELS` / none), adds OpenRouter `plugins: [{ id: "response-healing" }]` for JSON requests, and validates `JSON.parse` on non-streaming JSON requests before accepting a completion (automatically trying the next fallback model if a model outputs malformed JSON or empty text).
- Checks App Check + Firebase ID token, reads `config/food_ai_settings` (with defaults `weeklyLimit: 200` and optional `textModels` / `visionModels`), pre-checks `food_ai_usage/{uid}` before upstream calls, and increments `food_ai_usage/{uid}` ONLY on successful completion.

- [ ] **Step 4: Run unit tests to verify GREEN**

Run: `cd functions && node --test test_proxy.js`
Expected: PASS (all assertions green).

- [ ] **Step 5: Commit `functions/index.js` and `functions/test_proxy.js`**

```bash
git add functions/index.js functions/test_proxy.js
git commit -m "feat(functions): implement foodAiProxy on OpenRouter free models with vision fallback"
```

---

### Task 3: Live OpenRouter Smoke Suite & Firebase Secret Configuration

**Files:**
- Create: `functions/smoke_openrouter.js`
- Create (gitignored, local only): `functions/.secret.local`

**Interfaces:**
- Consumes: `functions/index.js` `_test` exports.

- [ ] **Step 1: Write `functions/smoke_openrouter.js`**

Tests live OpenRouter calls using keys from `OPENROUTER_API_KEY` or gitignored `.secret.local`:
1. Plain nutrition chat text (`responseMimeType: "text/plain"`).
2. Daily verdict JSON (`title`, `message`, `mood`).
3. Weekly 7-day meal plan JSON (`days` array shape).
4. Multimodal Vision food recognition JSON using a real generated/minimal valid JPEG base64 image in `inlineData` (verifies multimodal path end-to-end).

- [ ] **Step 2: Configure local `.secret.local` (gitignored) and run live smoke suite**

Run: `cd functions && npm run smoke`
Expected: PASS on all 4 live checks; inspect which models responded fastest/cleanest and adjust default ordering in `TEXT_MODEL_CHAIN` / `VISION_MODEL_CHAIN` if any top model fails or lags.

- [ ] **Step 3: Update `OPENROUTER_API_KEY` in Firebase Secret Manager safely**

Read existing `OPENROUTER_API_KEY` secret in memory (without printing to terminal/logs), merge + deduplicate with the two new keys, and push updated comma-separated value via `firebase functions:secrets:set OPENROUTER_API_KEY --project serzhanovich-ecosystem-ce700 --data-file -`.

- [ ] **Step 4: Commit `functions/smoke_openrouter.js`**

```bash
git add functions/smoke_openrouter.js
git commit -m "test(functions): add live OpenRouter smoke tests for text, JSON, and vision"
```

---

### Task 4: Safe Isolated Deployment & Live Endpoint Verification

**Files:**
- None modified (deployment & live verification).

- [ ] **Step 1: Verify `firebase functions:list` baseline and deploy ONLY `foodAiProxy`**

Run: `firebase deploy --only functions:foodAiProxy --project serzhanovich-ecosystem-ce700`
Expected: `foodAiProxy` deploys on `nodejs22` in `us-central1` with `OPENROUTER_API_KEY` secret attached; note the exact Cloud Run URL (`https://foodaiproxy-...-uc.a.run.app`).

- [ ] **Step 2: Verify existing functions were untouched & test live endpoint security gate**

Run: `firebase functions:list --project serzhanovich-ecosystem-ce700` (verify `vertexProxy`, `imageProxy`, `moderateSharedWorkout`, `onReportCreated`, `deleteAccount` still exist untouched and `foodAiProxy` is listed).
Run `curl -i -X POST <deployed-url>` without App Check token → Expected: HTTP `401` `{"error":"Missing App Check token"}`.

---

### Task 5: TDD for iOS Client (`AIProxyEndpoint`, `AIResponseParsing`, `GeminiProxyClient`, Language Fix)

**Files:**
- Create: `FoodTracker/Services/AIProxyEndpoint.swift`
- Create: `FoodTracker/Services/AIResponseParsing.swift`
- Modify: `FoodTracker/Services/GeminiProxyClient.swift`
- Modify: `FoodTracker/Services/VertexAIManager.swift`
- Modify: `FoodTracker/AI/AINutritionService.swift`
- Create: `FoodTrackerTests/GeminiProxyClientTests.swift`

**Interfaces:**
- Produces:
  - `AIProxyEndpoint.resolve(configured: String?) -> URL` (`remoteConfigKey = "food_ai_proxy_url"`, fallback = deployed `foodAiProxy` URL)
  - `AIResponseParsing.extractJSON(from raw: String) -> String`
  - `GeminiProxyError.rateLimited(retryAfter: String?)` parsing helper `GeminiProxyClient.extractRetryAfter(header:data:)`

- [ ] **Step 1: Write Swift tests for `AIProxyEndpoint`, `AIResponseParsing`, and language instruction**

Write `FoodTrackerTests/GeminiProxyClientTests.swift` covering HTTPS URL resolution (valid HTTPS override vs empty/http/malformed fallback), balanced JSON object/array extraction from fenced/prose responses (including braces inside quoted strings), and `Retry-After` extraction from HTTP header or JSON body.

- [ ] **Step 2: Run standalone Swift test harness to verify RED**

Run `swift` test script against the new assertions before creating `AIProxyEndpoint.swift` / `AIResponseParsing.swift` → Expected: FAIL (missing symbols).

- [ ] **Step 3: Implement `AIProxyEndpoint.swift`, `AIResponseParsing.swift`, update `GeminiProxyClient.swift`, and fix `\\(currentLanguage)`**

1. Create `FoodTracker/Services/AIProxyEndpoint.swift` with the deployed `foodAiProxy` Cloud Run fallback URL and `remoteConfigKey = "food_ai_proxy_url"`.
2. Create `FoodTracker/Services/AIResponseParsing.swift` with `extractJSON(from:)` that handles fences and balanced `{...}` / `[...]` scanning while respecting string literals and escapes.
3. Update `FoodTracker/Services/GeminiProxyClient.swift`:
   - Resolve endpoint via `RemoteConfigManager.shared.getString(forKey: AIProxyEndpoint.remoteConfigKey)` + `AIProxyEndpoint.resolve(configured:)`.
   - Use configured `URLSession` (`60s` request, `120s` resource, `waitsForConnectivity = true`).
   - Use `try await AnonymousAuthBootstrap.shared.ensureSignedIn()` if `Auth.auth().currentUser == nil`.
   - Parse `Retry-After` from header or JSON `retryAfter` body on `429`.
   - Use `AIResponseParsing.extractJSON(from:)` in `cleanJSONResponse`.
4. Fix `\\(currentLanguage)` → `\(currentLanguage)` in `FoodTracker/Services/VertexAIManager.swift` and `FoodTracker/AI/AINutritionService.swift`.

- [ ] **Step 4: Run Swift unit tests + full `xcodebuild` iOS build**

Run standalone `swift` verification for `AIProxyEndpoint` + `AIResponseParsing` (Expected: PASS).
Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project FoodTracker.xcodeproj -scheme FoodTracker -destination 'generic/platform=iOS' -configuration Debug build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit iOS updates and verify clean git status**

```bash
git add FoodTracker/Services/AIProxyEndpoint.swift FoodTracker/Services/AIResponseParsing.swift FoodTracker/Services/GeminiProxyClient.swift FoodTracker/Services/VertexAIManager.swift FoodTracker/AI/AINutritionService.swift FoodTrackerTests/GeminiProxyClientTests.swift
git commit -m "feat(ai): point FoodTracker iOS client to foodAiProxy and harden JSON/locale handling"
```
