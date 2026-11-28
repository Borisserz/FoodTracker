const test = require("node:test");
const assert = require("node:assert/strict");

process.env.GCLOUD_PROJECT = "serzhanovich-ecosystem-ce700";

const mod = require("./index.js");
const t = mod._test;

test("exports _test helpers and only FoodTracker Cloud Functions", () => {
  assert.ok(t, "_test helpers must be exported");
  assert.equal(typeof mod.foodAiProxy, "function");
  assert.equal(typeof mod.foodSearchProxy, "function");
  assert.equal(typeof mod.foodDeleteAccount, "function");
  assert.equal(mod.vertexProxy, undefined);
  assert.equal(mod.moderateSharedWorkout, undefined);
  assert.equal(mod.onReportCreated, undefined);
  assert.equal(mod.deleteAccount, undefined);
});

test("model chains cover live named ZDR-compatible :free text and vision models without dead, non-ZDR, or wildcard entries", () => {
  assert.deepEqual(t.TEXT_MODEL_CHAIN, [
    "recursive/flint-v1.0:free",
    "google/gemma-4-31b-it:free",
    "google/gemma-4-26b-a4b-it:free",
  ]);
  assert.deepEqual(t.VISION_MODEL_CHAIN, [
    "google/gemma-4-31b-it:free",
    "google/gemma-4-26b-a4b-it:free",
  ]);
  for (const model of [...t.TEXT_MODEL_CHAIN, ...t.VISION_MODEL_CHAIN]) {
    assert.ok(model.endsWith(":free"), `Expected :free model, got ${model}`);
    assert.notEqual(model, "openrouter/free", "Must not include wildcard openrouter/free");
    assert.ok(!model.startsWith("baidu/"), `Must not include baidu model ${model}`);
    assert.notEqual(model, "dots-studio/dots-3-note-preview:free");
    assert.notEqual(model, "inclusionai/ling-3.2-flash:free");
    assert.notEqual(model, "nvidia/nemotron-3.5-super-vl:free");
    assert.notEqual(model, "particle-ai/particle-1:free");
    assert.notEqual(model, "nvidia/nemotron-3.5-lightning:free");
  }

  assert.ok(t.STRUCTURED_MODELS.has("google/gemini-2.5-flash-lite"));
  assert.ok(t.STRUCTURED_MODELS.has("google/gemini-2.5-flash"));
  assert.equal(t.STRUCTURED_MODELS.has("openrouter/free"), false);
  assert.equal(t.STRUCTURED_MODELS.has("baidu/ernie-5.5-flash-preview:free"), false);

  assert.ok(t.JSON_OBJECT_MODELS.has("recursive/flint-v1.0:free"));
  assert.ok(t.JSON_OBJECT_MODELS.has("google/gemma-4-31b-it:free"));
  assert.ok(t.JSON_OBJECT_MODELS.has("google/gemma-4-26b-a4b-it:free"));
  assert.ok(t.JSON_OBJECT_MODELS.has("google/gemini-2.5-flash-lite"));
  assert.ok(t.JSON_OBJECT_MODELS.has("google/gemini-2.5-flash"));
  assert.equal(t.JSON_OBJECT_MODELS.has("nvidia/nemotron-3.5-lightning:free"), false);
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
    model: "google/gemma-4-31b-it:free",
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
    t.stripModelJSON('Here is the result:\n```json\n{"calories": 250, "note": "a } b \\"quoted\\""}\n```\nEnjoy!'),
    '{"calories": 250, "note": "a } b \\"quoted\\""}'
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

test("shouldTryNextKeyForError only retries key on key-scoped errors", () => {
  assert.equal(t.shouldTryNextKeyForError(401, "Invalid key"), true);
  assert.equal(t.shouldTryNextKeyForError(402, "Insufficient credits"), true);
  assert.equal(t.shouldTryNextKeyForError(429, "Per-key rate limit exceeded"), true);
  assert.equal(
    t.shouldTryNextKeyForError(429, '{"limit_source":"upstream_provider_shared_pool"}'),
    false
  );
  assert.equal(t.shouldTryNextKeyForError(400, "invalid_image_url"), false);
  assert.equal(t.shouldTryNextKeyForError(403, "not available in your region"), false);
  assert.equal(t.shouldTryNextKeyForError(422, "media could not be screened"), false);
});

test("parseNumericValue handles numbers, comma decimals, and bad values", () => {
  assert.equal(t.parseNumericValue(12.5), 12.5);
  assert.equal(t.parseNumericValue(" 14,25 "), 14.25);
  assert.equal(t.parseNumericValue(null), 0);
  assert.equal(t.parseNumericValue("abc"), 0);
});

test("isTokenValid enforces 60s safety margin", () => {
  const now = 1_000_000;
  assert.equal(t.isTokenValid(null, now), false);
  assert.equal(t.isTokenValid({ token: "abc", expiresAtMs: now + 30_000 }, now), false);
  assert.equal(t.isTokenValid({ token: "abc", expiresAtMs: now + 120_000 }, now), true);
});

test("normalizeFatSecretFood handles array/object servings and keeps weight = 0 for unmeasured servings", () => {
  const fromArray = t.normalizeFatSecretFood({
    food_name: "Chicken Breast",
    servings: {
      serving: [
        { metric_serving_amount: "0", calories: "165", protein: "31.0", fat: "3,6", carbohydrate: "0" },
        { metric_serving_amount: "200", calories: "330", protein: "62", fat: "7.2", carbohydrate: "0" },
      ],
    },
  });
  assert.deepEqual(fromArray, {
    name: "Chicken Breast",
    weight: 0,
    calories: 165,
    protein: 31,
    fats: 3.6,
    carbs: 0,
  });

  const fromObject = t.normalizeFatSecretFood({
    food_name: "Greek Yogurt",
    servings: {
      serving: { metric_serving_amount: "150", calories: "95", protein: "15", fat: "0.5", carbohydrate: "6" },
    },
  });
  assert.deepEqual(fromObject, {
    name: "Greek Yogurt",
    weight: 150,
    calories: 95,
    protein: 15,
    fats: 0.5,
    carbs: 6,
  });
});

test("normalizeFatSecretSearch and normalizeFatSecretBarcode handle single and empty payloads", () => {
  const singleSearch = t.normalizeFatSecretSearch({
    foods_search: {
      results: {
        food: {
          food_name: "Apple",
          servings: { serving: { metric_serving_amount: "100", calories: "52", protein: "0.3", fat: "0.2", carbohydrate: "14" } },
        },
      },
    },
  });
  assert.equal(singleSearch.length, 1);
  assert.equal(singleSearch[0].name, "Apple");
  assert.deepEqual(t.normalizeFatSecretSearch({}), []);

  const barcodeHit = t.normalizeFatSecretBarcode({
    food: {
      food_name: "Oats",
      servings: { serving: { metric_serving_amount: "40", calories: "150", protein: "5", fat: "3", carbohydrate: "27" } },
    },
  });
  assert.equal(barcodeHit.name, "Oats");
  assert.equal(barcodeHit.weight, 40);
  assert.equal(t.normalizeFatSecretBarcode({}), null);
});

test("parseSearchPayload validates mode, inputs, and clamps maxResults", () => {
  assert.deepEqual(t.parseSearchPayload({ mode: "search", query: "  oats ", maxResults: 99 }), {
    mode: "search",
    query: "oats",
    maxResults: 25,
  });
  assert.deepEqual(t.parseSearchPayload({ mode: "barcode", barcode: " 46012345 " }), {
    mode: "barcode",
    barcode: "46012345",
  });
  assert.throws(() => t.parseSearchPayload({ mode: "search", query: "  " }), /Missing search query/);
  assert.throws(() => t.parseSearchPayload({ mode: "barcode", barcode: "1" }), /Invalid barcode/);
  assert.throws(() => t.parseSearchPayload({ mode: "unknown" }), /Invalid mode/);
});

test("parseFatSecretDescription parses OAuth 1.0 description strings", () => {
  assert.deepEqual(
    t.parseFatSecretDescription(
      "Per 101g - Calories: 197kcal | Fat: 7.79g | Carbs: 0.00g | Protein: 29.80g"
    ),
    { weight: 101, calories: 197, fats: 7.79, carbs: 0, protein: 29.8 }
  );
  assert.deepEqual(
    t.parseFatSecretDescription(
      "Per 1 serving - Calories: 90kcal | Fat: 1g | Carbs: 12g | Protein: 4g"
    ),
    { weight: 0, calories: 90, fats: 1, carbs: 12, protein: 4 }
  );
  assert.equal(t.parseFatSecretDescription("invalid"), null);
});

test("normalizeFatSecretSearch supports OAuth 1.0 foods.food items", () => {
  const items = t.normalizeFatSecretSearch({
    foods: {
      food: [
        {
          food_name: "Apples",
          food_description:
            "Per 100g - Calories: 52kcal | Fat: 0.17g | Carbs: 13.81g | Protein: 0.26g",
        },
        {
          food_name: "Kirkland Chicken",
          brand_name: "Kirkland Signature",
          food_description:
            "Per 4 oz - Calories: 90kcal | Fat: 1g | Carbs: 0g | Protein: 20g",
        },
      ],
    },
  });
  assert.equal(items.length, 2);
  assert.equal(items[0].name, "Apples");
  assert.equal(items[0].calories, 52);
  assert.equal(items[1].name, "Kirkland Chicken (Kirkland Signature)");
  assert.equal(items[1].protein, 20);
});

test("buildOAuth1FatSecretURL builds signed OAuth 1.0 URL", () => {
  const url = t.buildOAuth1FatSecretURL({
    consumerKey: "ck123",
    consumerSecret: "cs456",
    method: "foods.search",
    extraParams: { search_expression: "apple", max_results: "5" },
  });
  const parsed = new URL(url);
  assert.equal(parsed.origin + parsed.pathname, "https://platform.fatsecret.com/rest/server.api");
  assert.equal(parsed.searchParams.get("oauth_consumer_key"), "ck123");
  assert.equal(parsed.searchParams.get("oauth_signature_method"), "HMAC-SHA1");
  assert.equal(parsed.searchParams.get("method"), "foods.search");
  assert.ok(parsed.searchParams.get("oauth_signature"));
});

test("computeRateLimitTransition reserves atomically and rejects at limit", () => {
  const now = 1_700_000_000_000;
  const fresh = t.computeRateLimitTransition(null, now, 200, 7 * 24 * 60 * 60 * 1000);
  assert.deepEqual(fresh, {
    allowed: true,
    nextWindowStart: now,
    nextCount: 1,
    retryAfterSeconds: 0,
  });

  const atLimit = t.computeRateLimitTransition(
    { windowStart: now - 1000, count: 200 },
    now,
    200,
    7 * 24 * 60 * 60 * 1000
  );
  assert.equal(atLimit.allowed, false);
  assert.ok(atLimit.retryAfterSeconds > 0);

  const expiredWindow = t.computeRateLimitTransition(
    { windowStart: now - 8 * 24 * 60 * 60 * 1000, count: 200 },
    now,
    200,
    7 * 24 * 60 * 60 * 1000
  );
  assert.equal(expiredWindow.allowed, true);
  assert.equal(expiredWindow.nextCount, 1);
  assert.equal(expiredWindow.nextWindowStart, now);
});

test("upstreamTimeoutForBody allocates extended budget for heavy weekly plan & vision prompts", () => {
  const shortPrompt = { contents: [{ role: "user", parts: [{ text: "Hi coach" }] }] };
  const heavyPlanPrompt = {
    contents: [
      {
        role: "user",
        parts: [
          {
            text: "Generate a 7-day meal plan (0 to 6) with 4 meals per day " + "x".repeat(700),
          },
        ],
      },
    ],
  };
  const visionPrompt = {
    contents: [{ role: "user", parts: [{ inlineData: { mimeType: "image/jpeg", data: "abc" } }] }],
  };

  const normalMs = t.upstreamTimeoutForBody(shortPrompt);
  const heavyMs = t.upstreamTimeoutForBody(heavyPlanPrompt);
  const visionMs = t.upstreamTimeoutForBody(visionPrompt);

  assert.ok(heavyMs > normalMs, "Heavy 7-day plan must receive higher timeout than short chat");
  assert.ok(visionMs >= heavyMs || visionMs >= 35000);
});

test("normalizeFatSecretFood converts oz metric_serving_unit to grams", () => {
  const result = t.normalizeFatSecretFood({
    food_name: "Cheddar Cheese",
    brand_name: "Tillamook",
    servings: {
      serving: {
        metric_serving_amount: "1.000",
        metric_serving_unit: "oz",
        calories: "110",
        protein: "7",
        fat: "9",
        carbohydrate: "0",
      },
    },
  });

  assert.equal(result.name, "Cheddar Cheese (Tillamook)");
  assert.equal(result.weight, 28.3);
  assert.equal(result.calories, 110);
  assert.equal(result.protein, 7);
  assert.equal(result.fats, 9);
  assert.equal(result.carbs, 0);
});

test("normalizeFatSecretFood prefers 100g serving and converts lb/kg/mg", () => {
  const result = t.normalizeFatSecretFood({
    food_name: "Rolled Oats",
    servings: {
      serving: [
        { serving_description: "1 cup", calories: "300", protein: "10", fat: "5", carbohydrate: "54" },
        {
          metric_serving_amount: "100.000",
          metric_serving_unit: "g",
          calories: "389",
          protein: "16.9",
          fat: "6.9",
          carbohydrate: "66.3",
        },
      ],
    },
  });
  assert.equal(result.weight, 100);
  assert.equal(result.calories, 389);
  assert.equal(result.protein, 16.9);
  assert.equal(Math.round(t.convertMetricWeightToGrams(1, "lb")), 454);
  assert.equal(t.convertMetricWeightToGrams(0.5, "kg"), 500);
  assert.equal(t.convertMetricWeightToGrams(500, "mg"), 0.5);
});

test("parseFatSecretDescription converts Per oz/kg weights cleanly", () => {
  const ozDesc = t.parseFatSecretDescription(
    "Per 4 oz - Calories: 90kcal | Fat: 1g | Carbs: 0g | Protein: 20g"
  );
  assert.equal(ozDesc.weight, 113.4);
  assert.equal(ozDesc.calories, 90);
});

test("deleteFoodAccountData removes scoped quota docs, shared WorkoutTracker docs, and deletes Auth user idempotently", async () => {
  const deletedDocs = [];
  const recursiveDeletedPaths = [];
  const batchDeletedPaths = [];
  const deletedUsers = [];
  const makeDocRef = (path) => ({
    path,
    async delete() {
      deletedDocs.push(path);
    },
  });
  const sharedWorkoutRefs = [makeDocRef("shared_workouts/w1"), makeDocRef("shared_workouts/w2")];
  const reportRefs = [makeDocRef("reports/r1")];

  const mockFirestore = {
    collection(col) {
      return {
        doc(id) {
          return makeDocRef(`${col}/${id}`);
        },
        where(field, op, value) {
          assert.equal(op, "==");
          if (col === "shared_workouts" && field === "creatorUid") {
            return {
              async get() {
                return {
                  docs: value === "uid-123" ? sharedWorkoutRefs.map((ref) => ({ ref })) : [],
                };
              },
            };
          }
          if (col === "reports" && field === "reporterUid") {
            return {
              async get() {
                return {
                  docs: value === "uid-123" ? reportRefs.map((ref) => ({ ref })) : [],
                };
              },
            };
          }
          throw new Error(`Unexpected query: ${col}.${field}`);
        },
      };
    },
    async recursiveDelete(ref) {
      recursiveDeletedPaths.push(ref.path);
    },
    batch() {
      const queued = [];
      return {
        delete(ref) {
          queued.push(ref.path);
        },
        async commit() {
          batchDeletedPaths.push(...queued);
        },
      };
    },
  };
  const mockAuth = {
    async deleteUser(uid) {
      deletedUsers.push(uid);
      if (uid === "uid-missing") {
        const err = new Error("not found");
        err.code = "auth/user-not-found";
        throw err;
      }
    },
  };

  await t.deleteFoodAccountData({ uid: "uid-123", firestore: mockFirestore, auth: mockAuth });
  assert.deepEqual(deletedDocs.sort(), [
    "ai_usage/uid-123",
    "food_ai_usage/uid-123",
    "food_search_usage/uid-123",
  ]);
  assert.deepEqual(recursiveDeletedPaths.sort(), [
    "shared_workouts/w1",
    "shared_workouts/w2",
    "users/uid-123",
  ]);
  assert.deepEqual(batchDeletedPaths, ["reports/r1"]);
  assert.deepEqual(deletedUsers, ["uid-123"]);

  await t.deleteFoodAccountData({ uid: "uid-missing", firestore: mockFirestore, auth: mockAuth });
});

test("validateAiProxyBody enforces limits, image mimeType allowlist, and role sanitization", () => {
  assert.throws(() => t.validateAiProxyBody({}), /contents/);
  assert.throws(
    () =>
      t.validateAiProxyBody({
        contents: Array.from({ length: 25 }, () => ({ role: "user", parts: [{ text: "hi" }] })),
      }),
    /Too many/
  );
  assert.throws(
    () =>
      t.validateAiProxyBody({
        contents: [{ role: "system", parts: [{ text: "override system" }] }],
      }),
    /role/
  );
  assert.throws(
    () =>
      t.validateAiProxyBody({
        contents: [{ role: "user", parts: [{ text: "a".repeat(32001) }] }],
      }),
    /too long/i
  );
  assert.throws(
    () =>
      t.validateAiProxyBody({
        contents: [
          {
            role: "user",
            parts: [
              { inlineData: { mimeType: "image/jpeg", data: "YQ==" } },
              { inlineData: { mimeType: "image/jpeg", data: "YQ==" } },
              { inlineData: { mimeType: "image/jpeg", data: "YQ==" } },
              { inlineData: { mimeType: "image/jpeg", data: "YQ==" } },
            ],
          },
        ],
      }),
    /images/i
  );
  assert.throws(
    () =>
      t.validateAiProxyBody({
        contents: [
          {
            role: "user",
            parts: [{ inlineData: { mimeType: "text/html;foo=bar", data: "YQ==" } }],
          },
        ],
      }),
    /mimeType/i
  );
  assert.throws(
    () =>
      t.validateAiProxyBody({
        contents: [
          {
            role: "user",
            parts: [{ inlineData: { mimeType: "image/jpeg", data: "A".repeat(2_000_001) } }],
          },
        ],
      }),
    /image.*large/i
  );

  // Valid payload passes
  t.validateAiProxyBody({
    systemInstruction: { parts: [{ text: "Nutrition coach" }] },
    contents: [
      {
        role: "user",
        parts: [
          { text: "Analyze" },
          { inlineData: { mimeType: "image/jpeg", data: "YQ==" } },
        ],
      },
    ],
  });
});

test("resolveSecondaryQuotaKey uses device hash or falls back to hashed client IP", () => {
  const withDevice = t.resolveSecondaryQuotaKey({
    header: (name) =>
      name.toLowerCase() === "x-device-install-id" ? "ABCD1234-5678-90AB-CDEF-1234567890AB" : "",
    ip: "203.0.113.10",
  });
  assert.ok(withDevice.startsWith("device:"));

  const missingDevice = t.resolveSecondaryQuotaKey({
    header: (name) => (name.toLowerCase() === "x-forwarded-for" ? "198.51.100.7, 10.0.0.1" : ""),
    ip: "127.0.0.1",
  });
  assert.ok(missingDevice.startsWith("ip:"));

  const sameIpDirect = t.resolveSecondaryQuotaKey({
    header: (name) => (name.toLowerCase() === "x-device-install-id" ? "bad" : ""),
    ip: "198.51.100.7",
  });
  assert.equal(missingDevice, sameIpDirect);
});

test("normalizeFatSecretFood selects mg metric serving over non-metric serving", () => {
  const result = t.normalizeFatSecretFood({
    food_name: "Vitamin Powder",
    servings: {
      serving: [
        { serving_description: "1 scoop", calories: "40", protein: "0", fat: "0", carbohydrate: "10" },
        {
          metric_serving_amount: "50000",
          metric_serving_unit: "mg",
          calories: "120",
          protein: "20",
          fat: "1",
          carbohydrate: "5",
        },
      ],
    },
  });
  assert.equal(result.weight, 50);
  assert.equal(result.calories, 120);
});

test("stripModelJSON ignores citation brackets like [1] before real JSON", () => {
  const extracted = t.stripModelJSON('Option [1]: {"calories": 420, "name": "Oats"}');
  assert.equal(extracted, '{"calories": 420, "name": "Oats"}');
});

test("validateAiProxyBody rejects systemInstruction images and deep responseSchema", () => {
  assert.throws(
    () =>
      t.validateAiProxyBody({
        systemInstruction: { parts: [{ inlineData: { mimeType: "image/jpeg", data: "YQ==" } }] },
        contents: [{ role: "user", parts: [{ text: "Hi" }] }],
      }),
    /systemInstruction/i
  );

  let deep = { type: "OBJECT", properties: {} };
  let cursor = deep;
  for (let i = 0; i < 15; i++) {
    cursor.properties.child = { type: "OBJECT", properties: {} };
    cursor = cursor.properties.child;
  }
  assert.throws(
    () =>
      t.validateAiProxyBody({
        contents: [{ role: "user", parts: [{ text: "Hi" }] }],
        generationConfig: { responseSchema: deep },
      }),
    /schema|depth/i
  );
});

test("parseFatSecretDescription handles fl oz & mg and parseNumericValue handles 1,250", () => {
  assert.equal(t.parseNumericValue("1,250"), 1250);
  const flOzDesc = t.parseFatSecretDescription(
    "Per 8 fl oz - Calories: 110kcal | Fat: 0g | Carbs: 26g | Protein: 0g"
  );
  assert.equal(flOzDesc.weight, 236.6);
  const mgDesc = t.parseFatSecretDescription(
    "Per 500 mg - Calories: 5kcal | Fat: 0g | Carbs: 1g | Protein: 0g"
  );
  assert.equal(mgDesc.weight, 0.5);
});

test("geminiBodyToOpenAI enforces data_collection deny and clamps temperature", () => {
  const body = t.geminiBodyToOpenAI(
    {
      contents: [{ role: "user", parts: [{ text: "Hi" }] }],
      generationConfig: { temperature: 99 },
    },
    { streaming: false, model: "google/gemma-3-27b-it:free" }
  );
  assert.equal(body.provider?.data_collection, "deny");
  assert.equal(body.temperature, 2);
});

test("geminiBodyToOpenAI forwards clamped maxOutputTokens as max_tokens", () => {
  const standard = t.geminiBodyToOpenAI(
    {
      contents: [{ role: "user", parts: [{ text: "Weekly plan" }] }],
      generationConfig: { maxOutputTokens: 8192 },
    },
    { streaming: false, model: "google/gemma-3-27b-it:free" }
  );
  assert.equal(standard.max_tokens, 8192);

  const clampedHigh = t.geminiBodyToOpenAI(
    {
      contents: [{ role: "user", parts: [{ text: "Huge" }] }],
      generationConfig: { maxOutputTokens: 99999 },
    },
    { streaming: false, model: "google/gemma-3-27b-it:free" }
  );
  assert.equal(clampedHigh.max_tokens, 16384);

  const invalid = t.geminiBodyToOpenAI(
    {
      contents: [{ role: "user", parts: [{ text: "Bad" }] }],
      generationConfig: { maxOutputTokens: -10 },
    },
    { streaming: false, model: "google/gemma-3-27b-it:free" }
  );
  assert.equal(invalid.max_tokens, undefined);
});

test("resolveIpQuotaKey extracts hashed IP even when X-Device-Install-ID is sent", () => {
  const reqWithDevice = {
    header: (name) =>
      name.toLowerCase() === "x-device-install-id" ? "SPOOFED-DEVICE-ID-1234567890" : "",
    ip: "203.0.113.55",
  };
  const secondary = t.resolveSecondaryQuotaKey(reqWithDevice);
  const ipKey = t.resolveIpQuotaKey(reqWithDevice);
  assert.ok(secondary.startsWith("device:"));
  assert.ok(ipKey.startsWith("ip:"));
  assert.notEqual(secondary, ipKey);
});

test("validateAiProxyBody rejects whitespace in base64 and normalizes mimeType casing", () => {
  assert.throws(
    () =>
      t.validateAiProxyBody({
        contents: [
          {
            role: "user",
            parts: [{ inlineData: { mimeType: "image/jpeg", data: "YQ==\nYQ==" } }],
          },
        ],
      }),
    /base64|whitespace/i
  );

  const payload = {
    contents: [
      {
        role: "user",
        parts: [{ inlineData: { mimeType: " IMAGE/JPEG ", data: "YQ==" } }],
      },
    ],
  };
  t.validateAiProxyBody(payload);
  assert.equal(payload.contents[0].parts[0].inlineData.mimeType, "image/jpeg");
});

test("assertFatSecretDetailSuccess throws on FatSecret food.get error payloads", () => {
  assert.doesNotThrow(() => t.assertFatSecretDetailSuccess({ food: { food_name: "Apple" } }));
  assert.throws(
    () => t.assertFatSecretDetailSuccess({ error: { code: 12, message: "Internal error" } }),
    /FatSecret detail error 12/
  );
});

test("sanitizeUpstreamErrorMessage strips raw model names and upstream URLs", () => {
  const clean = t.sanitizeUpstreamErrorMessage("OpenRouter 429 google/gemma-3-27b-it:free https://openrouter.ai/secret");
  assert.ok(!clean.includes("gemma"));
  assert.ok(!clean.includes("openrouter.ai"));
  assert.ok(clean.length > 0);
});

test("verifyFirebaseUser enforces checkRevoked=true and returns 401 on revoked token", async () => {
  let seenToken = null;
  let seenCheckRevoked = null;
  const mockReq = { header: (name) => (name === "Authorization" ? "Bearer valid-jwt" : "") };
  const mockRes = {
    statusCode: null,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  const uid = await t.verifyFirebaseUser(mockReq, mockRes, async (token, checkRevoked) => {
    seenToken = token;
    seenCheckRevoked = checkRevoked;
    return { uid: "u123" };
  });
  assert.equal(uid, "u123");
  assert.equal(seenToken, "valid-jwt");
  assert.equal(seenCheckRevoked, true);

  const revokedRes = {
    statusCode: null,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  const revokedUid = await t.verifyFirebaseUser(mockReq, revokedRes, async () => {
    const err = new Error("Token revoked");
    err.code = "auth/id-token-revoked";
    throw err;
  });
  assert.equal(revokedUid, null);
  assert.equal(revokedRes.statusCode, 401);
  assert.match(revokedRes.body?.error || "", /revoked/i);
});

test("verifyAppCheck pins decoded.appId to FoodTracker appId allowlist", async () => {
  const mkReq = (tok) => ({ header: (n) => (n.toLowerCase() === "x-firebase-appcheck" ? tok : "") });
  const mkRes = () => ({
    statusCode: null,
    body: null,
    status(c) { this.statusCode = c; return this; },
    json(p) { this.body = p; return this; },
  });

  const okRes = mkRes();
  const ok = await t.verifyAppCheck(mkReq("tok-ft"), okRes, async () => ({
    appId: "1:667537183554:ios:d28f3e33988402cc786edb",
  }));
  assert.equal(ok, true);

  const wrongRes = mkRes();
  const wrong = await t.verifyAppCheck(mkReq("tok-wt"), wrongRes, async () => ({
    appId: "1:667537183554:ios:9999999999999999999999",
  }));
  assert.equal(wrong, false);
  assert.equal(wrongRes.statusCode, 401);
});

test("validateAiProxyBody rejects oversized responseSchema", () => {
  const props = {};
  for (let i = 0; i < 400; i++) {
    props[`field_${i}`] = { type: "STRING", description: "Long description padding ".repeat(3) };
  }
  assert.throws(
    () =>
      t.validateAiProxyBody({
        contents: [{ role: "user", parts: [{ text: "Hi" }] }],
        generationConfig: {
          responseSchema: { type: "OBJECT", properties: props },
        },
      }),
    /responseSchema/i
  );
});

test("sanitizeModelOverrides filters out non-free and undisclosed-vendor models", () => {
  const cleaned = t.sanitizeModelOverrides([
    "nvidia/nemotron-3.5-super-vl:free",
    "openai/gpt-4o",
    "anthropic/claude-3.5-sonnet",
    "recursive/flint-v1.0:free",
    "google/gemma-4-31b-it:free",
  ]);
  assert.deepEqual(cleaned, [
    "recursive/flint-v1.0:free",
    "google/gemma-4-31b-it:free",
  ]);
});

test("resolveIpQuotaKey normalizes IPv4-mapped IPv6 and ignores CGNAT/link-local/ULA", () => {
  const v4 = t.resolveIpQuotaKey({ ip: "203.0.113.55", header: () => "" });
  const v6Mapped = t.resolveIpQuotaKey({ ip: "::ffff:203.0.113.55", header: () => "" });
  assert.equal(v4, v6Mapped);

  const xffReq = {
    ip: "::ffff:10.0.0.5",
    header: (n) => (n.toLowerCase() === "x-forwarded-for" ? "198.51.100.2, 100.64.0.1, fe80::1" : ""),
  };
  const publicReq = { ip: "198.51.100.2", header: () => "" };
  assert.equal(t.resolveIpQuotaKey(xffReq), t.resolveIpQuotaKey(publicReq));
});

test("resolveUserQuotaLimit enforces stricter cap for anonymous provider", () => {
  const anonLimit = t.resolveUserQuotaLimit(200, "anonymous", "ai");
  const appleLimit = t.resolveUserQuotaLimit(200, "apple.com", "ai");
  assert.ok(anonLimit < appleLimit);
  assert.equal(appleLimit, 200);
});

test("assertFatSecretResponseSuccess throws on OAuth2 error envelopes", () => {
  assert.doesNotThrow(() => t.assertFatSecretResponseSuccess({ foods: { food: [] } }));
  assert.throws(
    () => t.assertFatSecretResponseSuccess({ error: { code: 5, message: "Invalid signature" } }),
    /FatSecret error 5/
  );
});

test("normalizeFatSecretFood forwards optional micronutrients and converts %DV fields", () => {
  const hit = t.normalizeFatSecretFood({
    food_name: "Atlantic Salmon",
    servings: {
      serving: {
        metric_serving_amount: "100",
        metric_serving_unit: "g",
        calories: "208",
        protein: "20",
        fat: "13",
        carbohydrate: "0",
        potassium: "363",
        calcium: "2",
        iron: "2",
        vitamin_c: "5",
        vitamin_d: "55",
      },
    },
  });
  assert.equal(hit.potassium, 363);
  assert.equal(hit.calcium, 26);
  assert.equal(hit.iron, 0.36);
  assert.equal(hit.vitaminC, 4.5);
  assert.equal(hit.vitaminD, 11);
});

test("normalizeFatSecretBarcodeInput zero-pads 8 and 12 digit barcodes to 13-digit GTIN-13", () => {
  assert.equal(t.normalizeFatSecretBarcodeInput("012345678905"), "0012345678905");
  assert.equal(t.normalizeFatSecretBarcodeInput("12345670"), "0000012345670");
  assert.equal(t.normalizeFatSecretBarcodeInput("4601234567890"), "4601234567890");
});

test("verifyFirebaseUser enforces recent auth_time when requireRecentAuthSec is set for non-anonymous users", async () => {
  const nowSec = Math.floor(Date.now() / 1000);
  const makeRes = () => {
    const out = { statusCode: 0, body: null };
    return {
      status(c) { out.statusCode = c; return this; },
      json(b) { out.body = b; return this; },
      _out: out,
    };
  };
  const makeReq = () => ({ header: (n) => (n.toLowerCase() === "authorization" ? "Bearer valid-jwt" : "") });

  const staleRes = makeRes();
  const staleUid = await t.verifyFirebaseUser(
    makeReq(),
    staleRes,
    async () => ({ uid: "u1", auth_time: nowSec - 900, firebase: { sign_in_provider: "apple.com" } }),
    { requireRecentAuthSec: 300 }
  );
  assert.equal(staleUid, null);
  assert.equal(staleRes._out.statusCode, 401);
  assert.equal(staleRes._out.body?.error, "requires_recent_login");

  const freshRes = makeRes();
  const freshUid = await t.verifyFirebaseUser(
    makeReq(),
    freshRes,
    async () => ({ uid: "u1", auth_time: nowSec - 30, firebase: { sign_in_provider: "apple.com" } }),
    { requireRecentAuthSec: 300 }
  );
  assert.equal(freshUid, "u1");

  const anonRes = makeRes();
  const anonUid = await t.verifyFirebaseUser(
    makeReq(),
    anonRes,
    async () => ({ uid: "anon1", auth_time: nowSec - 9000, firebase: { sign_in_provider: "anonymous" } }),
    { requireRecentAuthSec: 300 }
  );
  assert.equal(anonUid, "anon1");
});

test("ENDPOINT_AUTH_OPTIONS allows older auth_time for foodAiProxy and foodSearchProxy while enforcing recent login on foodDeleteAccount", async () => {
  assert.ok(t.ENDPOINT_AUTH_OPTIONS, "ENDPOINT_AUTH_OPTIONS must be exported");
  const nowSec = Math.floor(Date.now() / 1000);
  const makeReq = () => ({ header: (n) => (n.toLowerCase() === "authorization" ? "Bearer valid-jwt" : "") });
  const makeRes = () => {
    const out = { statusCode: 0, body: null };
    return {
      status(c) { out.statusCode = c; return this; },
      json(b) { out.body = b; return this; },
      _out: out,
    };
  };
  const staleAppleUser = async () => ({
    uid: "apple-user-1",
    auth_time: nowSec - 7200,
    firebase: { sign_in_provider: "apple.com" },
  });

  const aiRes = makeRes();
  const aiUid = await t.verifyFirebaseUser(makeReq(), aiRes, staleAppleUser, t.ENDPOINT_AUTH_OPTIONS.foodAiProxy);
  assert.equal(aiUid, "apple-user-1");

  const searchRes = makeRes();
  const searchUid = await t.verifyFirebaseUser(makeReq(), searchRes, staleAppleUser, t.ENDPOINT_AUTH_OPTIONS.foodSearchProxy);
  assert.equal(searchUid, "apple-user-1");

  const deleteRes = makeRes();
  const deleteUid = await t.verifyFirebaseUser(makeReq(), deleteRes, staleAppleUser, t.ENDPOINT_AUTH_OPTIONS.foodDeleteAccount);
  assert.equal(deleteUid, null);
  assert.equal(deleteRes._out.statusCode, 401);
  assert.equal(deleteRes._out.body?.error, "requires_recent_login");
});

test("SSE stream helpers set no-cache headers, flushHeaders, and ensure terminal [DONE] marker", () => {
  assert.equal(typeof t.beginSSEStreamResponse, "function");
  assert.equal(typeof t.finishSSEStreamResponse, "function");

  const headers = {};
  const chunks = [];
  let flushed = false;
  let ended = false;
  const res = {
    statusCode: 0,
    status(c) { this.statusCode = c; return this; },
    set(k, v) { headers[k] = v; return this; },
    flushHeaders() { flushed = true; },
    write(chunk) { chunks.push(chunk); },
    end() { ended = true; },
  };

  t.beginSSEStreamResponse(res);
  assert.equal(res.statusCode, 200);
  assert.equal(headers["Content-Type"], "text/event-stream");
  assert.equal(headers["Cache-Control"], "no-cache, no-transform");
  assert.equal(headers["Connection"], "keep-alive");
  assert.equal(flushed, true);

  t.finishSSEStreamResponse(res, { yielded: true, emittedDone: false });
  assert.equal(chunks.includes("data: [DONE]\n\n"), true);
  assert.equal(ended, true);

  // If [DONE] was already emitted, don't duplicate it.
  chunks.length = 0;
  ended = false;
  t.finishSSEStreamResponse(res, { yielded: true, emittedDone: true });
  assert.equal(chunks.length, 0);
  assert.equal(ended, true);
});

test("verifyFirebaseUser enforces recent auth_time even when sign_in_provider claim is missing", async () => {
  const staleSec = Math.floor(Date.now() / 1000) - 600;
  const req = { header: (k) => (k.toLowerCase() === "authorization" ? "Bearer tok" : "") };
  const out = { statusCode: 0, body: null };
  const res = {
    status(c) { out.statusCode = c; return this; },
    json(b) { out.body = b; return this; },
  };
  const uid = await t.verifyFirebaseUser(
    req,
    res,
    async () => ({ uid: "u1", auth_time: staleSec, firebase: {} }),
    { requireRecentAuthSec: 300 }
  );
  assert.equal(uid, null);
  assert.equal(out.statusCode, 401);
  assert.equal(out.body?.error, "requires_recent_login");
});

test("isMeaningfulJsonOutput rejects empty object/array and accepts populated payloads", () => {
  assert.equal(t.isMeaningfulJsonOutput("{}"), false);
  assert.equal(t.isMeaningfulJsonOutput("[]"), false);
  assert.equal(t.isMeaningfulJsonOutput('{"mealName":"Oats"}'), true);
  assert.equal(t.isMeaningfulJsonOutput('[{"name":"Apple"}]'), true);
});

test("resolveDeviceQuotaLimit tightens anonymous device quota to curb reset abuse", () => {
  assert.equal(t.resolveDeviceQuotaLimit(200, "anonymous", "ai"), 120);
  assert.equal(t.resolveDeviceQuotaLimit(200, "apple.com", "ai"), 400);
  assert.equal(t.resolveDeviceQuotaLimit(1000, "anonymous", "search"), 500);
  assert.equal(t.resolveDeviceQuotaLimit(1000, "google.com", "search"), 2000);
});

test("validateAiProxyBody rejects unsupported responseMimeType", () => {
  assert.throws(
    () =>
      t.validateAiProxyBody({
        contents: [{ role: "user", parts: [{ text: "hello" }] }],
        generationConfig: { responseMimeType: "text/html" },
      }),
    /responseMimeType/i
  );
});

test("openAIStreamChunkToGemini throws on mid-stream upstream error object", () => {
  assert.throws(
    () => t.openAIStreamChunkToGemini('data: {"error":{"message":"Upstream interrupted"}}'),
    /Upstream interrupted/
  );
});

test("normalizeFatSecretBarcodeInput expands 8-digit UPC-E to 13-digit GTIN-13", () => {
  assert.equal(t.normalizeFatSecretBarcodeInput("04252614"), "0042100005264");
  assert.equal(t.normalizeFatSecretBarcodeInput("01234565"), "0012345000065");
  // Valid EAN-8 still zero-pads directly to 13 digits
  assert.equal(t.normalizeFatSecretBarcodeInput("12345670"), "0000012345670");
});

test("normalizeFatSecretFood preserves weight = 0 and servingDescription when metric_serving_amount is missing", () => {
  const item = t.normalizeFatSecretFood({
    food_name: "Pizza Slice",
    servings: {
      serving: {
        serving_description: "1 slice",
        calories: "280",
        protein: "12",
        fat: "10",
        carbohydrate: "34",
      },
    },
  });
  assert.equal(item.weight, 0);
  assert.equal(item.servingDescription, "1 slice");
  assert.equal(item.calories, 280);
});

test("normalizeFatSecretFood converts % Daily Value micronutrients to mg and mcg", () => {
  const hit = t.normalizeFatSecretFood({
    food_name: "Fortified Milk",
    servings: {
      serving: {
        metric_serving_amount: "240",
        metric_serving_unit: "ml",
        calories: "120",
        protein: "8",
        fat: "5",
        carbohydrate: "12",
        potassium: "363",
        calcium: "10",
        iron: "20",
        vitamin_c: "50",
        vitamin_d: "25",
      },
    },
  });
  assert.equal(hit.potassium, 363);
  assert.equal(hit.calcium, 130);
  assert.equal(hit.iron, 3.6);
  assert.equal(hit.vitaminC, 45);
  assert.equal(hit.vitaminD, 5);
});

test("resolveAllowPaidFallback defaults off (zero spend) and only enables on explicit Firestore or env opt-in", () => {
  assert.equal(t.resolveAllowPaidFallback(undefined, undefined), false);
  assert.equal(t.resolveAllowPaidFallback(undefined, ""), false);
  assert.equal(t.resolveAllowPaidFallback(undefined, "false"), false);
  assert.equal(t.resolveAllowPaidFallback(undefined, "true"), true);
  assert.equal(t.resolveAllowPaidFallback(false, "true"), false);
  assert.equal(t.resolveAllowPaidFallback(true, "false"), true);
  assert.equal(t.resolveAllowPaidFallback(true, undefined), true);
});

test("shouldYieldFreeSlotToPaidFallback reserves the tail budget for the SLA model", () => {
  const chain = ["mock/free-model:free", "google/gemini-2.5-flash-lite"];
  assert.equal(
    t.shouldYieldFreeSlotToPaidFallback("mock/free-model:free", chain, t.PAID_FALLBACK_RESERVE_MS - 1),
    true
  );
  assert.equal(
    t.shouldYieldFreeSlotToPaidFallback("mock/free-model:free", chain, t.PAID_FALLBACK_RESERVE_MS),
    false
  );
  assert.equal(
    t.shouldYieldFreeSlotToPaidFallback("google/gemini-2.5-flash-lite", chain, 1000),
    false
  );
  assert.equal(
    t.shouldYieldFreeSlotToPaidFallback("mock/free-model:free", ["mock/free-model:free"], 1000),
    false
  );
});

test("modelChainForRequest appends deduplicated paid SLA fallback models only when allowPaidFallback is enabled", () => {
  const textReq = { contents: [{ role: "user", parts: [{ text: "hello" }] }] };
  const imgReq = {
    contents: [
      {
        role: "user",
        parts: [{ inlineData: { mimeType: "image/jpeg", data: "YWJj" } }],
      },
    ],
  };

  const defaultText = t.modelChainForRequest(textReq, {});
  assert.ok(defaultText.every((m) => m.endsWith(":free") || m === "openrouter/free"));

  const withPaidText = t.modelChainForRequest(textReq, { allowPaidFallback: true });
  assert.ok(t.PAID_TEXT_FALLBACK_MODELS.length >= 1);
  assert.deepEqual(
    withPaidText.slice(-t.PAID_TEXT_FALLBACK_MODELS.length),
    t.PAID_TEXT_FALLBACK_MODELS
  );
  assert.ok(t.STRUCTURED_MODELS.has(t.PAID_TEXT_FALLBACK_MODELS[0]));
  assert.ok(t.JSON_OBJECT_MODELS.has(t.PAID_TEXT_FALLBACK_MODELS[0]));

  const withPaidVision = t.modelChainForRequest(imgReq, {
    allowPaidFallback: true,
    visionModels: ["custom/vl:free"],
    paidVisionModels: ["google/gemini-2.5-flash", "custom/vl:free"],
  });
  assert.deepEqual(withPaidVision, ["custom/vl:free", "google/gemini-2.5-flash"]);
});

test("sanitizeModelOverrides restricts to disclosed vendors and :free by default, allowing disclosed paid models when allowPaid is true", () => {
  assert.deepEqual(
    t.sanitizeModelOverrides(["google/gemini-2.5-flash", "recursive/flint-v1.0:free", "openai/gpt-4o:free"]),
    ["recursive/flint-v1.0:free"]
  );
  assert.deepEqual(
    t.sanitizeModelOverrides(["google/gemini-2.5-flash", " recursive/flint-v1.0:free ", "anthropic/claude-3.5-sonnet", ""], { allowPaid: true }),
    ["google/gemini-2.5-flash", "recursive/flint-v1.0:free"]
  );
});

test("callOpenRouterText falls back to paid SLA model when free chain fails and allowPaidFallback is enabled", async () => {
  const originalFetch = globalThis.fetch;
  const calledModels = [];
  globalThis.fetch = async (_url, init) => {
    const parsed = JSON.parse(init.body);
    calledModels.push(parsed.model);
    if (parsed.model.endsWith(":free")) {
      return {
        ok: false,
        status: 429,
        text: async () => "upstream_provider_shared_pool",
      };
    }
    return {
      ok: true,
      status: 200,
      text: async () =>
        JSON.stringify({
          choices: [{ message: { content: '{"mealName":"Oatmeal"}' } }],
        }),
    };
  };

  try {
    const result = await t.callOpenRouterText({
      apiKeys: ["sk-test"],
      geminiBody: {
        contents: [{ role: "user", parts: [{ text: "Oatmeal" }] }],
        generationConfig: { responseMimeType: "application/json" },
      },
      overrides: {
        textModels: ["mock/free-model:free"],
        allowPaidFallback: true,
        paidTextModels: ["google/gemini-2.5-flash-lite"],
      },
    });
    assert.deepEqual(calledModels, ["mock/free-model:free", "google/gemini-2.5-flash-lite"]);
    assert.equal(
      result.candidates[0].content.parts[0].text,
      '{"mealName":"Oatmeal"}'
    );
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("foodAiProxy limits container concurrency to 8 for 512MiB multimodal safety", () => {
  assert.equal(mod.foodAiProxy.__endpoint.concurrency, 8);
});

test("shouldRefundQuotaSlot refunds only when nothing was yielded, no completion received, and no paid model attempted", () => {
  assert.equal(typeof t.shouldRefundQuotaSlot, "function");
  assert.equal(
    t.shouldRefundQuotaSlot({ yielded: false, receivedCompletion: false, attemptedPaid: false }),
    true
  );
  assert.equal(
    t.shouldRefundQuotaSlot({ yielded: true, receivedCompletion: false, attemptedPaid: false }),
    false
  );
  assert.equal(
    t.shouldRefundQuotaSlot({ yielded: false, receivedCompletion: true, attemptedPaid: false }),
    false
  );
  assert.equal(
    t.shouldRefundQuotaSlot({ yielded: false, receivedCompletion: false, attemptedPaid: true }),
    false
  );
  assert.equal(
    t.shouldRefundQuotaSlot({ yielded: true, receivedCompletion: true, attemptedPaid: true }),
    false
  );
});

test("callOpenRouterText tracks attemptMeta and stops paid cascade on invalid or empty JSON", async () => {
  const originalFetch = globalThis.fetch;

  try {
    // 1. Free model fails with 429 before completion -> refundable
    const metaFree429 = { receivedCompletion: false, attemptedPaid: false };
    globalThis.fetch = async () => ({
      ok: false,
      status: 429,
      text: async () => "upstream_provider_shared_pool",
    });
    await assert.rejects(
      () =>
        t.callOpenRouterText({
          apiKeys: ["sk-test"],
          geminiBody: {
            contents: [{ role: "user", parts: [{ text: "Oatmeal" }] }],
            generationConfig: { responseMimeType: "application/json" },
          },
          overrides: { textModels: ["mock/free:free"], allowPaidFallback: false },
          attemptMeta: metaFree429,
        }),
      /429/
    );
    assert.deepEqual(metaFree429, { receivedCompletion: false, attemptedPaid: false });
    assert.equal(t.shouldRefundQuotaSlot({ yielded: false, ...metaFree429 }), true);

    // 2. Free model returns HTTP 200 with invalid JSON -> receivedCompletion=true -> NOT refundable
    const metaFreeInvalidJson = { receivedCompletion: false, attemptedPaid: false };
    globalThis.fetch = async () => ({
      ok: true,
      status: 200,
      text: async () =>
        JSON.stringify({ choices: [{ message: { content: "Sorry, I cannot output JSON." } }] }),
    });
    await assert.rejects(
      () =>
        t.callOpenRouterText({
          apiKeys: ["sk-test"],
          geminiBody: {
            contents: [{ role: "user", parts: [{ text: "Break JSON" }] }],
            generationConfig: { responseMimeType: "application/json" },
          },
          overrides: { textModels: ["mock/free:free"], allowPaidFallback: false },
          attemptMeta: metaFreeInvalidJson,
        }),
      /Invalid JSON output/
    );
    assert.deepEqual(metaFreeInvalidJson, { receivedCompletion: true, attemptedPaid: false });
    assert.equal(t.shouldRefundQuotaSlot({ yielded: false, ...metaFreeInvalidJson }), false);

    // 3. Paid model returns HTTP 200 with invalid JSON -> breaks outer loop, never calls second paid model
    const calledOnInvalidJson = [];
    const metaPaidInvalidJson = { receivedCompletion: false, attemptedPaid: false };
    globalThis.fetch = async (_url, init) => {
      const parsed = JSON.parse(init.body);
      calledOnInvalidJson.push(parsed.model);
      if (parsed.model.endsWith(":free")) {
        return { ok: false, status: 429, text: async () => "upstream_provider_shared_pool" };
      }
      return {
        ok: true,
        status: 200,
        text: async () =>
          JSON.stringify({ choices: [{ message: { content: "not valid json" } }] }),
      };
    };
    await assert.rejects(
      () =>
        t.callOpenRouterText({
          apiKeys: ["sk-test"],
          geminiBody: {
            contents: [{ role: "user", parts: [{ text: "Adversarial prompt" }] }],
            generationConfig: { responseMimeType: "application/json" },
          },
          overrides: {
            textModels: ["mock/free:free"],
            allowPaidFallback: true,
            paidTextModels: ["google/gemini-2.5-flash-lite", "google/gemini-2.5-flash"],
          },
          attemptMeta: metaPaidInvalidJson,
        }),
      /Invalid JSON output/
    );
    assert.deepEqual(calledOnInvalidJson, ["mock/free:free", "google/gemini-2.5-flash-lite"]);
    assert.deepEqual(metaPaidInvalidJson, { receivedCompletion: true, attemptedPaid: true });
    assert.equal(t.shouldRefundQuotaSlot({ yielded: false, ...metaPaidInvalidJson }), false);

    // 4. Paid model returns HTTP 200 with empty JSON container "{}" -> breaks outer loop, never calls second paid model
    const calledOnEmptyJson = [];
    const metaPaidEmptyJson = { receivedCompletion: false, attemptedPaid: false };
    globalThis.fetch = async (_url, init) => {
      const parsed = JSON.parse(init.body);
      calledOnEmptyJson.push(parsed.model);
      return {
        ok: true,
        status: 200,
        text: async () => JSON.stringify({ choices: [{ message: { content: "{}" } }] }),
      };
    };
    await assert.rejects(
      () =>
        t.callOpenRouterText({
          apiKeys: ["sk-test"],
          geminiBody: {
            contents: [{ role: "user", parts: [{ text: "Adversarial empty" }] }],
            generationConfig: { responseMimeType: "application/json" },
          },
          overrides: {
            textModels: ["google/gemini-2.5-flash-lite", "google/gemini-2.5-flash"],
            allowPaidFallback: false,
          },
          attemptMeta: metaPaidEmptyJson,
        }),
      /Invalid JSON output/
    );
    assert.deepEqual(calledOnEmptyJson, ["google/gemini-2.5-flash-lite"]);
    assert.deepEqual(metaPaidEmptyJson, { receivedCompletion: true, attemptedPaid: true });
    assert.equal(t.shouldRefundQuotaSlot({ yielded: false, ...metaPaidEmptyJson }), false);

    // 5. Paid model fails with HTTP 503 -> attemptedPaid=true, receivedCompletion=false -> NOT refundable
    const metaPaid503 = { receivedCompletion: false, attemptedPaid: false };
    globalThis.fetch = async () => ({
      ok: false,
      status: 503,
      text: async () => "service unavailable",
    });
    await assert.rejects(
      () =>
        t.callOpenRouterText({
          apiKeys: ["sk-test"],
          geminiBody: { contents: [{ role: "user", parts: [{ text: "Hi" }] }] },
          overrides: {
            textModels: ["google/gemini-2.5-flash-lite"],
            allowPaidFallback: false,
          },
          attemptMeta: metaPaid503,
        }),
      /503/
    );
    assert.deepEqual(metaPaid503, { receivedCompletion: false, attemptedPaid: true });
    assert.equal(t.shouldRefundQuotaSlot({ yielded: false, ...metaPaid503 }), false);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test("shouldTryNextKeyForError skips key rotation for upstream provider rate-limit phrases", () => {
  assert.equal(
    t.shouldTryNextKeyForError(
      429,
      '{"error":{"message":"Provider returned error","code":429,"metadata":{"raw":"google/gemma-4-31b-it:free is temporarily rate-limited upstream. Please retry shortly."}}}'
    ),
    false
  );
  assert.equal(
    t.shouldTryNextKeyForError(429, '{"error":{"message":"Rate limit exceeded: free-models-per-day"}}'),
    true
  );
});

test("resolveAllowVertexFallback enables Vertex fallback by default for vision only and honors explicit overrides", () => {
  assert.equal(t.resolveAllowVertexFallback(undefined, { isVision: true, envValue: undefined }), true);
  assert.equal(t.resolveAllowVertexFallback(undefined, { isVision: false, envValue: undefined }), false);
  assert.equal(t.resolveAllowVertexFallback(false, { isVision: true, envValue: "true" }), false);
  assert.equal(t.resolveAllowVertexFallback(true, { isVision: false, envValue: "false" }), true);
  assert.equal(t.resolveAllowVertexFallback(undefined, { isVision: false, envValue: "true" }), true);
  assert.equal(t.resolveAllowVertexFallback(undefined, { isVision: true, envValue: "false" }), false);
});

test("buildVertexGenerateContentBody sanitizes generationConfig and preserves multimodal inlineData", () => {
  const payload = t.buildVertexGenerateContentBody({
    systemInstruction: { parts: [{ text: "Be concise." }] },
    contents: [
      {
        role: "user",
        parts: [
          { text: "Analyze this meal" },
          { inlineData: { mimeType: "IMAGE/JPEG", data: "YWJj" } },
        ],
      },
    ],
    generationConfig: {
      temperature: 99,
      maxOutputTokens: 99999,
      responseMimeType: "application/json",
      responseSchema: { type: "OBJECT", properties: { name: { type: "STRING" } } },
    },
  });
  assert.equal(payload.systemInstruction.parts[0].text, "Be concise.");
  assert.equal(payload.contents[0].parts[1].inlineData.mimeType, "image/jpeg");
  assert.equal(payload.generationConfig.temperature, 2);
  assert.equal(payload.generationConfig.maxOutputTokens, 16384);
  assert.equal(payload.generationConfig.responseMimeType, "application/json");
  assert.deepEqual(payload.generationConfig.responseSchema, {
    type: "OBJECT",
    properties: { name: { type: "STRING" } },
  });
});

test("callVertexAIText falls back to Google Vertex AI Gemini and normalizes JSON response", async () => {
  const calledUrls = [];
  const meta = { receivedCompletion: false, attemptedPaid: false };
  const result = await t.callVertexAIText({
    geminiBody: {
      contents: [
        {
          role: "user",
          parts: [
            { text: "Analyze plate" },
            { inlineData: { mimeType: "image/jpeg", data: "YWJj" } },
          ],
        },
      ],
      generationConfig: { responseMimeType: "application/json" },
    },
    models: ["gemini-2.5-flash-lite", "gemini-2.5-flash"],
    projectId: "serzhanovich-ecosystem-ce700",
    location: "us-central1",
    getAccessToken: async () => "ya29.test-token",
    fetchImpl: async (url, init) => {
      calledUrls.push(url);
      assert.equal(init.headers.Authorization, "Bearer ya29.test-token");
      return {
        ok: true,
        status: 200,
        text: async () =>
          JSON.stringify({
            candidates: [
              {
                content: {
                  parts: [{ text: '```json\n{"isFood":true,"name":"Salad","calories":240}\n```' }],
                },
              },
            ],
          }),
      };
    },
    attemptMeta: meta,
  });

  assert.equal(
    calledUrls[0],
    "https://us-central1-aiplatform.googleapis.com/v1/projects/serzhanovich-ecosystem-ce700/locations/us-central1/publishers/google/models/gemini-2.5-flash-lite:generateContent"
  );
  assert.equal(result.candidates[0].content.parts[0].text, '{"isFood":true,"name":"Salad","calories":240}');
  assert.deepEqual(meta, { receivedCompletion: true, attemptedPaid: true });
});

test("normalizeFatSecretFood preserves metric mg/mcg micronutrients for v2 payloads without %DV inflation", () => {
  const v2Food = {
    food_name: "Milk v2",
    servings: {
      serving: {
        metric_serving_amount: "240",
        metric_serving_unit: "ml",
        calories: "120",
        protein: "8",
        fat: "5",
        carbohydrate: "12",
        potassium: "363",
        calcium: "300",
        iron: "0.5",
        vitamin_c: "2.4",
        vitamin_d: "3.0",
      },
    },
  };
  const item = t.normalizeFatSecretFood(v2Food, { isV2MetricMicros: true });
  assert.equal(item.calcium, 300);
  assert.equal(item.iron, 0.5);
  assert.equal(item.vitaminC, 2.4);
  assert.equal(item.vitaminD, 3.0);
  assert.equal(item.potassium, 363);
});

test("isFatSecretBarcodeUnavailableError treats plan/scope/not-found codes 10 and 21 as non-fatal", () => {
  assert.equal(t.isFatSecretBarcodeUnavailableError({ error: { code: 10 } }), true);
  assert.equal(t.isFatSecretBarcodeUnavailableError({ error: { code: "21" } }), true);
  assert.equal(t.isFatSecretBarcodeUnavailableError({ error: { code: 101 } }), false);
  assert.equal(t.isFatSecretBarcodeUnavailableError({ food: {} }), false);
});

test("resolveIpQuotaLimit tightens anonymous IP budget relative to signed-in users", () => {
  assert.equal(t.resolveIpQuotaLimit(200, "anonymous", "ai"), 400);
  assert.equal(t.resolveIpQuotaLimit(200, "apple.com", "ai"), 1600);
  assert.equal(t.resolveIpQuotaLimit(1000, "anonymous", "search"), 2000);
  assert.equal(t.resolveIpQuotaLimit(1000, "google.com", "search"), 8000);
});

test("checkBurstRateLimit blocks requests exceeding per-minute cap and resets after window", () => {
  const store = new Map();
  const t0 = 1_000_000;
  for (let i = 0; i < 3; i++) {
    const r = t.checkBurstRateLimit("u1", { limit: 3, windowMs: 60_000, now: t0 + i * 100, store });
    assert.equal(r.allowed, true);
  }
  const blocked = t.checkBurstRateLimit("u1", { limit: 3, windowMs: 60_000, now: t0 + 500, store });
  assert.equal(blocked.allowed, false);
  assert.ok(blocked.retryAfterSeconds >= 1 && blocked.retryAfterSeconds <= 60);

  const afterReset = t.checkBurstRateLimit("u1", { limit: 3, windowMs: 60_000, now: t0 + 61_000, store });
  assert.equal(afterReset.allowed, true);
});
