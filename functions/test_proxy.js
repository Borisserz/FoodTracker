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
