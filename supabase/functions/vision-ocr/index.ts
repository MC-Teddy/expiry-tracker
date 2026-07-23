// Supabase Edge Function: vision-ocr
// ---------------------------------------------------------------------------
// Server-side proxy for Google Cloud Vision so the API key never ships to the
// browser. Only authenticated users can call it. The key lives in a Supabase
// secret (GOOGLE_VISION_KEY), set once by the admin:
//   supabase secrets set GOOGLE_VISION_KEY=AIza...
// Deploy:
//   supabase functions deploy vision-ocr
// (or paste this file in the dashboard → Edge Functions → new function
//  named exactly "vision-ocr").
//
// Request  body: { image: "<base64 jpeg, no data: prefix>" }
// Response body: { ok: true, text: "..." }  |  { ok: false, error: "..." }
// ---------------------------------------------------------------------------
import { createClient } from "jsr:@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const visionKey = Deno.env.get("GOOGLE_VISION_KEY");
    const authHeader = req.headers.get("Authorization") ?? "";

    // Require a signed-in user (any role).
    const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } } });
    const { data: { user } } = await caller.auth.getUser();
    if (!user) return json({ ok: false, error: "Not authenticated" });
    if (!visionKey) return json({ ok: false, error: "Cloud OCR not configured" });

    const { image } = await req.json().catch(() => ({}));
    if (!image) return json({ ok: false, error: "No image provided" });

    const r = await fetch(
      "https://vision.googleapis.com/v1/images:annotate?key=" + visionKey,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          requests: [{ image: { content: image }, features: [{ type: "TEXT_DETECTION" }] }],
        }),
      },
    );
    if (!r.ok) return json({ ok: false, error: "vision-http-" + r.status });
    const j = await r.json();
    const err = j?.responses?.[0]?.error;
    if (err) return json({ ok: false, error: err.message || "vision-error" });
    const text = j?.responses?.[0]?.fullTextAnnotation?.text ?? "";
    return json({ ok: true, text });
  } catch (e) {
    return json({ ok: false, error: String((e as Error)?.message ?? e) });
  }
});
