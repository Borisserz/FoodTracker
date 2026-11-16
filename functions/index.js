const crypto = require("node:crypto");
const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAppCheck } = require("firebase-admin/app-check");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { defineSecret } = require("firebase-functions/params");

const AI_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_AI_WEEKLY_LIMIT = 200;
const UPSTREAM_TIMEOUT_MS = 22000;

initializeApp();

// Stored in Secret Manager (comma-separate for key rotation).
const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");
const fatSecretClientId = defineSecret("FATSECRET_CLIENT_ID");
const fatSecretClientSecret = defineSecret("FATSECRET_CLIENT_SECRET");

const PROJECT_HINT = "serzhanovich-ecosystem-ce700";
const SERVICE_ACCOUNT =
  "firebase-adminsdk-fbsvc@serzhanovich-ecosystem-ce700.iam.gserviceaccount.com";
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const FATSECRET_TOKEN_URL = "https://oauth.fatsecret.com/connect/token";
const FATSECRET_API_BASE = "https://platform.fatsecret.com/rest";
const FATSECRET_OAUTH1_URL = "https://platform.fatsecret.com/rest/server.api";
const FATSECRET_TIMEOUT_MS = 10000;

let fatSecretTokenCache = null;

// 10-model text fallback chain ordered by live reliability and structured JSON support.
const TEXT_MODEL_CHAIN = [
  "particle-ai/particle-1:free",
  "nvidia/nemotron-3.5-super-vl:free",
  "baidu/ernie-5.5-flash-preview:free",
  "liquid/lfm-3-1.7b:free",
  "dots-studio/dots-3-note-preview:free",
  "inclusionai/ling-3.2-flash:free",
  "recursive/flint-v1.0:free",
  "google/gemma-4-31b-it:free",
  "google/gemma-4-26b-a4b-it:free",
  "openrouter/free",
];

// Multimodal fallback chain for food/menu photos (image-capable models only).
const VISION_MODEL_CHAIN = [
  "nvidia/nemotron-3.5-super-vl:free",
  "particle-ai/particle-1:free",
  "inclusionai/ling-3.2-flash:free",
  "dots-studio/dots-3-note-preview:free",
  "google/gemma-4-31b-it:free",
  "google/gemma-4-26b-a4b-it:free",
  "nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free",
  "thinkingmachines/inkling-2-small:free",
  "openrouter/free",
];

const STRUCTURED_MODELS = new Set([
  "inclusionai/ling-3.2-flash:free",
  "baidu/ernie-5.5-flash-preview:free",
  "liquid/lfm-3-1.7b:free",
  "particle-ai/particle-1:free",
  "dots-studio/dots-3-note-preview:free",
  "nvidia/nemotron-3.5-super-vl:free",
  "openrouter/free",
]);

const JSON_OBJECT_MODELS = new Set([
  ...STRUCTURED_MODELS,
  "google/gemma-4-31b-it:free",
  "google/gemma-4-26b-a4b-it:free",
  "recursive/flint-v1.0:free",
]);

class RateLimitError extends Error {
  constructor(retryAfterSeconds, limit) {
    super("rate_limited");
    this.retryAfterSeconds = retryAfterSeconds;
    this.limit = limit;
  }
}

function parseApiKeys(raw) {
  const seen = new Set();
  const keys = [];
  for (const part of String(raw || "").split(",")) {
    const trimmed = part.trim();
    if (trimmed && !seen.has(trimmed)) {
      seen.add(trimmed);
      keys.push(trimmed);
    }
  }
  return keys;
}

function hasImageContent(body) {
  if (!Array.isArray(body?.contents)) return false;
  return body.contents.some(
    (c) =>
      Array.isArray(c?.parts) &&
      c.parts.some((p) => p?.inlineData && p.inlineData.data)
  );
}

function modelChainForRequest(body, overrides = {}) {
  if (hasImageContent(body)) {
    if (Array.isArray(overrides.visionModels) && overrides.visionModels.length > 0) {
      return overrides.visionModels;
    }
    return VISION_MODEL_CHAIN;
  }
  if (Array.isArray(overrides.textModels) && overrides.textModels.length > 0) {
    return overrides.textModels;
  }
  return TEXT_MODEL_CHAIN;
}

