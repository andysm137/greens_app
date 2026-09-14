import webpush from "npm:web-push@3.6.7";
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

const standardMessages: Record<string, { title: string; body: string }> = {
  event_created: { title: "New event", body: "A new Silkstone Greens event has been added." },
  deadline_reminder: { title: "Response deadline", body: "An event response deadline is approaching." },
  event_status_changed: { title: "Event status updated", body: "An event status has changed." },
  rsvp_changed: { title: "RSVP updated", body: "An RSVP response has changed." },
  event_details_changed: { title: "Event updated", body: "An event's details have changed." },
  test: { title: "Notifications enabled", body: "Silkstone Greens notifications are working on this browser." },
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authorization = request.headers.get("Authorization");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const adminKey = resolveAdminKey(
    Deno.env.get("SUPABASE_SECRET_KEYS"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  );
  const publicKey = Deno.env.get("VAPID_PUBLIC_KEY");
  const privateKey = Deno.env.get("VAPID_PRIVATE_KEY");
  const subject = Deno.env.get("VAPID_SUBJECT") ?? "mailto:admin@example.com";
  if (!authorization?.startsWith("Bearer ") || !supabaseUrl || !adminKey || !publicKey || !privateKey) {
    return json({ error: "Push notifications are not configured" }, 503);
  }

  const client = createClient(supabaseUrl, adminKey);
  const { data: authData, error: authError } = await client.auth.getUser(authorization.replace("Bearer ", ""));
  if (authError || !authData.user) return json({ error: "Invalid session" }, 401);

  const body = await request.json();
  const notificationType = typeof body.notification_type === "string" ? body.notification_type : "";
  const requestedTargetMemberId = typeof body.target_member_id === "string" ? body.target_member_id : "";
  const eventId = typeof body.event_id === "string" ? body.event_id : "";
  if (!standardMessages[notificationType]) {
    return json({ error: "A supported notification type is required" }, 400);
  }

  const { data: callers } = await client
    .from("team_members")
    .select("id, is_leader, is_admin")
    .or(`id.eq.${authData.user.id},auth_user_id.eq.${authData.user.id}`);
  const caller = callers?.[0] ?? (authData.user.email
    ? (await client
        .from("team_members")
        .select("id, is_leader, is_admin")
        .eq("email", authData.user.email)
        .maybeSingle()).data
    : null);
  if (!caller) return json({ error: "Team profile not found" }, 403);
  if (notificationType !== "test" && notificationType !== "rsvp_changed" && !caller.is_leader && !caller.is_admin) {
    return json({ error: "Leader or admin access required" }, 403);
  }
  if (notificationType === "test" && requestedTargetMemberId && caller.id !== requestedTargetMemberId) {
    return json({ error: "Test notifications can only be sent to your own devices" }, 403);
  }

  if (eventId) {
    const { data: event } = await client
      .from("events")
      .select("id")
      .eq("id", eventId)
      .maybeSingle();
    if (!event) return json({ error: "Event not found" }, 404);
  }

  const { data: setting } = await client
    .from("notification_settings")
    .select("is_enabled, message_template")
    .eq("notification_type", notificationType)
    .maybeSingle();
  if (notificationType !== "test" && setting?.is_enabled !== true) {
    return json({ delivered: 0, disabled: true });
  }

  const message = standardMessages[notificationType];
  const notificationBody = setting?.message_template?.trim() || message.body;
  const payload = JSON.stringify({
    title: message.title,
    body: notificationBody,
    url: "../",
  });
  let targetMemberIds = requestedTargetMemberId ? [requestedTargetMemberId] : [caller.id];
  if (eventId) {
    const { data: recipients } = notificationType === "rsvp_changed"
      ? await client.from("team_members").select("id").or("is_leader.eq.true,is_admin.eq.true")
      : await client.from("team_members").select("id");
    targetMemberIds = (recipients ?? []).map((recipient) => recipient.id as string);
  }

  const subscriptions = [] as Array<{ id: string; endpoint: string; p256dh: string; auth: string }>;
  for (const targetMemberId of targetMemberIds) {
    await client.from("notifications").insert({
      member_id: targetMemberId,
      notification_type: notificationType,
      title: message.title,
      body: notificationBody,
      event_id: eventId || null,
    });
    const { data: memberSubscriptions, error: subscriptionsError } = await client.rpc(
      "get_push_subscriptions_for_delivery",
      { p_member_id: targetMemberId },
    );
    if (subscriptionsError) return json({ error: subscriptionsError.message }, 400);
    subscriptions.push(...(memberSubscriptions ?? []));
  }

  webpush.setVapidDetails(subject, publicKey, privateKey);
  let delivered = 0;
  for (const subscription of subscriptions ?? []) {
    try {
      await webpush.sendNotification({
        endpoint: subscription.endpoint,
        keys: { p256dh: subscription.p256dh, auth: subscription.auth },
      }, payload);
      delivered++;
    } catch (error) {
      const statusCode = (error as { statusCode?: number }).statusCode;
      if (statusCode === 404 || statusCode === 410) {
        await client.rpc("delete_push_subscription_for_delivery", {
          p_subscription_id: subscription.id,
        });
      }
    }
  }
  return json({ delivered });
});