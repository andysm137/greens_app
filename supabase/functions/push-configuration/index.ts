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
  const vapidPublicKey = Deno.env.get("VAPID_PUBLIC_KEY");
  if (!authorization?.startsWith("Bearer ") || !supabaseUrl || !adminKey) {
    return json({ error: "Invalid function configuration or session" }, 401);
  }
  if (!vapidPublicKey) return json({ error: "Push notifications are not configured" }, 503);

  const client = createClient(supabaseUrl, adminKey);
  const { data, error } = await client.auth.getUser(authorization.replace("Bearer ", ""));
  if (error || !data.user) return json({ error: "Invalid session" }, 401);
  return json({ vapid_public_key: vapidPublicKey });
});