function geminiTypeToJson(type) {
  if (!type) return "string";
  switch (String(type).toUpperCase()) {
    case "OBJECT":
      return "object";
    case "ARRAY":
      return "array";
    case "INTEGER":
      return "integer";
    case "NUMBER":
      return "number";
    case "BOOLEAN":
      return "boolean";
    case "STRING":
    default:
      return "string";
  }
}

function convertGeminiSchema(schema) {
  if (!schema || typeof schema !== "object") return undefined;
  const out = { type: geminiTypeToJson(schema.type) };
  if (schema.description) out.description = schema.description;
  if (schema.properties && typeof schema.properties === "object") {
    out.properties = {};
    for (const [key, value] of Object.entries(schema.properties)) {
      out.properties[key] = convertGeminiSchema(value);
    }
  }
  if (schema.items) out.items = convertGeminiSchema(schema.items);
  if (Array.isArray(schema.required)) out.required = schema.required;
  return out;
}

function geminiBodyToOpenAI(body, { streaming, model }) {
  const messages = [];
  const systemParts = body?.systemInstruction?.parts;
  if (Array.isArray(systemParts)) {
    const systemText = systemParts
      .map((p) => (typeof p?.text === "string" ? p.text : ""))
      .filter(Boolean)
      .join("\n");
    if (systemText) messages.push({ role: "system", content: systemText });
  }

  if (Array.isArray(body?.contents)) {
    for (const content of body.contents) {
      const role =
        content.role === "model" ? "assistant" : content.role || "user";
      const parts = Array.isArray(content.parts) ? content.parts : [];
      const hasInline = parts.some((p) => p?.inlineData && p.inlineData.data);

      if (!hasInline) {
        const text = parts
          .map((p) => (typeof p?.text === "string" ? p.text : ""))
          .filter(Boolean)
          .join("\n");
        if (text) messages.push({ role, content: text });
        continue;
      }

      const contentParts = [];
      for (const p of parts) {
        if (typeof p?.text === "string" && p.text.length > 0) {
          contentParts.push({ type: "text", text: p.text });
        } else if (p?.inlineData?.data) {
          const mime = p.inlineData.mimeType || "image/jpeg";
          contentParts.push({
            type: "image_url",
            image_url: { url: `data:${mime};base64,${p.inlineData.data}` },
          });
        }
      }
      if (contentParts.length > 0) {
        messages.push({ role, content: contentParts });
      }
    }
  }

  const gen = body?.generationConfig || {};
  const temperature =
    typeof gen.temperature === "number" ? gen.temperature : 0.4;
  const wantsJson =
    gen.responseMimeType === "application/json" || Boolean(gen.responseSchema);

  const openAIBody = {
    model,
    messages,
    temperature,
    stream: Boolean(streaming),
  };

  if (wantsJson) {
    openAIBody.plugins = [{ id: "response-healing" }];
    if (gen.responseSchema && STRUCTURED_MODELS.has(model)) {
      const jsonSchema = convertGeminiSchema(gen.responseSchema);
      if (jsonSchema) {
        openAIBody.response_format = {
          type: "json_schema",
          json_schema: {
            name: "food_tracker_response",
            strict: false,
            schema: jsonSchema,
          },
        };
      }
    } else if (JSON_OBJECT_MODELS.has(model)) {
      openAIBody.response_format = { type: "json_object" };
    }
  }

  return openAIBody;
}

function extractBalancedJSON(text) {
  for (let start = 0; start < text.length; start++) {
    const opener = text[start];
    if (opener !== "{" && opener !== "[") continue;
    const closer = opener === "{" ? "}" : "]";
    let depth = 0;
    let inString = false;
    let escaped = false;

    for (let i = start; i < text.length; i++) {
      const ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch === "\\") {
          escaped = true;
        } else if (ch === '"') {
          inString = false;
        }
        continue;
      }
      if (ch === '"') {
        inString = true;
      } else if (ch === opener) {
        depth++;
      } else if (ch === closer) {
        depth--;
        if (depth === 0) {
          const candidate = text.slice(start, i + 1);
          try {
            JSON.parse(candidate);
            return candidate;
          } catch {
            break;
          }
        }
      }
    }
  }
  return null;
}

