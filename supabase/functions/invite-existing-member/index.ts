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

  // The resolveAdminKey function has been moved to a shared module.

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const secretKeys = Deno.env.get("SUPABASE_SECRET_KEYS");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const adminKey = resolveAdminKey(secretKeys, serviceRoleKey);
  if (!authorization?.startsWith("Bearer ") || !supabaseUrl || !adminKey) {
    return json({ error: "Invalid function configuration or session" }, 401);
  }

  const adminClient = createClient(supabaseUrl, adminKey);
  const accessToken = authorization.replace("Bearer ", "");
  const { data: caller, error: callerError } = await adminClient.auth.getUser(accessToken);
  if (callerError || !caller.user) return json({ error: "Invalid session" }, 401);

  const { data: callerByAuthId, error: callerByAuthIdError } = await adminClient
    .from("team_members")
    .select("is_admin")
    .eq("auth_user_id", caller.user.id)
    .maybeSingle();
  const { data: callerByProfileId, error: callerByProfileIdError } = await adminClient
    .from("team_members")
    .select("is_admin")
    .eq("id", caller.user.id)
    .maybeSingle();
  const { data: callerByEmail, error: callerByEmailError } = caller.user.email
    ? await adminClient
        .from("team_members")
        .select("is_admin")
        .eq("email", caller.user.email)
        .maybeSingle()
    : { data: null };
  const isAdmin =
    callerByAuthId?.is_admin === true ||
    callerByProfileId?.is_admin === true ||
    callerByEmail?.is_admin === true;
  if (!isAdmin) {
    return json({
      error: "Admin access required",
      auth_user_id: caller.user.id,
      auth_email: caller.user.email ?? null,
      matched_by_auth_user_id: callerByAuthId != null,
      matched_by_profile_id: callerByProfileId != null,
      matched_by_email: callerByEmail != null,
      auth_id_query_error: callerByAuthIdError?.message ?? null,
      profile_id_query_error: callerByProfileIdError?.message ?? null,
      email_query_error: callerByEmailError?.message ?? null,
      function_project: supabaseUrl,
    }, 403);
  }

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

  const { error: updateError } = await adminClient.rpc(
    "record_member_invitation",
    {
      p_member_id: memberId,
      p_auth_user_id: invitation.user.id,
      p_invited_at: new Date().toISOString(),
    },
  );

  if (updateError) {
    await adminClient.auth.admin.deleteUser(invitation.user.id);
    return json({ error: updateError.message }, 400);
  }

  return json({ member_id: memberId, auth_user_id: invitation.user.id });
});
