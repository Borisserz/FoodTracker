const crypto = require("node:crypto");
const { onRequest } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAppCheck } = require("firebase-admin/app-check");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const { defineSecret } = require("firebase-functions/params");

const AI_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;
const DEFAULT_AI_WEEKLY_LIMIT = 200;
const DEFAULT_SEARCH_WEEKLY_LIMIT = 1000;
const MAX_AI_CONTENTS = 24;
const MAX_AI_PARTS_PER_MESSAGE = 8;
const MAX_AI_SYSTEM_CHARS = 8000;
const MAX_AI_TOTAL_TEXT_CHARS = 32000;
const MAX_AI_IMAGES = 3;
const MAX_AI_IMAGE_BASE64_CHARS = 2_000_000;
const ALLOWED_IMAGE_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/heic",
  "image/heif",
]);
const ALLOWED_APP_CHECK_APP_IDS = new Set(
  String(process.env.FOODTRACKER_APP_CHECK_APP_IDS || "1:667537183554:ios:d28f3e33988402cc786edb")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean)
);
const MAX_SCHEMA_BYTES = 16_384;
const UPSTREAM_TIMEOUT_MS = 22000;
const HEAVY_UPSTREAM_TIMEOUT_MS = 45000;
const TOTAL_CHAIN_BUDGET_MS = 85000;
const FATSECRET_TOTAL_BUDGET_MS = 22000;

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
let fatSecretTokenInFlight = null;
let fatSecretAuthModeCache = null;
let aiSettingsCache = null;
const AI_SETTINGS_CACHE_TTL_MS = 60_000;

// Text fallback chain ordered by live ZDR (data_collection: "deny") availability & JSON support.
const TEXT_MODEL_CHAIN = [
  "recursive/flint-v1.0:free",
  "google/gemma-4-31b-it:free",
  "google/gemma-4-26b-a4b-it:free",
];

// Multimodal fallback chain for food/menu photos (live ZDR-compatible image-capable :free models).
const VISION_MODEL_CHAIN = [
  "google/gemma-4-31b-it:free",
  "google/gemma-4-26b-a4b-it:free",
];

// Paid ZDR-compatible SLA fallback. Appended after the free chain ONLY when explicitly opted-in.
// Production defaults this OFF (zero cents spent); set config/food_ai_settings.allowPaidFallback = true
// or FOOD_AI_ALLOW_PAID_FALLBACK=true to opt in without an iOS release.
const PAID_TEXT_FALLBACK_MODELS = [
  "google/gemini-2.5-flash-lite",
  "google/gemini-2.5-flash",
];

const PAID_VISION_FALLBACK_MODELS = [
  "google/gemini-2.5-flash-lite",
  "google/gemini-2.5-flash",
];

const STRUCTURED_MODELS = new Set([
  "google/gemini-2.5-flash-lite",
  "google/gemini-2.5-flash",
]);

