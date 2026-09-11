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

  const body = await request.json();
  const memberId = typeof body.member_id === "string" ? body.member_id.trim() : "";
  if (!memberId) return json({ error: "Member ID is required" }, 400);

  const { data: member, error: memberError } = await adminClient
    .from("team_members")
    .select("id, full_name, email, auth_user_id")
    .eq("id", memberId)
    .single();
  if (memberError || !member) return json({ error: "Member profile not found" }, 404);
  if (!member.email) return json({ error: "This member has no email address" }, 400);
  if (member.auth_user_id) return json({ error: "This member has already been invited" }, 400);

  const { data: invitation, error: invitationError } =
    await adminClient.auth.admin.inviteUserByEmail(member.email);
  if (invitationError || !invitation.user) {
    return json({ error: invitationError?.message ?? "Unable to send invitation" }, 400);
  }

  const { error: updateError } = await adminClient
    .from("team_members")
    .update({ auth_user_id: invitation.user.id, invited_at: new Date().toISOString() })
    .eq("id", memberId);

  if (updateError) {
    await adminClient.auth.admin.deleteUser(invitation.user.id);
    return json({ error: updateError.message }, 400);
  }

  return json({ member_id: memberId, auth_user_id: invitation.user.id });
});
