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

  const accessToken = authorization.replace("Bearer ", "");
  const adminClient = createClient(supabaseUrl, serviceRoleKey);
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
  const email = typeof body.email === "string" ? body.email.trim() : "";
  const fullName = typeof body.full_name === "string" ? body.full_name.trim() : "";
  const phone = typeof body.phone === "string" ? body.phone.trim() : "";
  const isLeader = body.is_leader === true;
  const isAdmin = body.is_admin === true;
  const instruments = typeof body.instruments === "string"
    ? body.instruments.trim()
    : "";

  if (!email || !fullName) {
    return json({ error: "Full name and email are required" }, 400);
  }

  const { data: invitation, error: invitationError } = await adminClient.auth.admin.inviteUserByEmail(email);
  if (invitationError || !invitation.user) {
    return json({ error: invitationError?.message ?? "Unable to send invitation" }, 400);
  }

  const { error: memberError } = await adminClient.from("team_members").insert({
    id: invitation.user.id,
    auth_user_id: invitation.user.id,
    full_name: fullName,
    email,
    phone: phone || null,
    is_leader: isLeader,
    is_admin: isAdmin,
    instruments: instruments || null,
    invited_at: new Date().toISOString(),
  });

  if (memberError) {
    await adminClient.auth.admin.deleteUser(invitation.user.id);
    return json({ error: memberError.message }, 400);
  }

  const instrumentNames = instruments
    .split(",")
    .map((instrument) => instrument.trim())
    .filter((instrument) => instrument.length > 0);

  if (instrumentNames.length > 0) {
    const { error: musicianError } = await adminClient
      .from("musician_profiles")
      .insert(instrumentNames.map((primaryInstrument) => ({
        member_id: invitation.user!.id,
        primary_instrument: primaryInstrument,
      })));

    if (musicianError) {
      return json({ error: musicianError.message }, 400);
    }
  }

  return json({ user_id: invitation.user.id });
});