const JSON_OBJECT_MODELS = new Set([
  ...STRUCTURED_MODELS,
  "recursive/flint-v1.0:free",
  "google/gemma-4-31b-it:free",
  "google/gemma-4-26b-a4b-it:free",
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

function upstreamTimeoutForBody(body) {
  if (hasImageContent(body)) {
    return HEAVY_UPSTREAM_TIMEOUT_MS;
  }
  const contents = Array.isArray(body?.contents) ? body.contents : [];
  let totalPromptChars = 0;
  let mentionsHeavyPlan = false;
  for (const c of contents) {
    const parts = Array.isArray(c?.parts) ? c.parts : [];
    for (const p of parts) {
      if (typeof p?.text === "string") {
        totalPromptChars += p.text.length;
        if (
          p.text.includes("7-day") ||
          p.text.includes("dayIndex") ||
          p.text.includes('"days"')
        ) {
          mentionsHeavyPlan = true;
        }
      }
    }
  }
  const maxTokens = Number(body?.generationConfig?.maxOutputTokens || 0);
  if (totalPromptChars >= 600 || mentionsHeavyPlan || maxTokens >= 2000) {
    return HEAVY_UPSTREAM_TIMEOUT_MS;
  }
  return UPSTREAM_TIMEOUT_MS;
}

function isFreeModelId(model) {
  return model.endsWith(":free") || model === "openrouter/free";
}

// Keep the tail of the chain budget for a paid SLA attempt so slow :free timeouts
// cannot consume the whole 85s window before Gemini Flash is tried.
const PAID_FALLBACK_RESERVE_MS = 25000;

function resolveAllowPaidFallback(explicitValue, envValue = process.env.FOOD_AI_ALLOW_PAID_FALLBACK) {
  if (typeof explicitValue === "boolean") return explicitValue;
  return envValue === "true";
}

function shouldRefundQuotaSlot({ yielded = false, receivedCompletion = false, attemptedPaid = false } = {}) {
  return !yielded && !receivedCompletion && !attemptedPaid;
}

function shouldYieldFreeSlotToPaidFallback(model, chain, remainingMs, reserveMs = PAID_FALLBACK_RESERVE_MS) {
  if (!model || !isFreeModelId(model)) return false;
  if (!Array.isArray(chain) || !chain.some((candidate) => candidate && !isFreeModelId(candidate))) {
    return false;
  }
  return remainingMs < reserveMs;
}

function logUpstreamModelFailure(model, status, errText) {
  const statusNum = Number(status) || 0;
  const payload = JSON.stringify({
    event: "openrouter_upstream_failure",
    model,
    status: statusNum,
    paidFallback: !isFreeModelId(model),
  });
  const detail = String(errText || "").slice(0, 180);
  if (statusNum === 429 || statusNum === 502 || statusNum === 503) {
    console.error(payload, detail);
  } else {
    console.warn(payload, detail);
  }
}

function modelChainForRequest(body, overrides = {}) {
  const isVision = hasImageContent(body);
  const primary = isVision
    ? Array.isArray(overrides.visionModels) && overrides.visionModels.length > 0
      ? overrides.visionModels
      : VISION_MODEL_CHAIN
    : Array.isArray(overrides.textModels) && overrides.textModels.length > 0
      ? overrides.textModels
      : TEXT_MODEL_CHAIN;

  if (!overrides.allowPaidFallback) {
    return primary;
  }

  const paid = isVision
    ? Array.isArray(overrides.paidVisionModels) && overrides.paidVisionModels.length > 0
      ? overrides.paidVisionModels
      : PAID_VISION_FALLBACK_MODELS
    : Array.isArray(overrides.paidTextModels) && overrides.paidTextModels.length > 0
      ? overrides.paidTextModels
      : PAID_TEXT_FALLBACK_MODELS;

  const seen = new Set();
  const combined = [];
  for (const m of [...primary, ...paid]) {
    if (m && !seen.has(m)) {
      seen.add(m);
      combined.push(m);
    }
  }
  return combined;
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

const MAX_SCHEMA_DEPTH = 10;

function validateSchemaDepth(schema, depth = 0) {
  if (!schema || typeof schema !== "object") return;
  if (depth > MAX_SCHEMA_DEPTH) {
    throw new Error(`responseSchema exceeds max depth (${MAX_SCHEMA_DEPTH})`);
  }
  if (schema.properties && typeof schema.properties === "object") {
    for (const value of Object.values(schema.properties)) {
      validateSchemaDepth(value, depth + 1);
    }
  }
  if (schema.items && typeof schema.items === "object") {
    validateSchemaDepth(schema.items, depth + 1);
  }
}

function convertGeminiSchema(schema, depth = 0) {
  if (!schema || typeof schema !== "object" || depth > MAX_SCHEMA_DEPTH) return undefined;
  const out = { type: geminiTypeToJson(schema.type) };
  if (schema.description) out.description = schema.description;
  if (schema.properties && typeof schema.properties === "object") {
    out.properties = {};
    for (const [key, value] of Object.entries(schema.properties)) {
      const converted = convertGeminiSchema(value, depth + 1);
      if (converted) out.properties[key] = converted;
    }
  }
  if (schema.items) {
    const convertedItems = convertGeminiSchema(schema.items, depth + 1);
    if (convertedItems) out.items = convertedItems;
  }
  if (Array.isArray(schema.required)) out.required = schema.required;
  return out;
}

function validateAiProxyBody(body) {
  if (!body || typeof body !== "object" || !Array.isArray(body.contents) || body.contents.length === 0) {
    throw new Error("Missing contents array");
  }
  if (body.contents.length > MAX_AI_CONTENTS) {
    throw new Error(`Too many content messages (max ${MAX_AI_CONTENTS})`);
  }

  if (body.generationConfig?.responseMimeType !== undefined) {
    const mime = body.generationConfig.responseMimeType;
    if (mime !== "text/plain" && mime !== "application/json") {
      throw new Error(`Unsupported responseMimeType: ${String(mime)}`);
    }
  }
  if (body.generationConfig?.responseSchema !== undefined) {
    validateSchemaDepth(body.generationConfig.responseSchema, 0);
    const serializedSchema = JSON.stringify(body.generationConfig.responseSchema);
    if (!serializedSchema || serializedSchema.length > MAX_SCHEMA_BYTES) {
      throw new Error(`responseSchema exceeds max size (${MAX_SCHEMA_BYTES} bytes)`);
    }
  }

  let totalTextChars = 0;
  let totalImages = 0;

  if (body.systemInstruction !== undefined) {
    const sysParts = body.systemInstruction?.parts;
    if (!Array.isArray(sysParts) || sysParts.length > MAX_AI_PARTS_PER_MESSAGE) {
      throw new Error("Invalid systemInstruction parts");
    }
    let sysChars = 0;
    for (const part of sysParts) {
      if (!part || typeof part !== "object" || part.inlineData !== undefined) {
        throw new Error("Invalid systemInstruction part");
      }
      if (part.text !== undefined) {
        if (typeof part.text !== "string") {
          throw new Error("Invalid systemInstruction text");
        }
        sysChars += part.text.length;
      }
    }
    if (sysChars > MAX_AI_SYSTEM_CHARS) {
      throw new Error(`System instruction too long (max ${MAX_AI_SYSTEM_CHARS} chars)`);
    }
    totalTextChars += sysChars;
  }

  for (const content of body.contents) {
    if (!content || typeof content !== "object") {
      throw new Error("Invalid content entry");
    }
    if (content.role !== undefined) {
      if (content.role !== "user" && content.role !== "model" && content.role !== "assistant") {
        throw new Error(`Unsupported message role: ${String(content.role)}`);
      }
    }
    const parts = content.parts;
    if (!Array.isArray(parts) || parts.length === 0 || parts.length > MAX_AI_PARTS_PER_MESSAGE) {
      throw new Error("Invalid content parts array");
    }
    for (const part of parts) {
      if (!part || typeof part !== "object" || (part.text === undefined && part.inlineData === undefined)) {
        throw new Error("Invalid part entry");
      }
      if (part.text !== undefined) {
        if (typeof part.text !== "string") {
          throw new Error("Invalid text part");
        }
        totalTextChars += part.text.length;
        if (totalTextChars > MAX_AI_TOTAL_TEXT_CHARS) {
          throw new Error(`Prompt text too long (max ${MAX_AI_TOTAL_TEXT_CHARS} chars)`);
        }
      }
      if (part.inlineData !== undefined) {
        totalImages += 1;
        if (totalImages > MAX_AI_IMAGES) {
          throw new Error(`Too many images (max ${MAX_AI_IMAGES})`);
        }
        const mimeType = String(part.inlineData?.mimeType || "").trim().toLowerCase();
        if (!ALLOWED_IMAGE_MIME_TYPES.has(mimeType)) {
          throw new Error(`Unsupported image mimeType: ${mimeType || "empty"}`);
        }
        part.inlineData.mimeType = mimeType;
        const data = part.inlineData?.data;
        if (typeof data !== "string" || data.length === 0) {
          throw new Error("Empty image payload");
        }
        if (data.length > MAX_AI_IMAGE_BASE64_CHARS) {
          throw new Error(`Image payload too large (max ${MAX_AI_IMAGE_BASE64_CHARS} base64 chars)`);
        }
        if (!/^[A-Za-z0-9+/=]+$/.test(data)) {
          throw new Error("Invalid base64 image payload (unexpected whitespace or characters)");
        }
      }
    }
  }
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
        content.role === "model" || content.role === "assistant" ? "assistant" : "user";
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
  const rawTemp = typeof gen.temperature === "number" && Number.isFinite(gen.temperature) ? gen.temperature : 0.4;
  const temperature = Math.min(2, Math.max(0, rawTemp));
  const wantsJson =
    gen.responseMimeType === "application/json" || Boolean(gen.responseSchema);

  const openAIBody = {
    model,
    messages,
    temperature,
    stream: Boolean(streaming),
    provider: { data_collection: "deny" },
  };
  if (
    typeof gen.maxOutputTokens === "number" &&
    Number.isFinite(gen.maxOutputTokens) &&
    gen.maxOutputTokens >= 1
  ) {
    openAIBody.max_tokens = Math.min(16384, Math.max(1, Math.floor(gen.maxOutputTokens)));
  }

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
  let fallbackArrayCandidate = null;
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
            if (opener === "{") {
              return candidate;
            }
            // Prefer structured arrays over citation brackets like [1].
            if (candidate.includes("{") || candidate.includes('"')) {
              return candidate;
            }
            if (!fallbackArrayCandidate) {
              fallbackArrayCandidate = candidate;
            }
          } catch {
            // keep scanning
          }
          break;
        }
      }
    }
  }
  return fallbackArrayCandidate;
}

