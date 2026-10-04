import { defineSecret } from "firebase-functions/params";
import { MAX_OUTPUT_TOKENS } from "../limits.js";
import { postJSON } from "./upstream.js";

export const secret = defineSecret("ANTHROPIC_API_KEY");
// ponytail: default model goes stale; check docs.claude.com/en/docs/about-claude/models when scaffolding.
const DEFAULT_MODEL = "claude-sonnet-5-5";

export async function complete({ model, system, messages }) {
  const json = await postJSON(
    "https://api.anthropic.com/v1/messages",
    { "x-api-key": secret.value(), "anthropic-version": "2023-06-01" },
    { model: model ?? DEFAULT_MODEL, max_tokens: MAX_OUTPUT_TOKENS, ...(system && { system }), messages }
  );
  return (json.content ?? []).filter((block) => block.type === "text").map((block) => block.text).join("");
}
