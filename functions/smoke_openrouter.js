#!/usr/bin/env node
/**
 * Live smoke test for FoodTracker's OpenRouter translation, 10-model fallback,
 * multimodal vision image parsing, and key rotation.
 * Reads keys from OPENROUTER_API_KEY env or gitignored .secret.local / .env.
 */
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");

function loadKey() {
  if (process.env.OPENROUTER_API_KEY) return process.env.OPENROUTER_API_KEY.trim();
  for (const file of [".secret.local", ".env"]) {
    const secretPath = path.join(__dirname, file);
    if (!fs.existsSync(secretPath)) continue;
    const raw = fs.readFileSync(secretPath, "utf8");
    const line = raw.split("\n").find((l) => l.startsWith("OPENROUTER_API_KEY="));
    if (line) return line.slice("OPENROUTER_API_KEY=".length).trim();
  }
  throw new Error("No OPENROUTER_API_KEY found");
}

function loadSampleFoodJpegBase64() {
  const candidates = [
    path.join(__dirname, "../Screenshots/food_bg_warm.png"),
    path.join(__dirname, "../Screenshots/food_bg_green.png"),
    path.join(__dirname, "../FoodTracker/Assets.xcassets/AppIcon.appiconset/AppIcon1024x1024.png"),
  ];
  const srcPng = candidates.find((p) => fs.existsSync(p));
  if (!srcPng) {
    throw new Error("No sample image asset found for smoke test");
  }
  const tmpJpg = path.join(os.tmpdir(), `foodtracker-smoke-${process.pid}.jpg`);
  try {
    execFileSync("sips", ["-Z", "256", "-s", "format", "jpeg", srcPng, "--out", tmpJpg], {
      stdio: "ignore",
    });
    return fs.readFileSync(tmpJpg).toString("base64");
  } finally {
    if (fs.existsSync(tmpJpg)) fs.unlinkSync(tmpJpg);
  }
}

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || "serzhanovich-ecosystem-ce700";
const mod = require("./index.js");
const {
  TEXT_MODEL_CHAIN,
  VISION_MODEL_CHAIN,
  parseApiKeys,
  callOpenRouterText,
} = mod._test;

const SAMPLE_JPEG_BASE64 = loadSampleFoodJpegBase64();

async function callJSON(apiKeys, prompt, extraParts = [], overrides = {}) {
  const parts = [{ text: prompt }, ...extraParts];
  const geminiBody = {
    contents: [{ role: "user", parts }],
    generationConfig: {
      temperature: extraParts.length > 0 ? 0.4 : 0.7,
      responseMimeType: "application/json",
    },
  };
  const gemini = await callOpenRouterText({ apiKeys, geminiBody, overrides });
  const text = gemini.candidates[0].content.parts[0].text;
  return { text, parsed: JSON.parse(text) };
}

