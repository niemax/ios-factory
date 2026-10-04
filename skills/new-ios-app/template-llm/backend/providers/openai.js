import { defineSecret } from "firebase-functions/params";
import { MAX_OUTPUT_TOKENS } from "../limits.js";
import { postJSON } from "./upstream.js";

export const secret = defineSecret("OPENAI_API_KEY");
// ponytail: default model goes stale; check platform.openai.com/docs/models when scaffolding.
const DEFAULT_MODEL = "gpt-5-mini";

export async function complete({ model, system, messages }) {
  const json = await postJSON(
    "https://api.openai.com/v1/chat/completions",
    { authorization: `Bearer ${secret.value()}` },
    {
      model: model ?? DEFAULT_MODEL,
      max_completion_tokens: MAX_OUTPUT_TOKENS,
      messages: system ? [{ role: "system", content: system }, ...messages] : messages,
    }
  );
  return json.choices?.[0]?.message?.content ?? "";
}
