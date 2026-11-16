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

test("normalizeFatSecretFood handles array/object servings and defaults weight to 100", () => {
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
    weight: 100,
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
