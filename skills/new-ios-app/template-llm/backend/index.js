import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { REGION } from "./limits.js";
import * as providers from "./providers/index.js";
import { spendDailyQuota } from "./quota.js";
import { httpError, parseRequest, requireUid } from "./request.js";

initializeApp();

// POST /llm with `Authorization: Bearer <Firebase ID token>`. Returns { text }.
export const llm = onRequest(
  { region: REGION, timeoutSeconds: 120, secrets: Object.values(providers).map((provider) => provider.secret) },
  async (req, res) => {
    try {
      if (req.method !== "POST") throw httpError(405, "POST only");
      const uid = await requireUid(req, (token) => getAuth().verifyIdToken(token));
      const { provider, model, system, messages } = parseRequest(req.body, Object.keys(providers));
      await spendDailyQuota(getFirestore(), uid);
      const text = await providers[provider].complete({ model, system, messages });
      res.json({ text });
    } catch (error) {
      const status = error.status ?? 500;
      if (status >= 500) console.error(error);
      res.status(status).json({ error: status >= 500 ? "upstream error" : error.message });
    }
  }
);