function stripModelJSON(raw) {
  let text = String(raw || "").trim();
  const fenceMatch = text.match(/```(?:json|JSON)?\s*([\s\S]*?)```/);
  if (fenceMatch && fenceMatch[1]) {
    const inner = fenceMatch[1].trim();
    try {
      JSON.parse(inner);
      return inner;
    } catch {
      const balanced = extractBalancedJSON(inner);
      if (balanced) return balanced;
    }
  }
  try {
    JSON.parse(text);
    return text;
  } catch {
    // Fall back to balanced scan across the full response.
  }
  return extractBalancedJSON(text) || text;
}

function extractMessageText(content) {
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => (typeof part?.text === "string" ? part.text : ""))
      .filter(Boolean)
      .join("\n");
  }
  return "";
}

function openAIToGeminiResponse(data, { expectJSON = false } = {}) {
  const rawContent =
    data?.choices?.[0]?.message?.content ?? data?.choices?.[0]?.text ?? "";
  let text = extractMessageText(rawContent);
  if (expectJSON && text) {
    text = stripModelJSON(text);
  }
  return {
    candidates: [
      {
        content: {
          parts: [{ text }],
        },
      },
    ],
  };
}

function openAIStreamChunkToGemini(line) {
  if (!line.startsWith("data:")) return null;
  const payload = line.slice(5).trim();
  if (!payload) return null;
  if (payload === "[DONE]") return "[DONE]";
  try {
    const parsed = JSON.parse(payload);
    const delta = extractMessageText(
      parsed?.choices?.[0]?.delta?.content ??
        parsed?.choices?.[0]?.message?.content ??
        ""
    );
    if (!delta) return null;
    return JSON.stringify({
      candidates: [{ content: { parts: [{ text: delta }] } }],
    });
  } catch {
    return null;
  }
}

async function loadAISettings() {
  try {
    const db = getFirestore();
    const snap = await db.collection("config").doc("food_ai_settings").get();
    const data = snap.exists ? snap.data() || {} : {};
    return {
      weeklyLimit:
        typeof data.weeklyLimit === "number"
          ? data.weeklyLimit
          : DEFAULT_AI_WEEKLY_LIMIT,
      textModels: Array.isArray(data.textModels) ? data.textModels : null,
      visionModels: Array.isArray(data.visionModels) ? data.visionModels : null,
    };
  } catch (e) {
    console.warn("Could not load config/food_ai_settings, using defaults:", e);
    return {
      weeklyLimit: DEFAULT_AI_WEEKLY_LIMIT,
      textModels: null,
      visionModels: null,
    };
  }
}

async function enforceRateLimit(uid, weeklyLimit) {
  const db = getFirestore();
  const ref = db.collection("food_ai_usage").doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    let windowStart = now;
    let count = 0;

    if (snap.exists) {
      const data = snap.data() || {};
      const ws = typeof data.windowStart === "number" ? data.windowStart : 0;
      if (now - ws < AI_WINDOW_MS) {
        windowStart = ws;
        count = data.count || 0;
      }
    }

    if (count >= weeklyLimit) {
      const retryAfterSeconds = Math.ceil(
        (windowStart + AI_WINDOW_MS - now) / 1000
      );
      throw new RateLimitError(retryAfterSeconds, weeklyLimit);
    }
  });
}

