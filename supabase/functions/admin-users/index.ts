// Supabase Edge Function: admin-users
// ---------------------------------------------------------------------------
// Server-side user management for the Expiry Tracker. The service-role key
// (full DB access) lives ONLY here — never in the browser. Every call is
// verified: the caller must be signed in AND have app_metadata.role === 'admin'.
// Created users are always non-admin (app_metadata.role = 'user').
//
// Deploy (Supabase dashboard → Edge Functions → Deploy a new function, name it
// exactly "admin-users", paste this file), or via CLI:
//   supabase functions deploy admin-users
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are injected
// automatically — no secrets to configure.
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
    const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const authHeader = req.headers.get("Authorization") ?? "";

    // 1. Identify the caller from their JWT.
    const caller = createClient(url, anon, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: { user }, error: uErr } = await caller.auth.getUser();
    if (uErr || !user) return json({ ok: false, error: "Not authenticated" });

    // 2. Gate on admin role (app_metadata is server-controlled, so it's trustworthy).
    if (user.app_metadata?.role !== "admin") {
      return json({ ok: false, error: "Admins only" });
    }

    // 3. Privileged client (bypasses RLS) — used ONLY after the admin check above.
    const admin = createClient(url, service, { auth: { persistSession: false } });
    const { action, email, password, id } = await req.json().catch(() => ({}));

    if (action === "list") {
      const { data, error } = await admin.auth.admin.listUsers();
      if (error) return json({ ok: false, error: error.message });
      const users = data.users.map((u) => ({
        id: u.id,
        email: u.email,
        role: (u.app_metadata?.role as string) ?? "user",
        created_at: u.created_at,
      }));
      return json({ ok: true, users });
    }

    if (action === "create") {
      if (!email || !password || String(password).length < 6) {
        return json({ ok: false, error: "Email and a 6+ char password are required" });
      }
      const { data, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,                 // usable immediately, no email step
        app_metadata: { role: "user" },      // never admin
      });
      if (error) return json({ ok: false, error: error.message });
      return json({ ok: true, user: { id: data.user.id, email: data.user.email } });
    }

    if (action === "delete") {
      if (!id) return json({ ok: false, error: "User id is required" });
      if (id === user.id) return json({ ok: false, error: "You cannot delete your own account" });
      const { error } = await admin.auth.admin.deleteUser(id);
      if (error) return json({ ok: false, error: error.message });
      return json({ ok: true });
    }

    return json({ ok: false, error: "Unknown action" });
  } catch (e) {
    return json({ ok: false, error: String((e as Error)?.message ?? e) });
  }
});
