import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { resolveAdminKey } from "../_shared/admin_key.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const adminKey = resolveAdminKey(
    Deno.env.get("SUPABASE_SECRET_KEYS"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  );
  if (!authorization?.startsWith("Bearer ") || !supabaseUrl || !adminKey) {
    return json({ error: "Invalid function configuration or session" }, 401);
  }

  const client = createClient(supabaseUrl, adminKey);
  const { data: authData, error: authError } = await client.auth.getUser(
    authorization.replace("Bearer ", ""),
  );
  if (authError || !authData.user) return json({ error: "Invalid session" }, 401);

  const body = await request.json();
  const endpoint = typeof body.endpoint === "string" ? body.endpoint : "";
  const p256dh = typeof body.p256dh === "string" ? body.p256dh : "";
  const auth = typeof body.auth === "string" ? body.auth : "";
  if (!endpoint || !p256dh || !auth) {
    return json({ error: "A complete browser push subscription is required" }, 400);
  }

  const profileQuery = client
    .from("team_members")
    .select("id")
    .or(`id.eq.${authData.user.id},auth_user_id.eq.${authData.user.id}`);
  const { data: matchedProfiles } = await profileQuery;
  const profile = matchedProfiles?.[0] ?? (authData.user.email
    ? (await client
        .from("team_members")
        .select("id")
        .eq("email", authData.user.email)
        .maybeSingle()).data
    : null);
  if (!profile) return json({ error: "Team profile not found" }, 403);

  const { error } = await client.from("push_subscriptions").upsert({
    member_id: profile.id,
    endpoint,
    p256dh,
    auth,
    user_agent: "Flutter web",
    updated_at: new Date().toISOString(),
  }, { onConflict: "endpoint" });
  if (error) return json({ error: error.message }, 400);
  return json({ member_id: profile.id });
});