import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!authorization?.startsWith("Bearer ") || !supabaseUrl || !serviceRoleKey) {
    return json({ error: "Invalid function configuration or session" }, 401);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const accessToken = authorization.replace("Bearer ", "");
  const { data: caller, error: callerError } = await adminClient.auth.getUser(accessToken);
  if (callerError || !caller.user) return json({ error: "Invalid session" }, 401);

  const { data: callerProfile } = await adminClient
    .from("team_members")
    .select("is_admin")
    .or(`id.eq.${caller.user.id},auth_user_id.eq.${caller.user.id}`)
    .single();
  if (callerProfile?.is_admin !== true) return json({ error: "Admin access required" }, 403);

  const { data: members, error: membersError } = await adminClient
    .from("team_members")
    .select("id, auth_user_id, invited_at, registered_at");
  if (membersError) return json({ error: membersError.message }, 400);

  const statuses: Record<string, string> = {};
  for (const member of members ?? []) {
    if (!member.auth_user_id) {
      statuses[member.id] = "notInvited";
      continue;
    }

    const { data: authUser } = await adminClient.auth.admin.getUserById(member.auth_user_id);
    const registered = Boolean(authUser.user?.email_confirmed_at || authUser.user?.last_sign_in_at);
    if (registered && !member.registered_at) {
      await adminClient
        .from("team_members")
        .update({ registered_at: new Date().toISOString() })
        .eq("id", member.id);
    }
    statuses[member.id] = registered ? "registered" : "inviteSent";
  }

  return json({ statuses });
});