function stripModelJSON(raw) {
  const text = String(raw || "").trim();
  for (const match of text.matchAll(/```(?:json|JSON)?\s*([\s\S]*?)```/g)) {
    const inner = match[1]?.trim();
    if (!inner) continue;
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
  let parsed;
  try {
    parsed = JSON.parse(payload);
  } catch {
    return null;
  }
  if (parsed?.error) {
    const msg = parsed.error?.message || JSON.stringify(parsed.error);
    throw new Error(`Stream upstream error: ${String(msg).slice(0, 240)}`);
  }
  const delta = extractMessageText(
    parsed?.choices?.[0]?.delta?.content ??
      parsed?.choices?.[0]?.message?.content ??
      ""
  );
  if (!delta) return null;
  return JSON.stringify({
    candidates: [{ content: { parts: [{ text: delta }] } }],
  });
}

function isMeaningfulJsonOutput(text) {
  const parsed = JSON.parse(text);
  if (Array.isArray(parsed)) return parsed.length > 0;
  if (parsed && typeof parsed === "object") return Object.keys(parsed).length > 0;
  return false;
}

function sanitizeModelOverrides(models, { allowPaid = false } = {}) {
  if (!Array.isArray(models)) return null;
  const cleaned = models
    .map((m) => (typeof m === "string" ? m.trim() : ""))
    .filter((m) => m.length > 0 && (allowPaid || isFreeModelId(m)));
  return cleaned.length > 0 ? cleaned : null;
}

function resolveUserQuotaLimit(baseLimit, signInProvider, kind = "ai") {
  const safeBase =
    typeof baseLimit === "number" && Number.isFinite(baseLimit) && baseLimit > 0
      ? baseLimit
      : kind === "search"
        ? DEFAULT_SEARCH_WEEKLY_LIMIT
        : DEFAULT_AI_WEEKLY_LIMIT;
  if (signInProvider === "anonymous") {
    const anonCap = kind === "search" ? 250 : 60;
    return Math.min(safeBase, anonCap);
  }
  return safeBase;
}

function resolveDeviceQuotaLimit(baseLimit, signInProvider, kind = "ai") {
  const safeBase =
    typeof baseLimit === "number" && Number.isFinite(baseLimit) && baseLimit > 0
      ? baseLimit
      : kind === "search"
        ? DEFAULT_SEARCH_WEEKLY_LIMIT
        : DEFAULT_AI_WEEKLY_LIMIT;
  if (signInProvider === "anonymous") {
    return kind === "search" ? Math.min(safeBase * 2, 500) : Math.min(safeBase * 2, 120);
  }
  return safeBase * 2;
}

async function loadAISettings() {
  const now = Date.now();
  if (aiSettingsCache && now - aiSettingsCache.loadedAtMs < AI_SETTINGS_CACHE_TTL_MS) {
    return aiSettingsCache.value;
  }
  try {
    const db = getFirestore();
    const snap = await db.collection("config").doc("food_ai_settings").get();
    const data = snap.exists ? snap.data() || {} : {};
    const allowPaidModels = data.allowPaidModels === true;
    const allowPaidFallback = resolveAllowPaidFallback(data.allowPaidFallback);
    const value = {
      weeklyLimit:
        typeof data.weeklyLimit === "number" &&
        Number.isFinite(data.weeklyLimit) &&
        data.weeklyLimit > 0
          ? data.weeklyLimit
          : DEFAULT_AI_WEEKLY_LIMIT,
      textModels: sanitizeModelOverrides(data.textModels, { allowPaid: allowPaidModels }),
      visionModels: sanitizeModelOverrides(data.visionModels, { allowPaid: allowPaidModels }),
      allowPaidFallback,
      paidTextModels: sanitizeModelOverrides(data.paidTextModels, { allowPaid: true }),
      paidVisionModels: sanitizeModelOverrides(data.paidVisionModels, { allowPaid: true }),
    };
    aiSettingsCache = { value, loadedAtMs: now };
    return value;
  } catch (e) {
    console.warn("Could not load config/food_ai_settings, using defaults:", e);
    return (
      aiSettingsCache?.value || {
        weeklyLimit: DEFAULT_AI_WEEKLY_LIMIT,
        textModels: null,
        visionModels: null,
        allowPaidFallback: resolveAllowPaidFallback(undefined),
        paidTextModels: null,
        paidVisionModels: null,
      }
    );
  }
}

function computeRateLimitTransition(existingData, nowMs, limit, windowMs = AI_WINDOW_MS) {
  let windowStart = nowMs;
  let count = 0;

  if (existingData && typeof existingData === "object") {
    const ws = typeof existingData.windowStart === "number" ? existingData.windowStart : 0;
    if (nowMs - ws < windowMs) {
      windowStart = ws;
      count = existingData.count || 0;
    }
  }

  if (count >= limit) {
    const retryAfterSeconds = Math.max(1, Math.ceil((windowStart + windowMs - nowMs) / 1000));
    return { allowed: false, nextWindowStart: windowStart, nextCount: count, retryAfterSeconds };
  }

  return { allowed: true, nextWindowStart: windowStart, nextCount: count + 1, retryAfterSeconds: 0 };
}

async function reserveDualRateLimitSlots({
  userCollection,
  deviceCollection,
  uid,
  deviceHash,
  ipHash = null,
  userLimit,
  deviceLimit,
  ipLimit = null,
  windowMs = AI_WINDOW_MS,
}) {
  const db = getFirestore();
  const userRef = db.collection(userCollection).doc(uid);
  const deviceRef = deviceHash ? db.collection(deviceCollection).doc(deviceHash) : null;
  const shouldTrackSeparateIp = Boolean(ipHash && ipHash !== deviceHash && ipLimit);
  const ipRef = shouldTrackSeparateIp ? db.collection(deviceCollection).doc(ipHash) : null;

  return db.runTransaction(async (tx) => {
    const now = Date.now();
    const userSnap = await tx.get(userRef);
    const deviceSnap = deviceRef ? await tx.get(deviceRef) : null;
    const ipSnap = ipRef ? await tx.get(ipRef) : null;

    const userTransition = computeRateLimitTransition(
      userSnap.exists ? userSnap.data() : null,
      now,
      userLimit,
      windowMs
    );
    if (!userTransition.allowed) {
      throw new RateLimitError(userTransition.retryAfterSeconds, userLimit);
    }

    let deviceTransition = null;
    if (deviceRef && deviceSnap) {
      deviceTransition = computeRateLimitTransition(
        deviceSnap.exists ? deviceSnap.data() : null,
        now,
        deviceLimit,
        windowMs
      );
      if (!deviceTransition.allowed) {
        throw new RateLimitError(deviceTransition.retryAfterSeconds, deviceLimit);
      }
    }

    let ipTransition = null;
    if (ipRef && ipSnap) {
      ipTransition = computeRateLimitTransition(
        ipSnap.exists ? ipSnap.data() : null,
        now,
        ipLimit,
        windowMs
      );
      if (!ipTransition.allowed) {
        throw new RateLimitError(ipTransition.retryAfterSeconds, ipLimit);
      }
    }

    tx.set(
      userRef,
      {
        windowStart: userTransition.nextWindowStart,
        count: userTransition.nextCount,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    if (deviceRef && deviceTransition) {
      tx.set(
        deviceRef,
        {
          windowStart: deviceTransition.nextWindowStart,
          count: deviceTransition.nextCount,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    if (ipRef && ipTransition) {
      tx.set(
        ipRef,
        {
          windowStart: ipTransition.nextWindowStart,
          count: ipTransition.nextCount,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    return {
      userWindowStart: userTransition.nextWindowStart,
      deviceWindowStart: deviceTransition ? deviceTransition.nextWindowStart : null,
      ipWindowStart: ipTransition ? ipTransition.nextWindowStart : null,
    };
  });
}

async function refundRateLimitSlot(collectionName, docId, expectedWindowStart = null) {
  try {
    const db = getFirestore();
    const ref = db.collection(collectionName).doc(docId);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const data = snap.data() || {};
      if (
        expectedWindowStart !== null &&
        typeof data.windowStart === "number" &&
        data.windowStart !== expectedWindowStart
      ) {
        return;
      }
      const current = typeof data.count === "number" ? data.count : 0;
      if (current <= 0) return;
      tx.set(
        ref,
        {
          count: current - 1,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    });
  } catch (e) {
    console.warn(`Failed to refund slot in ${collectionName}/${docId}:`, e?.message || e);
  }
}

function hashDeviceInstallId(raw) {
  const cleaned = String(raw || "").trim();
  if (!/^[A-Za-z0-9-]{16,128}$/.test(cleaned)) return null;
  return crypto.createHash("sha256").update(cleaned).digest("hex");
}

function normalizeIpAddress(raw) {
  return String(raw || "").trim().replace(/^::ffff:/i, "");
}

function isInternalOrReservedIp(ip) {
  const norm = normalizeIpAddress(ip);
  if (!norm) return true;
  return /^(10\.|127\.|192\.168\.|169\.254\.|172\.(1[6-9]|2\d|3[01])\.|100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.|::1$|fc[0-9a-f]{2}:|fd[0-9a-f]{2}:|fe[89ab][0-9a-f]:)/i.test(
    norm
  );
}

function resolveIpQuotaKey(req) {
  const reqIp = normalizeIpAddress(req?.ip);
  let clientIp = reqIp && !isInternalOrReservedIp(reqIp) ? reqIp : "";
  if (!clientIp) {
    const xffParts = String(req?.header?.("x-forwarded-for") || "")
      .split(",")
      .map((s) => normalizeIpAddress(s))
      .filter(Boolean);
    const nonInternal = [...xffParts]
      .reverse()
      .find((ip) => !isInternalOrReservedIp(ip));
    clientIp = nonInternal || xffParts[0] || reqIp;
  }
  if (!clientIp) return null;
  const ipHash = crypto.createHash("sha256").update(clientIp).digest("hex");
  return `ip:${ipHash}`;
}

function resolveSecondaryQuotaKey(req) {
  const deviceHash = hashDeviceInstallId(req?.header?.("X-Device-Install-ID"));
  if (deviceHash) {
    return `device:${deviceHash}`;
  }
  return resolveIpQuotaKey(req);
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

async function callOpenRouterText({ apiKeys, geminiBody, overrides = {}, attemptMeta = null }) {
  const chain = modelChainForRequest(geminiBody, overrides);
  const expectJSON =
    geminiBody?.generationConfig?.responseMimeType === "application/json" ||
    Boolean(geminiBody?.generationConfig?.responseSchema);
  const keys = rotatedKeys(apiKeys);
  const attemptTimeoutMs = upstreamTimeoutForBody(geminiBody);
  const deadlineAt = Date.now() + TOTAL_CHAIN_BUDGET_MS;

  let lastError = null;
  modelLoop: for (const model of chain) {
    const remainingMs = deadlineAt - Date.now();
    if (shouldYieldFreeSlotToPaidFallback(model, chain, remainingMs)) {
      console.warn(
        `Skipping free model ${model}; reserving ${remainingMs}ms for paid SLA fallback`
      );
      continue;
    }
    if (remainingMs < 5000) {
      break;
    }
    if (!isFreeModelId(model)) {
      if (attemptMeta) attemptMeta.attemptedPaid = true;
      console.warn(`OpenRouter free chain exhausted; falling back to SLA model ${model}`);
    }
    const perCallTimeout = Math.min(attemptTimeoutMs, remainingMs);
    const attempt = geminiBodyToOpenAI(geminiBody, {
      streaming: false,
      model,
    });

    for (const apiKey of keys) {
      const keyRemainingMs = deadlineAt - Date.now();
      if (keyRemainingMs < 3000) break;
      const callTimeout = Math.min(perCallTimeout, keyRemainingMs);
      try {
        const resp = await fetch(OPENROUTER_URL, {
          method: "POST",
          headers: openRouterHeaders(apiKey),
          body: JSON.stringify(attempt),
          signal: AbortSignal.timeout(callTimeout),
        });
        const text = await resp.text();
        if (!resp.ok) {
          lastError = new Error(
            `OpenRouter ${resp.status} ${model}: ${text.slice(0, 400)}`
          );
          logUpstreamModelFailure(model, resp.status, text);
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
        if (attemptMeta) attemptMeta.receivedCompletion = true;
        if (expectJSON) {
          try {
            if (!isMeaningfulJsonOutput(outText)) {
              throw new Error("Empty JSON container");
            }
          } catch (e) {
            lastError = new Error(
              `Invalid JSON output from ${model}: ${e.message}`
            );
            console.warn(lastError.message);
            if (!isFreeModelId(model)) {
              break modelLoop;
            }
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

async function verifyAppCheck(
  req,
  res,
  verifyTokenFn = (token) => getAppCheck().verifyToken(token)
) {
  const appCheckToken = req.header("X-Firebase-AppCheck");
  if (!appCheckToken) {
    res.status(401).json({ error: "Missing App Check token" });
    return false;
  }
  try {
    const decoded = await verifyTokenFn(appCheckToken);
    const appId = String(decoded?.appId || decoded?.app_id || "").trim();
    if (!appId || !ALLOWED_APP_CHECK_APP_IDS.has(appId)) {
      res.status(401).json({ error: "Invalid App Check app" });
      return false;
    }
    return true;
  } catch (e) {
    res.status(401).json({ error: "Invalid App Check token" });
    return false;
  }
}

const ENDPOINT_AUTH_OPTIONS = Object.freeze({
  foodAiProxy: Object.freeze({}),
  foodSearchProxy: Object.freeze({}),
  foodDeleteAccount: Object.freeze({ requireRecentAuthSec: 300 }),
});

async function verifyFirebaseUser(
  req,
  res,
  verifyIdTokenFn = (token, checkRevoked) => getAuth().verifyIdToken(token, checkRevoked),
  options = {}
) {
  const authHeader = req.header("Authorization") || "";
  const m = authHeader.match(/^Bearer (.+)$/i);
  if (!m) {
    res.status(401).json({ error: "Missing Firebase ID token" });
    return null;
  }
  try {
    const decoded = await verifyIdTokenFn(m[1], true);
    const provider = decoded?.firebase?.sign_in_provider || "";
    const requireRecentAuthSec = Number(options?.requireRecentAuthSec || 0);
    if (requireRecentAuthSec > 0 && provider !== "anonymous") {
      const authTime = Number(decoded?.auth_time || 0);
      const nowSec = Math.floor(Date.now() / 1000);
      if (!Number.isFinite(authTime) || authTime <= 0 || nowSec - authTime > requireRecentAuthSec) {
        res.status(401).json({ error: "requires_recent_login" });
        return null;
      }
    }
    if (req && typeof req === "object") {
      req._authSignInProvider = provider;
    }
    return decoded.uid;
  } catch (e) {
    const message =
      e?.code === "auth/id-token-revoked"
        ? "Firebase ID token revoked"
        : "Invalid Firebase ID token";
    res.status(401).json({ error: message });
    return null;
  }
}

function isValidEAN8(digits) {
  if (!/^\d{8}$/.test(digits)) return false;
  let sum = 0;
  for (let i = 0; i < 7; i++) {
    sum += Number(digits[i]) * (i % 2 === 0 ? 3 : 1);
  }
  const check = (10 - (sum % 10)) % 10;
  return check === Number(digits[7]);
}

function isValidUPCACheckDigit(upca) {
  if (!/^\d{12}$/.test(upca)) return false;
  let oddSum = 0;
  let evenSum = 0;
  for (let i = 0; i < 11; i++) {
    const n = Number(upca[i]);
    if (i % 2 === 0) oddSum += n;
    else evenSum += n;
  }
  const check = (10 - ((oddSum * 3 + evenSum) % 10)) % 10;
  return check === Number(upca[11]);
}

function expandUPCEtoUPCA(upce) {
  if (!/^[01]\d{7}$/.test(upce)) return null;
  const [n, d1, d2, d3, d4, d5, d6, check] = upce;
  let expanded;
  if (d6 === "0" || d6 === "1" || d6 === "2") {
    expanded = `${n}${d1}${d2}${d6}0000${d3}${d4}${d5}${check}`;
  } else if (d6 === "3") {
    expanded = `${n}${d1}${d2}${d3}00000${d4}${d5}${check}`;
  } else if (d6 === "4") {
    expanded = `${n}${d1}${d2}${d3}${d4}00000${d5}${check}`;
  } else {
    expanded = `${n}${d1}${d2}${d3}${d4}${d5}0000${d6}${check}`;
  }
  return isValidUPCACheckDigit(expanded) ? expanded : null;
}

function normalizeFatSecretBarcodeInput(barcode) {
  let cleaned = String(barcode || "").trim();
  if (/^[01]\d{7}$/.test(cleaned)) {
    const isEan8Only = cleaned[0] === "1" && isValidEAN8(cleaned);
    if (!isEan8Only) {
      cleaned = expandUPCEtoUPCA(cleaned) || cleaned;
    }
  }
  if (/^\d{8,12}$/.test(cleaned)) {
    return cleaned.padStart(13, "0");
  }
  return cleaned;
}

function parseNumericValue(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const trimmed = value.trim();
    if (!trimmed) return 0;
    const cleaned = /^\d{1,3}(,\d{3})+(\.\d+)?$/.test(trimmed)
      ? trimmed.replace(/,/g, "")
      : trimmed.replace(",", ".");
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

function convertMetricWeightToGrams(amount, rawUnit) {
  if (!Number.isFinite(amount) || amount <= 0) return 0;
  const unit = String(rawUnit || "").trim().toLowerCase();
  switch (unit) {
    case "g":
    case "gram":
    case "grams":
    case "ml":
      return amount;
    case "oz":
      return amount * 28.3495;
    case "fl oz":
      return amount * 29.5735;
    case "lb":
    case "lbs":
      return amount * 453.59237;
    case "kg":
      return amount * 1000;
    case "mg":
      return amount / 1000;
    default:
      return amount;
  }
}

function pickPreferredFatSecretServing(servingData) {
  if (!Array.isArray(servingData)) return servingData;
  const objects = servingData.filter((s) => s && typeof s === "object");
  if (objects.length === 0) return null;

  const is100g = (s) => {
    const unit = String(s.metric_serving_unit || "").trim().toLowerCase();
    const amt = parseNumericValue(s.metric_serving_amount);
    return (unit === "g" || unit === "ml") && Math.abs(amt - 100) < 0.01;
  };
  if (objects.find(is100g)) return objects.find(is100g);

  const hasValidMetric = (s) => {
    const unit = String(s.metric_serving_unit || "").trim().toLowerCase();
    const amt = parseNumericValue(s.metric_serving_amount);
    return amt > 0 && ["g", "gram", "grams", "ml", "oz", "fl oz", "lb", "lbs", "kg", "mg"].includes(unit);
  };
  return objects.find(hasValidMetric) || objects[0];
}

function roundServingWeightGrams(weightGrams) {
  if (!Number.isFinite(weightGrams) || weightGrams <= 0) return 0;
  const rounded = Math.round(weightGrams * 10) / 10 || Math.round(weightGrams * 1000) / 1000;
  return rounded > 0 ? rounded : 0;
}

function roundNutrientValue(val) {
  return Math.round(val * 100) / 100;
}

function parseFatSecretDescription(description) {
  if (typeof description !== "string" || !description) return null;
  const calMatch = description.match(/Calories:\s*([0-9.,]+)\s*kcal/i);
  const fatMatch = description.match(/Fat:\s*([0-9.,]+)\s*g/i);
  const carbMatch = description.match(/Carbs:\s*([0-9.,]+)\s*g/i);
  const protMatch = description.match(/Protein:\s*([0-9.,]+)\s*g/i);
  if (!calMatch && !fatMatch && !carbMatch && !protMatch) return null;

  const weightMatch = description.match(/^Per\s+([0-9.,]+)\s*(fl\s+oz|g|ml|oz|lb|lbs|kg|mg)\b/i);
  const parsedWeight = weightMatch
    ? convertMetricWeightToGrams(
        parseNumericValue(weightMatch[1]),
        weightMatch[2].replace(/\s+/g, " ")
      )
    : 0;
  return {
    weight: roundServingWeightGrams(parsedWeight),
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

  const serving = pickPreferredFatSecretServing(food?.servings?.serving);
  if (serving && typeof serving === "object") {
    const rawAmount = parseNumericValue(serving.metric_serving_amount);
    const weightGrams = convertMetricWeightToGrams(rawAmount, serving.metric_serving_unit);
    const roundedWeight = roundServingWeightGrams(weightGrams);
    const servingDesc =
      typeof serving.serving_description === "string"
        ? serving.serving_description.trim()
        : "";
    const result = {
      name,
      weight: roundedWeight,
      calories: Math.round(parseNumericValue(serving.calories)),
      protein: parseNumericValue(serving.protein),
      fats: parseNumericValue(serving.fat),
      carbs: parseNumericValue(serving.carbohydrate),
    };
    if (servingDesc) {
      result.servingDescription = servingDesc;
    }
    // FatSecret reports calcium (1300mg DV), iron (18mg DV), vitamin_c (90mg DV), vitamin_d (20mcg DV) in % Daily Value.
    const calciumPct = parseNumericValue(serving.calcium);
    const ironPct = parseNumericValue(serving.iron);
    const vitCPct = parseNumericValue(serving.vitamin_c);
    const vitDPct = parseNumericValue(serving.vitamin_d);
    const microMap = {
      omega3: parseNumericValue(serving.omega_3 ?? serving.omega3),
      calcium: calciumPct > 0 ? roundNutrientValue((calciumPct / 100) * 1300) : 0,
      potassium: parseNumericValue(serving.potassium),
      magnesium: parseNumericValue(serving.magnesium),
      iron: ironPct > 0 ? roundNutrientValue((ironPct / 100) * 18) : 0,
      vitaminC: vitCPct > 0 ? roundNutrientValue((vitCPct / 100) * 90) : 0,
      vitaminD: vitDPct > 0 ? roundNutrientValue((vitDPct / 100) * 20) : 0,
    };
    for (const [k, v] of Object.entries(microMap)) {
      if (v > 0) result[k] = v;
    }
    return result;
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

function sanitizeUpstreamErrorMessage(_raw, kind = "ai") {
  if (kind === "search") {
    return "Food database temporarily unavailable. Please try again later.";
  }
  return "AI service temporarily unavailable. Please try again later.";
}

function assertFatSecretDetailSuccess(detail) {
  if (detail?.error) {
    const code = Number(detail.error?.code);
    throw new Error(`FatSecret detail error ${Number.isFinite(code) ? code : "unknown"}: ${detail.error?.message || "unknown"}`);
  }
}

function assertFatSecretResponseSuccess(data) {
  if (data?.error) {
    const code = Number(data.error?.code || 0);
    throw new Error(`FatSecret error ${code}: ${data.error?.message || "Unknown error"}`);
  }
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
  timeoutMs = FATSECRET_TIMEOUT_MS,
}) {
  if (!forceRefresh && isTokenValid(fatSecretTokenCache)) {
    return fatSecretTokenCache.token;
  }
  if (!clientId || !clientSecret) {
    throw new Error("FatSecret credentials not configured");
  }
  if (!forceRefresh && fatSecretTokenInFlight) {
    return fatSecretTokenInFlight;
  }

  const runFetch = (async () => {
    const basic = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
    const resp = await fetch(FATSECRET_TOKEN_URL, {
      method: "POST",
      headers: {
        Authorization: `Basic ${basic}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: "grant_type=client_credentials&scope=basic",
      signal: AbortSignal.timeout(timeoutMs),
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
  })();

  fatSecretTokenInFlight = runFetch;
  try {
    return await runFetch;
  } finally {
    if (fatSecretTokenInFlight === runFetch) {
      fatSecretTokenInFlight = null;
    }
  }
}

exports.foodAiProxy = onRequest(
  {
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    memory: "512MiB",
    concurrency: 8,
    timeoutSeconds: 300,
    secrets: [openRouterApiKey],
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }
    if (!(await verifyAppCheck(req, res))) return;
    const uid = await verifyFirebaseUser(
      req,
      res,
      (token, checkRevoked) => getAuth().verifyIdToken(token, checkRevoked),
      ENDPOINT_AUTH_OPTIONS.foodAiProxy
    );
    if (!uid) return;

    const body = req.body || {};
    try {
      validateAiProxyBody(body);
    } catch (e) {
      res.status(400).json({ error: "invalid_request", message: e.message });
      return;
    }

    const apiKeys = parseApiKeys(openRouterApiKey.value());
    if (apiKeys.length === 0) {
      res.status(500).json({ error: "OPENROUTER_API_KEY not configured" });
      return;
    }

    const settings = await loadAISettings();
    const userAiLimit = resolveUserQuotaLimit(settings.weeklyLimit, req._authSignInProvider, "ai");
    const deviceAiLimit = resolveDeviceQuotaLimit(settings.weeklyLimit, req._authSignInProvider, "ai");
    const deviceHash = resolveSecondaryQuotaKey(req);
    const ipHash = resolveIpQuotaKey(req);

    let reservedWindows;
    try {
      reservedWindows = await reserveDualRateLimitSlots({
        userCollection: "food_ai_usage",
        deviceCollection: "food_ai_device_usage",
        uid,
        deviceHash,
        ipHash,
        userLimit: userAiLimit,
        deviceLimit: deviceAiLimit,
        ipLimit: settings.weeklyLimit * 8,
      });
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
      console.error("Rate limit reservation failed:", e);
      res.status(500).json({ error: "Rate limit check failed" });
      return;
    }

    const refundReservedSlots = async () => {
      await refundRateLimitSlot("food_ai_usage", uid, reservedWindows.userWindowStart);
      if (deviceHash) {
        await refundRateLimitSlot(
          "food_ai_device_usage",
          deviceHash,
          reservedWindows.deviceWindowStart
        );
      }
      if (ipHash && ipHash !== deviceHash && reservedWindows.ipWindowStart !== null) {
        await refundRateLimitSlot(
          "food_ai_device_usage",
          ipHash,
          reservedWindows.ipWindowStart
        );
      }
    };

    const streaming = req.query.stream === "true";

    const attemptMeta = { receivedCompletion: false, attemptedPaid: false };
    let yielded = false;
    try {
      if (!streaming) {
        const gemini = await callOpenRouterText({
          apiKeys,
          geminiBody: body,
          overrides: settings,
          attemptMeta,
        });
        res.status(200).json(gemini);
        return;
      }

      const chain = modelChainForRequest(body, settings);
      const streamTimeoutMs = upstreamTimeoutForBody(body);
      const streamDeadlineAt = Date.now() + TOTAL_CHAIN_BUDGET_MS;
      const keys = rotatedKeys(apiKeys);
      let lastError = null;

      let emittedDone = false;
      const emitStreamLine = (rawLine) => {
        const line = rawLine.trimEnd();
        if (!line) return false;
        const converted = openAIStreamChunkToGemini(line);
        if (converted === "[DONE]") {
          if (yielded && !emittedDone) {
            res.write("data: [DONE]\n\n");
            emittedDone = true;
          }
          return true;
        }
        if (converted) {
          if (!yielded) {
            beginSSEStreamResponse(res);
            yielded = true;
          }
          attemptMeta.receivedCompletion = true;
          res.write(`data: ${converted}\n\n`);
          return true;
        }
        return false;
      };

      for (const model of chain) {
        if (yielded) break;
        const remainingMs = streamDeadlineAt - Date.now();
        if (shouldYieldFreeSlotToPaidFallback(model, chain, remainingMs)) {
          console.warn(
            `Skipping free stream model ${model}; reserving ${remainingMs}ms for paid SLA fallback`
          );
          continue;
        }
        if (remainingMs < 5000) break;
        if (!isFreeModelId(model)) {
          attemptMeta.attemptedPaid = true;
          console.warn(`OpenRouter free stream chain exhausted; falling back to SLA model ${model}`);
        }
        const perCallTimeout = Math.min(streamTimeoutMs, remainingMs);
        const attempt = geminiBodyToOpenAI(body, { streaming: true, model });
        for (const apiKey of keys) {
          if (yielded) break;
          const keyRemainingMs = streamDeadlineAt - Date.now();
          if (keyRemainingMs < 3000) break;
          try {
            const resp = await fetch(OPENROUTER_URL, {
              method: "POST",
              headers: openRouterHeaders(apiKey),
              body: JSON.stringify(attempt),
              signal: AbortSignal.timeout(Math.min(perCallTimeout, keyRemainingMs)),
            });
            if (!resp.ok || !resp.body) {
              const errText = await resp.text();
              lastError = new Error(
                `stream ${resp.status} ${model}: ${errText.slice(0, 300)}`
              );
              logUpstreamModelFailure(model, resp.status, errText);
              if (!shouldTryNextKeyForError(resp.status, errText)) break;
              continue;
            }

            const reader = resp.body.getReader();
            const decoder = new TextDecoder();
            let buffer = "";
            for (;;) {
              const { done, value } = await reader.read();
              if (done) break;
              buffer += decoder.decode(value, { stream: true });
              const lines = buffer.split("\n");
              buffer = lines.pop() || "";
              for (const rawLine of lines) {
                emitStreamLine(rawLine);
              }
            }
            buffer += decoder.decode();
            if (buffer.trim()) {
              emitStreamLine(buffer);
            }
            if (!yielded) {
              lastError = new Error(`Empty stream completion from ${model}`);
              console.warn(lastError.message);
              break;
            }
            break;
          } catch (e) {
            lastError = e;
            console.warn(`Stream attempt failed on ${model}:`, e?.message || e);
            if (yielded) throw e;
            break;
          }
        }
      }

      if (!yielded) {
        throw lastError || new Error("All streaming models failed");
      }
      finishSSEStreamResponse(res, { yielded, emittedDone });
    } catch (e) {
      if (
        shouldRefundQuotaSlot({
          yielded,
          receivedCompletion: attemptMeta.receivedCompletion,
          attemptedPaid: attemptMeta.attemptedPaid,
        })
      ) {
        await refundReservedSlots();
      }
      console.error("foodAiProxy OpenRouter error:", e);
      if (!res.headersSent) {
        res.status(502).json({
          error: "upstream_failed",
          message: sanitizeUpstreamErrorMessage(e?.message || e, "ai"),
        });
      } else {
        res.write(`data: ${JSON.stringify({ error: "stream_interrupted" })}\n\ndata: [DONE]\n\n`);
        res.end();
      }
    }
  }
);

async function callFatSecretOAuth1({
  consumerKey,
  consumerSecret,
  method,
  extraParams,
  timeoutMs = FATSECRET_TIMEOUT_MS,
}) {
  const url = buildOAuth1FatSecretURL({
    consumerKey,
    consumerSecret,
    method,
    extraParams,
  });
  const resp = await fetch(url, {
    signal: AbortSignal.timeout(timeoutMs),
  });
  const text = await resp.text();
  if (!resp.ok) {
    throw new Error(`FatSecret OAuth1 ${resp.status}: ${text.slice(0, 200)}`);
  }
  return JSON.parse(text);
}

async function fetchFatSecretWithRetry({
  url,
  clientId,
  clientSecret,
  timeoutMs = FATSECRET_TIMEOUT_MS,
}) {
  for (let attempt = 0; attempt < 2; attempt++) {
    const token = await getFatSecretAccessToken({
      clientId,
      clientSecret,
      forceRefresh: attempt > 0,
      timeoutMs,
    });
    const resp = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
      signal: AbortSignal.timeout(timeoutMs),
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
    const uid = await verifyFirebaseUser(
      req,
      res,
      (token, checkRevoked) => getAuth().verifyIdToken(token, checkRevoked),
      ENDPOINT_AUTH_OPTIONS.foodSearchProxy
    );
    if (!uid) return;

    let parsed;
    try {
      parsed = parseSearchPayload(req.body);
    } catch (e) {
      res.status(400).json({ error: e.message });
      return;
    }

    const searchDeviceHash = resolveSecondaryQuotaKey(req);
    const searchIpHash = resolveIpQuotaKey(req);
    const userSearchLimit = resolveUserQuotaLimit(
      DEFAULT_SEARCH_WEEKLY_LIMIT,
      req._authSignInProvider,
      "search"
    );
    const deviceSearchLimit = resolveDeviceQuotaLimit(
      DEFAULT_SEARCH_WEEKLY_LIMIT,
      req._authSignInProvider,
      "search"
    );
    let searchReservedWindows;
    try {
      searchReservedWindows = await reserveDualRateLimitSlots({
        userCollection: "food_search_usage",
        deviceCollection: "food_search_device_usage",
        uid,
        deviceHash: searchDeviceHash,
        ipHash: searchIpHash,
        userLimit: userSearchLimit,
        deviceLimit: deviceSearchLimit,
        ipLimit: DEFAULT_SEARCH_WEEKLY_LIMIT * 8,
      });
    } catch (e) {
      if (e instanceof RateLimitError) {
        res.set("Retry-After", String(e.retryAfterSeconds));
        res.status(429).json({
          error: "search_limit_reached",
          message: "Weekly food search limit reached. Please try again later.",
          retryAfter: e.retryAfterSeconds,
        });
        return;
      }
      console.error("Search rate limit reservation failed:", e);
      res.status(500).json({ error: "Rate limit check failed" });
      return;
    }

    const refundSearchSlots = async () => {
      await refundRateLimitSlot("food_search_usage", uid, searchReservedWindows.userWindowStart);
      if (searchDeviceHash) {
        await refundRateLimitSlot(
          "food_search_device_usage",
          searchDeviceHash,
          searchReservedWindows.deviceWindowStart
        );
      }
      if (searchIpHash && searchIpHash !== searchDeviceHash && searchReservedWindows.ipWindowStart !== null) {
        await refundRateLimitSlot(
          "food_search_device_usage",
          searchIpHash,
          searchReservedWindows.ipWindowStart
        );
      }
    };

    const clientId = fatSecretClientId.value().trim();
    const clientSecret = fatSecretClientSecret.value().trim();
    if (!clientId || !clientSecret) {
      await refundSearchSlots();
      res.status(500).json({ error: "FatSecret credentials not configured" });
      return;
    }

    const searchDeadlineAt = Date.now() + FATSECRET_TOTAL_BUDGET_MS;
    const boundedFatSecretTimeout = () =>
      Math.min(FATSECRET_TIMEOUT_MS, Math.max(2000, searchDeadlineAt - Date.now()));

    try {
      if (parsed.mode === "search") {
        if (fatSecretAuthModeCache !== "oauth2") {
          const oauth1Data = await callFatSecretOAuth1({
            consumerKey: clientId,
            consumerSecret: clientSecret,
            method: "foods.search",
            extraParams: {
              search_expression: parsed.query,
              max_results: String(parsed.maxResults),
            },
            timeoutMs: boundedFatSecretTimeout(),
          });
          if (!oauth1Data?.error) {
            fatSecretAuthModeCache = "oauth1";
            res.status(200).json({ items: normalizeFatSecretSearch(oauth1Data) });
            return;
          }
          const errCode = Number(oauth1Data.error?.code);
          if (errCode !== 2 && errCode !== 8) {
            throw new Error(`FatSecret error ${errCode}: ${oauth1Data.error?.message}`);
          }
          fatSecretAuthModeCache = "oauth2";
        }
        const url =
          `${FATSECRET_API_BASE}/foods/search/v1?search_expression=${encodeURIComponent(
            parsed.query
          )}&format=json&max_results=${parsed.maxResults}`;
        const data = await fetchFatSecretWithRetry({
          url,
          clientId,
          clientSecret,
          timeoutMs: boundedFatSecretTimeout(),
        });
        assertFatSecretResponseSuccess(data);
        res.status(200).json({ items: normalizeFatSecretSearch(data) });
        return;
      }

      const normalizedBarcode = normalizeFatSecretBarcodeInput(parsed.barcode);
      if (fatSecretAuthModeCache !== "oauth2") {
        const oauth1Barcode = await callFatSecretOAuth1({
          consumerKey: clientId,
          consumerSecret: clientSecret,
          method: "food.find_id_for_barcode",
          extraParams: { barcode: normalizedBarcode },
          timeoutMs: boundedFatSecretTimeout(),
        });
        if (!oauth1Barcode?.error) {
          fatSecretAuthModeCache = "oauth1";
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
            timeoutMs: boundedFatSecretTimeout(),
          });
          assertFatSecretDetailSuccess(detail);
          res.status(200).json({ item: normalizeFatSecretBarcode(detail) });
          return;
        }
        const bCode = Number(oauth1Barcode.error?.code);
        if (bCode === 10) {
          fatSecretAuthModeCache = "oauth1";
          // Basic OAuth 1.0 plan has no barcode method; return null cleanly so OFF/AI proceed.
          res.status(200).json({ item: null });
          return;
        }
        if (bCode !== 2 && bCode !== 8) {
          throw new Error(`FatSecret barcode error ${bCode}: ${oauth1Barcode.error?.message}`);
        }
        fatSecretAuthModeCache = "oauth2";
      }

      const url =
        `${FATSECRET_API_BASE}/food/barcode/find-by-id/v2?barcode=${encodeURIComponent(
          normalizedBarcode
        )}&format=json`;
      const data = await fetchFatSecretWithRetry({
        url,
        clientId,
        clientSecret,
        timeoutMs: boundedFatSecretTimeout(),
      });
      assertFatSecretResponseSuccess(data);
      res.status(200).json({ item: normalizeFatSecretBarcode(data) });
    } catch (e) {
      await refundSearchSlots();
      console.error("foodSearchProxy error:", e?.message || e);
      res.status(502).json({
        error: "fatsecret_upstream_failed",
        message: sanitizeUpstreamErrorMessage(e?.message || e, "search"),
      });
    }
  }
);

async function deleteRefRecursively(firestore, ref) {
  if (typeof firestore.recursiveDelete === "function") {
    await firestore.recursiveDelete(ref);
    return;
  }
  await ref.delete();
}

async function deleteFoodAccountData({ uid, firestore = getFirestore(), auth = getAuth() }) {
  // Remove all per-user docs across the shared serzhanovich-ecosystem-ce700 project
  // before deleting the shared Firebase Auth UID so WorkoutTracker data is never orphaned.
  const sharedSnap = await firestore
    .collection("shared_workouts")
    .where("creatorUid", "==", uid)
    .get();
  for (const sharedDoc of sharedSnap.docs) {
    await deleteRefRecursively(firestore, sharedDoc.ref);
  }

  const reportsSnap = await firestore
    .collection("reports")
    .where("reporterUid", "==", uid)
    .get();
  const reportRefs = reportsSnap.docs.map((d) => d.ref);
  for (let i = 0; i < reportRefs.length; i += 450) {
    const batch = firestore.batch();
    reportRefs.slice(i, i + 450).forEach((ref) => batch.delete(ref));
    await batch.commit();
  }

  await deleteRefRecursively(firestore, firestore.collection("users").doc(uid));

  await Promise.all([
    firestore.collection("food_ai_usage").doc(uid).delete(),
    firestore.collection("food_search_usage").doc(uid).delete(),
    firestore.collection("ai_usage").doc(uid).delete(),
  ]);
  try {
    await auth.deleteUser(uid);
  } catch (err) {
    if (err?.code !== "auth/user-not-found") {
      throw err;
    }
  }
}

exports.foodDeleteAccount = onRequest(
  {
    region: "us-central1",
    serviceAccount: SERVICE_ACCOUNT,
    memory: "512MiB",
    timeoutSeconds: 120,
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }
    if (!(await verifyAppCheck(req, res))) return;
    const uid = await verifyFirebaseUser(
      req,
      res,
      (token, checkRevoked) => getAuth().verifyIdToken(token, checkRevoked),
      ENDPOINT_AUTH_OPTIONS.foodDeleteAccount
    );
    if (!uid) return;

    try {
      await deleteFoodAccountData({ uid });
      res.status(200).json({ ok: true });
    } catch (e) {
      console.error("foodDeleteAccount error:", e?.message || e);
      res.status(500).json({ error: "Failed to delete server data" });
    }
  }
);

function beginSSEStreamResponse(res) {
  res
    .status(200)
    .set("Content-Type", "text/event-stream")
    .set("Cache-Control", "no-cache, no-transform")
    .set("Connection", "keep-alive")
    .set("X-Accel-Buffering", "no");
  if (typeof res.flushHeaders === "function") {
    res.flushHeaders();
  }
}

function finishSSEStreamResponse(res, { yielded = true, emittedDone = false } = {}) {
  if (yielded && !emittedDone) {
    res.write("data: [DONE]\n\n");
  }
  res.end();
}

module.exports._test = {
  TEXT_MODEL_CHAIN,
  VISION_MODEL_CHAIN,
  PAID_TEXT_FALLBACK_MODELS,
  PAID_VISION_FALLBACK_MODELS,
  STRUCTURED_MODELS,
  JSON_OBJECT_MODELS,
  parseApiKeys,
  shouldTryNextKeyForError,
  hasImageContent,
  upstreamTimeoutForBody,
  computeRateLimitTransition,
  validateAiProxyBody,
  sanitizeUpstreamErrorMessage,
  resolveIpQuotaKey,
  resolveSecondaryQuotaKey,
  modelChainForRequest,
  resolveAllowPaidFallback,
  shouldRefundQuotaSlot,
  shouldYieldFreeSlotToPaidFallback,
  PAID_FALLBACK_RESERVE_MS,
  geminiBodyToOpenAI,
  stripModelJSON,
  openAIToGeminiResponse,
  openAIStreamChunkToGemini,
  callOpenRouterText,
  parseNumericValue,
  convertMetricWeightToGrams,
  pickPreferredFatSecretServing,
  isTokenValid,
  buildOAuth1FatSecretURL,
  parseFatSecretDescription,
  normalizeFatSecretFood,
  normalizeFatSecretSearch,
  normalizeFatSecretBarcode,
  normalizeFatSecretBarcodeInput,
  assertFatSecretDetailSuccess,
  assertFatSecretResponseSuccess,
  parseSearchPayload,
  deleteFoodAccountData,
  verifyAppCheck,
  verifyFirebaseUser,
  ENDPOINT_AUTH_OPTIONS,
  sanitizeModelOverrides,
  resolveUserQuotaLimit,
  resolveDeviceQuotaLimit,
  isMeaningfulJsonOutput,
  beginSSEStreamResponse,
  finishSSEStreamResponse,
};
