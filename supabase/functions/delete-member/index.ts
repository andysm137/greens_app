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
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "Missing authorization" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "The function is not configured" }, 500);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const accessToken = authorization.replace("Bearer ", "");
  const { data: caller, error: callerError } = await adminClient.auth.getUser(
    accessToken,
  );

  if (callerError || !caller.user) {
    return json({ error: "Invalid session" }, 401);
  }

  const { data: callerProfile, error: profileError } = await adminClient
    .from("team_members")
    .select("is_admin")
    .eq("id", caller.user.id)
    .single();

  if (profileError || callerProfile?.is_admin !== true) {
    return json({ error: "Admin access required" }, 403);
  }

  const body = await request.json();
  const memberId = typeof body.member_id === "string"
    ? body.member_id.trim()
    : "";

  if (!memberId) {
    return json({ error: "Member ID is required" }, 400);
  }

  if (memberId === caller.user.id) {
    return json({ error: "You cannot delete your own account" }, 400);
  }

  const { error: musicianError } = await adminClient
    .from("musician_profiles")
    .delete()
    .eq("member_id", memberId);

  if (musicianError) {
    return json({ error: musicianError.message }, 400);
  }

  const { error: memberError } = await adminClient
    .from("team_members")
    .delete()
    .eq("id", memberId);

  if (memberError) {
    return json({ error: memberError.message }, 400);
  }

  const { error: authError } = await adminClient.auth.admin.deleteUser(memberId);
  if (authError) {
    return json({
      error: "Profile deleted, but the Auth account could not be deleted: " +
        authError.message,
    }, 500);
  }

  return json({ deleted_user_id: memberId });
});