async function recordSuccessfulAIUse(uid) {
  const db = getFirestore();
  const ref = db.collection("food_ai_usage").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const now = Date.now();
    let windowStart = now;
    let count = 0;
    if (snap.exists) {
      const data = snap.data() || {};
      const ws = typeof data.windowStart === "number" ? data.windowStart : 0;
      if (now - ws < AI_WINDOW_MS) {
        windowStart = ws;
        count = data.count || 0;
      }
    }
    tx.set(
      ref,
      {
        windowStart,
        count: count + 1,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

function openRouterHeaders(apiKey) {
  return {
    Authorization: `Bearer ${apiKey}`,
    "Content-Type": "application/json",
    "HTTP-Referer": `https://${PROJECT_HINT}.web.app`,
    "X-OpenRouter-Title": "FoodTracker",
  };
}

function shouldTryNextKeyForError(status, errText) {
  if (status === 401 || status === 402) return true;
  if (status === 429) {
    return !String(errText || "").includes("upstream_provider_shared_pool");
  }
  return false;
}

function rotatedKeys(apiKeys) {
  if (apiKeys.length <= 1) return apiKeys;
  const offset = Math.floor(Math.random() * apiKeys.length);
  return [...apiKeys.slice(offset), ...apiKeys.slice(0, offset)];
}

async function callOpenRouterText({ apiKeys, geminiBody, overrides = {} }) {
  const chain = modelChainForRequest(geminiBody, overrides);
  const expectJSON =
    geminiBody?.generationConfig?.responseMimeType === "application/json" ||
    Boolean(geminiBody?.generationConfig?.responseSchema);
  const keys = rotatedKeys(apiKeys);

  let lastError = null;
  for (const model of chain) {
    const attempt = geminiBodyToOpenAI(geminiBody, {
      streaming: false,
      model,
    });

    for (const apiKey of keys) {
      try {
        const resp = await fetch(OPENROUTER_URL, {
          method: "POST",
          headers: openRouterHeaders(apiKey),
          body: JSON.stringify(attempt),
          signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
        });
        const text = await resp.text();
        if (!resp.ok) {
          lastError = new Error(
            `OpenRouter ${resp.status} ${model}: ${text.slice(0, 400)}`
          );
          console.warn(lastError.message);
          if (!shouldTryNextKeyForError(resp.status, text)) break;
          continue;
        }
        let data;
        try {
          data = JSON.parse(text);
        } catch (e) {
          lastError = new Error(`Non-JSON envelope from ${model}: ${e.message}`);
          break;
        }

        const gemini = openAIToGeminiResponse(data, { expectJSON });
        const outText = gemini.candidates?.[0]?.content?.parts?.[0]?.text || "";
        if (!outText) {
          lastError = new Error(`Empty completion from ${model}`);
          console.warn(lastError.message);
          break;
        }
        if (expectJSON) {
          try {
            JSON.parse(outText);
          } catch (e) {
            lastError = new Error(
              `Invalid JSON output from ${model}: ${e.message}`
            );
            console.warn(lastError.message);
            break;
          }
        }
        return gemini;
      } catch (e) {
        lastError = e;
        console.warn(`OpenRouter error on ${model}:`, e?.message || e);
        break;
      }
    }
  }
  throw lastError || new Error("All OpenRouter models/keys failed");
}

async function verifyAppCheck(req, res) {
  const appCheckToken = req.header("X-Firebase-AppCheck");
  if (!appCheckToken) {
    res.status(401).json({ error: "Missing App Check token" });
    return false;
  }
  try {
    await getAppCheck().verifyToken(appCheckToken);
    return true;
  } catch (e) {
    res.status(401).json({ error: "Invalid App Check token" });
    return false;
  }
}

async function verifyFirebaseUser(req, res) {
  const authHeader = req.header("Authorization") || "";
  const m = authHeader.match(/^Bearer (.+)$/i);
  if (!m) {
    res.status(401).json({ error: "Missing Firebase ID token" });
    return null;
  }
  try {
    const decoded = await getAuth().verifyIdToken(m[1]);
    return decoded.uid;
  } catch (e) {
    res.status(401).json({ error: "Invalid Firebase ID token" });
    return null;
  }
}

function parseNumericValue(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const cleaned = value.trim().replace(",", ".");
    if (!cleaned) return 0;
    const parsed = Number(cleaned);
    return Number.isFinite(parsed) ? parsed : 0;
  }
  return 0;
}

function isTokenValid(cacheEntry, nowMs = Date.now()) {
  return Boolean(
    cacheEntry &&
      typeof cacheEntry.token === "string" &&
      cacheEntry.token.length > 0 &&
      typeof cacheEntry.expiresAtMs === "number" &&
      cacheEntry.expiresAtMs - nowMs > 60_000
  );
}

function oauthPercentEncode(str) {
  return encodeURIComponent(String(str)).replace(
    /[!'()*]/g,
    (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`
  );
}

function buildOAuth1FatSecretURL({
  consumerKey,
  consumerSecret,
  method,
  extraParams = {},
}) {
  const params = {
    oauth_consumer_key: consumerKey,
    oauth_nonce: crypto.randomBytes(8).toString("hex"),
    oauth_signature_method: "HMAC-SHA1",
    oauth_timestamp: String(Math.floor(Date.now() / 1000)),
    oauth_version: "1.0",
    format: "json",
    method,
    ...extraParams,
  };
  const sortedQuery = Object.keys(params)
    .sort()
    .map((k) => `${oauthPercentEncode(k)}=${oauthPercentEncode(params[k])}`)
    .join("&");
  const baseString = `GET&${oauthPercentEncode(
    FATSECRET_OAUTH1_URL
  )}&${oauthPercentEncode(sortedQuery)}`;
  const signingKey = `${oauthPercentEncode(consumerSecret)}&`;
  const signature = crypto
    .createHmac("sha1", signingKey)
    .update(baseString)
    .digest("base64");
  return `${FATSECRET_OAUTH1_URL}?${sortedQuery}&oauth_signature=${oauthPercentEncode(
    signature
  )}`;
}

function parseFatSecretDescription(description) {
  if (typeof description !== "string" || !description) return null;
  const calMatch = description.match(/Calories:\s*([0-9.,]+)\s*kcal/i);
  const fatMatch = description.match(/Fat:\s*([0-9.,]+)\s*g/i);
  const carbMatch = description.match(/Carbs:\s*([0-9.,]+)\s*g/i);
  const protMatch = description.match(/Protein:\s*([0-9.,]+)\s*g/i);
  if (!calMatch && !fatMatch && !carbMatch && !protMatch) return null;

  const weightMatch = description.match(/^Per\s+([0-9.,]+)\s*(g|ml)\b/i);
  const parsedWeight = weightMatch ? parseNumericValue(weightMatch[1]) : 0;

  return {
    weight: parsedWeight > 0 ? parsedWeight : 100,
    calories: Math.round(parseNumericValue(calMatch?.[1] || 0)),
    fats: parseNumericValue(fatMatch?.[1] || 0),
    carbs: parseNumericValue(carbMatch?.[1] || 0),
    protein: parseNumericValue(protMatch?.[1] || 0),
  };
}

function normalizeFatSecretFood(food) {
  const baseName =
    typeof food?.food_name === "string" ? food.food_name.trim() : "";
  if (!baseName) return null;

  const brand =
    typeof food?.brand_name === "string" ? food.brand_name.trim() : "";
  const name =
    brand && !baseName.toLowerCase().includes(brand.toLowerCase())
      ? `${baseName} (${brand})`
      : baseName;

  const servingData = food?.servings?.serving;
  const serving = Array.isArray(servingData) ? servingData[0] : servingData;
  if (serving && typeof serving === "object") {
    const weightRaw = parseNumericValue(serving.metric_serving_amount);
    return {
      name,
      weight: weightRaw > 0 ? weightRaw : 100,
      calories: Math.round(parseNumericValue(serving.calories)),
      protein: parseNumericValue(serving.protein),
      fats: parseNumericValue(serving.fat),
      carbs: parseNumericValue(serving.carbohydrate),
    };
  }

  const fromDesc = parseFatSecretDescription(food?.food_description);
  if (fromDesc) {
    return { name, ...fromDesc };
  }
  return null;
}

function normalizeFatSecretSearch(json) {
  const foodData = json?.foods_search?.results?.food ?? json?.foods?.food;
  if (!foodData) return [];
  const list = Array.isArray(foodData) ? foodData : [foodData];
  return list.map(normalizeFatSecretFood).filter(Boolean);
}

function normalizeFatSecretBarcode(json) {
  if (!json?.food) return null;
  return normalizeFatSecretFood(json.food);
}

function parseSearchPayload(body) {
  const mode = body?.mode;
  if (mode === "search") {
    const query = typeof body?.query === "string" ? body.query.trim() : "";
    if (!query || query.length > 120) {
      throw new Error("Missing search query");
    }
    const rawMax = Number(body?.maxResults);
    const maxResults = Number.isFinite(rawMax)
      ? Math.max(1, Math.min(25, Math.floor(rawMax)))
      : 15;
    return { mode: "search", query, maxResults };
  }
  if (mode === "barcode") {
    const barcode =
      typeof body?.barcode === "string" ? body.barcode.trim() : "";
    if (!/^[A-Za-z0-9_-]{3,32}$/.test(barcode)) {
      throw new Error("Invalid barcode");
    }
    return { mode: "barcode", barcode };
  }
  throw new Error("Invalid mode");
}

async function getFatSecretAccessToken({
  clientId,
  clientSecret,
  forceRefresh = false,
}) {
  if (!forceRefresh && isTokenValid(fatSecretTokenCache)) {
    return fatSecretTokenCache.token;
  }
  if (!clientId || !clientSecret) {
    throw new Error("FatSecret credentials not configured");
  }

  const basic = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
  const resp = await fetch(FATSECRET_TOKEN_URL, {
    method: "POST",
    headers: {
      Authorization: `Basic ${basic}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials&scope=basic",
    signal: AbortSignal.timeout(FATSECRET_TIMEOUT_MS),
  });
  const text = await resp.text();
  if (!resp.ok) {
    fatSecretTokenCache = null;
    throw new Error(`FatSecret token error ${resp.status}: ${text.slice(0, 200)}`);
  }
  const data = JSON.parse(text);
  if (!data?.access_token) {
    fatSecretTokenCache = null;
    throw new Error("FatSecret token missing access_token");
  }
  const expiresSec =
    typeof data.expires_in === "number" && data.expires_in > 120
      ? data.expires_in
      : 3600;
  fatSecretTokenCache = {
    token: data.access_token,
    expiresAtMs: Date.now() + expiresSec * 1000,
  };
  return fatSecretTokenCache.token;
}

async function fetchFatSecretWithRetry({ url, clientId, clientSecret }) {
  for (let attempt = 0; attempt < 2; attempt++) {
    const token = await getFatSecretAccessToken({
      clientId,
      clientSecret,
      forceRefresh: attempt > 0,
    });
    const resp = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(FATSECRET_TIMEOUT_MS),
    });
    if (resp.status === 401 && attempt === 0) {
      fatSecretTokenCache = null;
      continue;
    }
    const text = await resp.text();
    if (!resp.ok) {
      throw new Error(`FatSecret API ${resp.status}: ${text.slice(0, 200)}`);
    }
    return JSON.parse(text);
  }
  throw new Error("FatSecret API unauthorized after refresh");
}

exports.foodAiProxy = onRequest(
  {
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    memory: "512MiB",
    timeoutSeconds: 300,
    secrets: [openRouterApiKey],
  },
  async (req, res) => {
    if (!(await verifyAppCheck(req, res))) return;
    const uid = await verifyFirebaseUser(req, res);
    if (!uid) return;

    const settings = await loadAISettings();

    try {
      await enforceRateLimit(uid, settings.weeklyLimit);
    } catch (e) {
      if (e instanceof RateLimitError) {
        res.set("Retry-After", String(e.retryAfterSeconds));
        res.status(429).json({
          error: "weekly_limit_reached",
          message: `You've reached your weekly limit of ${e.limit} AI requests.`,
          retryAfter: e.retryAfterSeconds,
        });
        return;
      }
      console.error("Rate limit check failed:", e);
      res.status(500).json({ error: "Rate limit check failed" });
      return;
    }

    const apiKeys = parseApiKeys(openRouterApiKey.value());
    if (apiKeys.length === 0) {
      res.status(500).json({ error: "OPENROUTER_API_KEY not configured" });
      return;
    }

    const body = req.body || {};
    const streaming = req.query.stream === "true";

    try {
      if (!streaming) {
        const gemini = await callOpenRouterText({
          apiKeys,
          geminiBody: body,
          overrides: settings,
        });
        await recordSuccessfulAIUse(uid);
        res.status(200).json(gemini);
        return;
      }

      const chain = modelChainForRequest(body, settings);
      const keys = rotatedKeys(apiKeys);
      let upstream = null;
      let lastError = null;
      for (const model of chain) {
        const attempt = geminiBodyToOpenAI(body, { streaming: true, model });
        for (const apiKey of keys) {
          try {
            const resp = await fetch(OPENROUTER_URL, {
              method: "POST",
              headers: openRouterHeaders(apiKey),
              body: JSON.stringify(attempt),
              signal: AbortSignal.timeout(UPSTREAM_TIMEOUT_MS),
            });
            if (!resp.ok || !resp.body) {
              const errText = await resp.text();
              lastError = new Error(
                `stream ${resp.status} ${model}: ${errText.slice(0, 300)}`
              );
              console.warn(lastError.message);
              if (!shouldTryNextKeyForError(resp.status, errText)) break;
              continue;
            }
            upstream = resp;
            break;
          } catch (e) {
            lastError = e;
            console.warn(`Stream attempt failed on ${model}:`, e?.message || e);
            break;
          }
        }
        if (upstream) break;
      }

      if (!upstream) {
        throw lastError || new Error("All streaming models failed");
      }

      res.status(200).set("Content-Type", "text/event-stream");
      const reader = upstream.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      let yielded = false;

      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split("\n");
        buffer = lines.pop() || "";
        for (const rawLine of lines) {
          const line = rawLine.trimEnd();
          if (!line) continue;
          const converted = openAIStreamChunkToGemini(line);
          if (converted === "[DONE]") {
            res.write("data: [DONE]\n\n");
            continue;
          }
          if (converted) {
            yielded = true;
            res.write(`data: ${converted}\n\n`);
          }
        }
      }
      if (yielded) {
        await recordSuccessfulAIUse(uid);
      }
      res.end();
    } catch (e) {
      console.error("foodAiProxy OpenRouter error:", e);
      if (!res.headersSent) {
        res.status(502).json({
          error: "upstream_failed",
          message: String(e?.message || e).slice(0, 500),
        });
      } else {
        res.end();
      }
    }
  }
);

