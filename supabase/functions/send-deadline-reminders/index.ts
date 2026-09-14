import webpush from "npm:web-push@3.6.7";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { resolveAdminKey } from "../_shared/admin_key.ts";

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const configuredCronSecret = Deno.env.get("CRON_SECRET");
  const suppliedCronSecret = request.headers.get("x-cron-secret");
  if (!configuredCronSecret || suppliedCronSecret !== configuredCronSecret) {
    return json({ error: "Scheduled access required" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceKey = resolveAdminKey(
    Deno.env.get("SUPABASE_SECRET_KEYS"),
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
  );
  const publicKey = Deno.env.get("VAPID_PUBLIC_KEY");
  const privateKey = Deno.env.get("VAPID_PRIVATE_KEY");
  if (!supabaseUrl || !serviceKey || !publicKey || !privateKey) {
    return json({ error: "Reminder delivery is not configured" }, 503);
  }

  const client = createClient(supabaseUrl, serviceKey);
  const { data: settings } = await client.rpc(
    "get_notification_setting_for_delivery",
    { p_notification_type: "deadline_reminder" },
  );
  const setting = settings?.[0];
  if (setting?.is_enabled !== true) return json({ sent: 0, disabled: true });

  const reminderDays = (setting.reminder_days as number[] | null) ?? [];
  if (reminderDays.length === 0) return json({ sent: 0 });

  const today = new Date();
  const dateText = today.toISOString().slice(0, 10);
  const { data: events, error: eventsError } = await client
    .from("events")
    .select("id, title, response_deadline")
    .in("status", ["Pending", "Go"])
    .not("response_deadline", "is", null);
  if (eventsError) return json({ error: eventsError.message }, 400);

  webpush.setVapidDetails(
    Deno.env.get("VAPID_SUBJECT") ?? "mailto:admin@example.com",
    publicKey,
    privateKey,
  );
  let sent = 0;

  for (const event of events ?? []) {
    const deadline = event.response_deadline as string;
    const daysRemaining = Math.round(
      (Date.parse(`${deadline}T00:00:00Z`) - Date.parse(`${dateText}T00:00:00Z`)) /
        86400000,
    );
    if (!reminderDays.includes(daysRemaining)) continue;

    const { data: responses } = await client
      .from("event_rsvps")
      .select("member_id")
      .eq("event_id", event.id);
    const responded = new Set((responses ?? []).map((row) => row.member_id as string));
    const { data: members } = await client.from("team_members").select("id");

    for (const member of members ?? []) {
      const memberId = member.id as string;
      if (responded.has(memberId)) continue;

      const { data: claim, error: claimError } = await client
        .from("notification_deliveries")
        .insert({
          notification_type: "deadline_reminder",
          event_id: event.id,
          member_id: memberId,
          days_before_deadline: daysRemaining,
        })
        .select("id")
        .maybeSingle();
      if (claimError || !claim) continue;

      const { data: subscriptions } = await client.rpc(
        "get_push_subscriptions_for_delivery",
        { p_member_id: memberId },
      );
      const sentAt = new Date().toLocaleString("en-GB", {
        timeZone: "UTC",
        hour12: false,
      });
      const body = `${setting.message_template?.trim() ||
        `${event.title} needs your response in ${daysRemaining} day${daysRemaining === 1 ? "" : "s"}.`}\nSent: ${sentAt} UTC`;
      await client.rpc("insert_notification_for_delivery", {
        p_member_id: memberId,
        p_notification_type: "deadline_reminder",
        p_title: "Response deadline",
        p_body: body,
        p_event_id: event.id,
      });
      for (const subscription of subscriptions ?? []) {
        try {
          await webpush.sendNotification({
            endpoint: subscription.endpoint,
            keys: { p256dh: subscription.p256dh, auth: subscription.auth },
          }, JSON.stringify({
            title: "Response deadline",
            body,
            url: "../",
          }));
          sent++;
        } catch (error) {
          const statusCode = (error as { statusCode?: number }).statusCode;
          if (statusCode === 404 || statusCode === 410) {
            await client.rpc("delete_push_subscription_for_delivery", {
              p_subscription_id: subscription.id,
            });
          }
        }
      }
      await client.from("notification_deliveries").update({ sent_at: new Date().toISOString() }).eq("id", claim.id);
    }
  }
  return json({ sent });
});