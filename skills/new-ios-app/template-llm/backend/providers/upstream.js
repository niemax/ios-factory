import { httpError } from "../request.js";

// Provider HTTP call; any non-2xx becomes a 502 so provider details never reach the client.
export async function postJSON(url, headers, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error(`upstream ${response.status}`, JSON.stringify(json).slice(0, 500));
    throw httpError(502, "upstream error");
  }
  return json;
}
