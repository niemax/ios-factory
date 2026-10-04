import { defineSecret } from "firebase-functions/params";
import { MAX_OUTPUT_TOKENS } from "../limits.js";
import { postJSON } from "./upstream.js";

export const secret = defineSecret("GEMINI_API_KEY");
const DEFAULT_MODEL = "gemini-flash-latest";

export async function complete({ model, system, messages }) {
  const json = await postJSON(
    `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model ?? DEFAULT_MODEL)}:generateContent`,
    { "x-goog-api-key": secret.value() },
    {
      ...(system && { systemInstruction: { parts: [{ text: system }] } }),
      contents: messages.map((message) => ({
        role: message.role === "assistant" ? "model" : "user",
        parts: [{ text: message.content }],
      })),
      generationConfig: { maxOutputTokens: MAX_OUTPUT_TOKENS },
    }
  );
  return (json.candidates?.[0]?.content?.parts ?? []).map((part) => part.text ?? "").join("");
}
