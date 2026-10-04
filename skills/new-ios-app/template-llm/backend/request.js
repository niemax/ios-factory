import { MAX_INPUT_CHARS, MAX_MESSAGES } from "./limits.js";

export function httpError(status, message) {
  return Object.assign(new Error(message), { status });
}

// Validates the client's body: { provider, model?, system?, messages: [{ role, content }] }.
export function parseRequest(body, providerNames) {
  const { provider, model, system, messages } = body ?? {};
  if (!providerNames.includes(provider)) throw httpError(400, `provider must be one of: ${providerNames.join(", ")}`);
  if (model !== undefined && typeof model !== "string") throw httpError(400, "model must be a string");
  if (system !== undefined && typeof system !== "string") throw httpError(400, "system must be a string");
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > MAX_MESSAGES) {
    throw httpError(400, `messages must hold 1–${MAX_MESSAGES} items`);
  }
  for (const message of messages) {
    if (!["user", "assistant"].includes(message?.role) || typeof message.content !== "string") {
      throw httpError(400, "each message needs role user|assistant and string content");
    }
  }
  const inputChars = (system ?? "").length + messages.reduce((sum, message) => sum + message.content.length, 0);
  if (inputChars > MAX_INPUT_CHARS) throw httpError(413, "input too long");
  return { provider, model, system, messages };
}

export async function requireUid(req, verifyIdToken) {
  const match = (req.get("authorization") || "").match(/^Bearer (.+)$/);
  if (!match) throw httpError(401, "unauthenticated");
  try {
    return (await verifyIdToken(match[1])).uid;
  } catch {
    throw httpError(401, "unauthenticated");
  }
}
