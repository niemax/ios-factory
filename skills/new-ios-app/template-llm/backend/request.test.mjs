import assert from "node:assert/strict";
import { test } from "node:test";
import { parseRequest, requireUid } from "./request.js";

const names = ["openai", "anthropic"];
const ok = { provider: "openai", messages: [{ role: "user", content: "hi" }] };

test("accepts a minimal request", () => {
  assert.deepEqual(parseRequest(ok, names), { ...ok, model: undefined, system: undefined });
});

test("rejects unknown provider, bad roles, empty and oversized input", () => {
  const status = (body) => {
    try { parseRequest(body, names); } catch (error) { return error.status; }
  };
  assert.equal(status({ ...ok, provider: "gemini" }), 400);
  assert.equal(status({ ...ok, messages: [] }), 400);
  assert.equal(status({ ...ok, messages: [{ role: "system", content: "x" }] }), 400);
  assert.equal(status({ ...ok, messages: [{ role: "user", content: "x".repeat(20_001) }] }), 413);
  assert.equal(status(undefined), 400);
});

test("requireUid needs a valid bearer token", async () => {
  const req = (header) => ({ get: () => header });
  const verify = async (token) => {
    if (token !== "good") throw new Error("bad");
    return { uid: "u1" };
  };
  assert.equal(await requireUid(req("Bearer good"), verify), "u1");
  await assert.rejects(requireUid(req("Bearer bad"), verify), { status: 401 });
  await assert.rejects(requireUid(req(undefined), verify), { status: 401 });
});