async function callFatSecretOAuth1({ consumerKey, consumerSecret, method, extraParams }) {
  const url = buildOAuth1FatSecretURL({
    consumerKey,
    consumerSecret,
    method,
    extraParams,
  });
  const resp = await fetch(url, {
    signal: AbortSignal.timeout(FATSECRET_TIMEOUT_MS),
  });
  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(`FatSecret OAuth1 ${resp.status}: ${text.slice(0, 200)}`);
  }
  return JSON.parse(text);
}

exports.foodSearchProxy = onRequest(
  {
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    memory: "256MiB",
    timeoutSeconds: 30,
    secrets: [fatSecretClientId, fatSecretClientSecret],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }
    if (!(await verifyAppCheck(req, res))) return;

    let parsed;
    try {
      parsed = parseSearchPayload(req.body);
    } catch (e) {
      res.status(400).json({ error: e.message });
      return;
    }

    const clientId = fatSecretClientId.value().trim();
    const clientSecret = fatSecretClientSecret.value().trim();
    if (!clientId || !clientSecret) {
      res.status(500).json({ error: "FatSecret credentials not configured" });
      return;
    }

    try {
      if (parsed.mode === "search") {
        // Try OAuth 1.0 Consumer Key/Secret first (stateless, works with Basic FatSecret keys).
        const oauth1Data = await callFatSecretOAuth1({
          consumerKey: clientId,
          consumerSecret: clientSecret,
          method: "foods.search",
          extraParams: {
            search_expression: parsed.query,
            max_results: String(parsed.maxResults),
          },
        });
        if (!oauth1Data?.error) {
          res.status(200).json({ items: normalizeFatSecretSearch(oauth1Data) });
          return;
        }
        // Only fall back to OAuth 2.0 if keys are rejected as OAuth 1.0 consumer credentials.
        const errCode = Number(oauth1Data.error?.code);
        if (errCode !== 2 && errCode !== 8) {
          throw new Error(`FatSecret error ${errCode}: ${oauth1Data.error?.message}`);
        }
        const url =
          `${FATSECRET_API_BASE}/foods/search/v1?search_expression=${encodeURIComponent(
            parsed.query
          )}&format=json&max_results=${parsed.maxResults}`;
        const data = await fetchFatSecretWithRetry({ url, clientId, clientSecret });
        res.status(200).json({ items: normalizeFatSecretSearch(data) });
        return;
      }

      const oauth1Barcode = await callFatSecretOAuth1({
        consumerKey: clientId,
        consumerSecret: clientSecret,
        method: "food.find_id_for_barcode",
        extraParams: { barcode: parsed.barcode },
      });
      if (!oauth1Barcode?.error) {
        const foodId = oauth1Barcode?.food_id?.value;
        if (!foodId) {
          res.status(200).json({ item: null });
          return;
        }
        const detail = await callFatSecretOAuth1({
          consumerKey: clientId,
          consumerSecret: clientSecret,
          method: "food.get",
          extraParams: { food_id: String(foodId) },
        });
        res.status(200).json({ item: normalizeFatSecretBarcode(detail) });
        return;
      }
      const bCode = Number(oauth1Barcode.error?.code);
      if (bCode === 10) {
        // Basic OAuth 1.0 plan has no barcode method; return null cleanly so OFF/AI proceed.
        res.status(200).json({ item: null });
        return;
      }
      if (bCode !== 2 && bCode !== 8) {
        throw new Error(`FatSecret barcode error ${bCode}: ${oauth1Barcode.error?.message}`);
      }

      const url =
        `${FATSECRET_API_BASE}/food/barcode/find-by-id/v2?barcode=${encodeURIComponent(
          parsed.barcode
        )}&format=json`;
      const data = await fetchFatSecretWithRetry({ url, clientId, clientSecret });
      res.status(200).json({ item: normalizeFatSecretBarcode(data) });
    } catch (e) {
      console.error("foodSearchProxy error:", e?.message || e);
      res.status(502).json({
        error: "fatsecret_upstream_failed",
        message: String(e?.message || e).slice(0, 300),
      });
    }
  }
);