async function main() {
  const apiKeys = parseApiKeys(loadKey());
  console.log("Keys loaded:", apiKeys.length);

  // 1. Verify each API key individually works
  for (let idx = 0; idx < apiKeys.length; idx++) {
    const res = await callOpenRouterText({
      apiKeys: [apiKeys[idx]],
      geminiBody: {
        contents: [{ role: "user", parts: [{ text: "Say OK in 2 words." }] }],
        generationConfig: { temperature: 0.2 },
      },
    });
    const out = res.candidates[0].content.parts[0].text.trim();
    console.log(`Key #${idx + 1} OK:`, out.slice(0, 60));
  }

  // 2. Plain chat (AINutritionService.sendChatMessage shape)
  console.log("\n--- 1. Plain chat ---");
  const chat = await callOpenRouterText({
    apiKeys,
    geminiBody: {
      contents: [
        {
          role: "user",
          parts: [
            {
              text: "You are a nutritionist. User ate 1400/2000 kcal today on a balanced diet and asks: Can I eat Greek yogurt? Keep it under 2 sentences.",
            },
          ],
        },
      ],
      generationConfig: { temperature: 0.7 },
    },
  });
  console.log("OK chat:", chat.candidates[0].content.parts[0].text.slice(0, 160));

  // 3. Daily verdict JSON (AINutritionService.generateDailyVerdict shape)
  console.log("\n--- 2. Daily verdict JSON ---");
  const verdict = await callJSON(
    apiKeys,
    `Analyze daily intake: 1650 kcal out of 2000 kcal goal, 120g protein out of 140g target.
Return ONLY a raw JSON object: {"title":"String","message":"String","mood":"perfect|warning|danger"}`
  );
  if (!verdict.parsed.title || !verdict.parsed.message || !verdict.parsed.mood) {
    throw new Error(`Invalid verdict JSON: ${verdict.text}`);
  }
  console.log("OK verdict:", verdict.parsed);

  // 4. Fridge recipe JSON (AINutritionService.generateFridgeRecipe shape)
  console.log("\n--- 3. Fridge recipe JSON ---");
  const recipe = await callJSON(
    apiKeys,
    `Invent a recipe using chicken breast, broccoli, olive oil (~450 kcal, ~40g protein).
Return ONLY a raw JSON object: {"name":"String","info":"String","calories":450,"protein":40.0,"fats":14.0,"carbs":20.0,"cookingTime":20}`
  );
  if (!recipe.parsed.name || typeof recipe.parsed.calories !== "number") {
    throw new Error(`Invalid recipe JSON: ${recipe.text}`);
  }
  console.log("OK recipe:", recipe.parsed.name, recipe.parsed.calories, "kcal");

  // 5. Multimodal vision food image JSON (VertexAIManager.analyzeFoodImage shape)
  console.log("\n--- 4. Multimodal Vision JSON (real food photo) ---");
  const vision = await callJSON(
    apiKeys,
    `You are an elite AI nutritionist. Analyze the image.
If it contains food, set "isFood" to true, estimate portion weight in grams, calories, protein, fats, carbs.
Respond ONLY with raw JSON: {"isFood": true, "errorMessage": null, "name": "Dish", "weight": 250.0, "calories": 400, "protein": 30.0, "fats": 20.0, "carbs": 15.0}`,
    [{ inlineData: { mimeType: "image/jpeg", data: SAMPLE_JPEG_BASE64 } }]
  );
  if (typeof vision.parsed.isFood !== "boolean") {
    throw new Error(`Invalid vision JSON: ${vision.text}`);
  }
  console.log("OK vision:", vision.parsed);

  // 6. Probe individual models in TEXT_MODEL_CHAIN and VISION_MODEL_CHAIN
  console.log("\n--- 5. Probing individual models ---");
  let workingText = 0;
  for (const model of TEXT_MODEL_CHAIN) {
    try {
      const r = await callJSON(
        apiKeys,
        'Return ONLY JSON {"ok": true}',
        [],
        { textModels: [model] }
      );
      console.log(`  TEXT PASS  ${model} -> ${JSON.stringify(r.parsed)}`);
      workingText++;
    } catch (e) {
      console.log(`  TEXT FAIL  ${model} -> ${String(e.message || e).slice(0, 140)}`);
    }
  }

  let workingVision = 0;
  for (const model of VISION_MODEL_CHAIN) {
    try {
      const r = await callJSON(
        apiKeys,
        'Describe what is in this image briefly as JSON: {"isFood": false, "note": "short"}',
        [{ inlineData: { mimeType: "image/jpeg", data: SAMPLE_JPEG_BASE64 } }],
        { visionModels: [model] }
      );
      console.log(`  VISION PASS ${model} -> ${JSON.stringify(r.parsed)}`);
      workingVision++;
    } catch (e) {
      console.log(`  VISION FAIL ${model} -> ${String(e.message || e).slice(0, 140)}`);
    }
  }

  console.log(`\nSummary: ${workingText}/${TEXT_MODEL_CHAIN.length} text models passed, ${workingVision}/${VISION_MODEL_CHAIN.length} vision models passed.`);
  if (workingText < 3 || workingVision < 1) {
    throw new Error("Too few working free models in chain!");
  }
  console.log("All smoke checks passed.");
}

main().catch((e) => {
  console.error("SMOKE FAILED:", e);
  process.exit(1);
});
