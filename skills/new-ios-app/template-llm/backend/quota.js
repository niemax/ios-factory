import { DAILY_REQUEST_LIMIT } from "./limits.js";
import { httpError } from "./request.js";

// One doc per uid; the day rolls over in UTC. Firestore rules deny clients
// everything outside users/{uid}, so only this function (admin SDK) writes it.
// ponytail: anonymous auth mints new uids freely; enforce App Check before launch.
export async function spendDailyQuota(db, uid) {
  const ref = db.collection("llmUsage").doc(uid);
  const today = new Date().toISOString().slice(0, 10);
  await db.runTransaction(async (transaction) => {
    const usage = (await transaction.get(ref)).data();
    const count = usage?.day === today ? usage.count : 0;
    if (count >= DAILY_REQUEST_LIMIT) throw httpError(429, "daily limit reached");
    transaction.set(ref, { day: today, count: count + 1 });
  });
}