exports.foodDeleteAccount = onRequest(
  {
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }
    if (!(await verifyAppCheck(req, res))) return;
    const uid = await verifyFirebaseUser(req, res);
    if (!uid) return;

    try {
      const db = getFirestore();
      // Delete only FoodTracker-scoped per-user server docs (never touch shared `users/{uid}`).
      await db.collection("food_ai_usage").doc(uid).delete();
      res.status(200).json({ ok: true });
    } catch (e) {
      console.error("foodDeleteAccount error:", e?.message || e);
      res.status(500).json({ error: "Failed to delete server data" });
    }
  }
);

module.exports._test = {
  TEXT_MODEL_CHAIN,
  VISION_MODEL_CHAIN,
  STRUCTURED_MODELS,
  JSON_OBJECT_MODELS,
  parseApiKeys,
  shouldTryNextKeyForError,
  hasImageContent,
  modelChainForRequest,
  geminiBodyToOpenAI,
  stripModelJSON,
  openAIToGeminiResponse,
  openAIStreamChunkToGemini,
  callOpenRouterText,
  parseNumericValue,
  isTokenValid,
  buildOAuth1FatSecretURL,
  parseFatSecretDescription,
  normalizeFatSecretFood,
  normalizeFatSecretSearch,
  normalizeFatSecretBarcode,
  parseSearchPayload,
};
