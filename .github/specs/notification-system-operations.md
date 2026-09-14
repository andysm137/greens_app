# Notification System Operations

Updated: 2026-09-14

This guide explains how to configure, deploy, and use the Silkstone Greens Web Push notification system from the Admin, Leader, and Member perspectives.

## Current Architecture

- Flutter web requests browser notification permission and registers a scoped push service worker at `push/`.
- Browser subscriptions are stored in `push_subscriptions`.
- Notification settings, enablement, reminder days, and template overrides are stored in `notification_settings`.
- VAPID keys are Supabase Edge Function secrets and must never be stored in Flutter, SQL migrations, Git, or chat.
- `push-configuration` returns the public VAPID key to authenticated clients.
- `register-push-subscription` resolves the signed-in member server-side and registers the browser subscription.
- `send-push-notification` sends immediate notifications and applies the Admin enablement/template settings.
- `send-deadline-reminders` sends scheduled deadline reminders and uses `notification_deliveries` to prevent duplicates.
- `notifications` stores a lightweight in-app inbox with read/unread state; the bell displays its unread count.

## Database Migrations

Apply these in the Supabase SQL Editor as the database owner, in this order:

1. `20260914_web_push_notifications.sql`
2. `20260914_register_push_subscription.sql`
3. `20260914_push_delivery_access.sql`
4. `20260914_deadline_reminders.sql`
5. `20260914_unregister_push_subscription.sql`
6. `20260914_notifications_inbox.sql`
7. `20260914_notification_delivery_settings.sql`
8. `20260914_notification_inbox_delivery_access.sql`
9. `20260914_event_notification_access.sql`
10. `20260914_notifications_clear.sql`
11. `20260914_notifications_clear_privileges.sql`
12. `20260914_event_notification_context_date.sql`
13. `20260914_competency_notification_setting.sql`
14. `20260914_notification_coalescing.sql`
15. `20260914_notification_coalescing_1min.sql`

All listed notification migrations have now been applied and the test push path has been verified.

The delivery-settings migration is applied; deployed senders read Admin notification settings through the server-only RPC.

The inbox-delivery migration is applied; deployed senders insert unread inbox records through their server-only RPC for both immediate and scheduled deliveries.

The event-notification access and event-date context migrations are applied, allowing deployed senders to resolve event titles, dates, RSVP member names, and server-side recipients without relying on direct table RLS reads.

The notifications-clear migration and follow-up DELETE privilege migration are applied. Members can remove only their own inbox records through the RLS policy.

Check the notification tables after applying the migrations:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'notification_settings',
    'push_subscriptions',
    'notification_deliveries',
    'notifications'
  )
order by table_name;
```

## Edge Function Deployment

Deploy from the project root:

```powershell
supabase functions deploy push-configuration --project-ref xzvawbevrlatfshsgnum
supabase functions deploy register-push-subscription --project-ref xzvawbevrlatfshsgnum
supabase functions deploy send-push-notification --project-ref xzvawbevrlatfshsgnum
supabase functions deploy send-deadline-reminders --project-ref xzvawbevrlatfshsgnum
```

This Supabase CLI version does not support `supabase functions invoke`. Use the Supabase Dashboard or the SQL `pg_net` request below for manual reminder testing.

## VAPID Secrets

The following secrets must exist in the hosted Supabase project:

```text
VAPID_PUBLIC_KEY
VAPID_PRIVATE_KEY
VAPID_SUBJECT
```

`VAPID_PRIVATE_KEY` must remain secret. `VAPID_SUBJECT` should be a monitored contact, for example `mailto:admin@example.com`.

The browser test notification has already been verified after configuring these secrets.

## Scheduled Reminder Secret

The reminder function uses a dedicated `CRON_SECRET` rather than the service-role key.

Configure the same randomly generated value in both places:

- Supabase Edge Function secret: `CRON_SECRET`
- Supabase Vault secret: `deadline_reminder_cron_secret`

Do not use the service-role key for the scheduled request. If the previous service-role-based cron secret exists, remove it after removing the old cron job. Rotate `CRON_SECRET` if it has been exposed.

## Supabase Cron Setup

Enable the installed extensions if needed:

```sql
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;
```

Vault is exposed by Supabase as the `supabase_vault` extension and its SQL objects use the `vault` schema. Add the Vault secret through the Supabase Dashboard Vault Secrets tab. Do not put the secret value in this file or in a migration.

Create the daily job after confirming the Vault secret exists:

```sql
select cron.schedule(
  'send-deadline-reminders-daily',
  '0 8 * * *',
  $$
  select net.http_post(
    url := 'https://xzvawbevrlatfshsgnum.supabase.co/functions/v1/send-deadline-reminders',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret',
      (
        select decrypted_secret
        from vault.decrypted_secrets
        where name = 'deadline_reminder_cron_secret'
      )
    ),
    body := '{}'::jsonb
  );
  $$
);
```

The schedule above runs at 08:00 UTC. Confirm it exists:

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname = 'send-deadline-reminders-daily';
```

To remove an old or duplicate job:

```sql
select cron.unschedule(jobid)
from cron.job
where jobname = 'send-deadline-reminders-daily';
```

## Manual Reminder Test

Use SQL Editor to invoke the deployed function without exposing the cron secret:

```sql
select net.http_post(
  url := 'https://xzvawbevrlatfshsgnum.supabase.co/functions/v1/send-deadline-reminders',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'x-cron-secret',
    (
      select decrypted_secret
      from vault.decrypted_secrets
      where name = 'deadline_reminder_cron_secret'
    )
  ),
  body := '{}'::jsonb
);
```

A result of `sent: 0` is normal when no event deadline matches an Admin-configured reminder offset on the current date.

## Admin Workflow

1. Sign in with an account whose `team_members.is_admin` value is `true`.
2. Open **Admin** and select the **Notifications** tab.
3. Select a notification row to edit it.
4. Use **Enabled** to turn that notification type on or off.
5. For **Response deadline reminder**, enter lead times such as `3, 1`.
6. Optionally enter a message-template override. Leave it blank to use the standard server message.
7. Save the setting.
8. Use the paper-plane test icon on the row to send that notification type to the Admin's currently subscribed browser.

Expected test behavior:

- Enabled setting with no override: standard server text is delivered.
- Enabled setting with an override: the override text is delivered.
- Disabled setting: delivery is suppressed and the UI reports that no test was sent.
- No active browser subscription: the UI reports that no subscribed browser was found.

Admin settings never contain VAPID private keys or browser encryption keys.

## Leader Workflow

Leaders can create and edit events and manage event attendance according to the event-date, status, and response-deadline rules.

Immediate notifications are generated server-side after these successful actions:

- Event created.
- Event status changed.
- Event details changed.
- RSVP changed.

Leaders do not configure notification settings, access VAPID secrets, or choose arbitrary recipient lists. The sender selects recipients server-side.

Leaders should verify that their browser subscription is enabled with the top-bar notification control if they need to receive operational notifications.

## Member Workflow

1. Sign in as a normal team member.
2. Select the top-bar notification bell.
3. Grant browser permission when prompted.
4. The browser subscription is stored against the authenticated member profile.
5. A server-generated test notification confirms delivery.

Members can receive enabled event and deadline notifications but cannot edit Admin settings or other members' subscriptions.

The top-bar disable control removes notifications for the current browser only. It does not remove subscriptions from other browsers or devices for the same member.

The same bell opens the recent in-app notification list. Unread items are highlighted and can be marked individually or all at once.

Selecting a notification with an event reference marks it read and opens the Events workspace with that event expanded. RSVP notifications show the event, member, and From/New values; they are delivered only to Leaders and Admins.

The Events workspace separates `Booking` and `Practice` items into tabs, each sorted by event date. Event-linked notifications select the matching tab before expanding the linked event, so notification navigation remains valid regardless of the event type.

## Notification Types

- `event_created`: a new Booking or Practice is created.
- `deadline_reminder`: a configured number of days remains before an event response deadline.
- `event_status_changed`: an event changes status, such as `Go` or `No-go`.
- `rsvp_changed`: an RSVP response changes, including a Maybe comment where applicable.
- `event_details_changed`: event date, location, description, or response deadline changes.
- `competency_updated`: a member changes their own Skill Matrix competency; delivered to Leaders/Admins only, with the dance, position, and old/new proficiency level.

All delivered notification bodies include a trailing `Sent: <date time> UTC` line.

Rapid repeat changes to the same `(member, type, event, related member)` within a 1-minute window are coalesced into the existing unread inbox row instead of sending another push; only the first in a burst triggers an actual push. This applies to every notification type except `test` — RSVP changes, event status/details changes, event creation, deadline reminders, and competency updates are all covered, keyed per recipient.

Immediate event dispatch is implemented. Scheduled deadline dispatch requires the daily cron job described above.

## Testing Regimen

Run this smoke test after deployment changes and before releasing a new PWA build. Use separate browser profiles or test accounts for Admin, Leader, and Member roles.

### A. Subscription and device lifecycle

1. Sign in as a Member in Browser A and enable notifications.
2. Confirm the browser permission prompt appears only on the first enable attempt.
3. Confirm the test notification is received.
4. Sign in as the same Member in Browser B and enable notifications; confirm both browser subscriptions can exist.
5. Disable notifications in Browser A; confirm Browser B remains subscribed.
6. Enable Browser A again and confirm it can subscribe again.
7. Confirm a Member cannot read or modify another member's subscription through the API.

### B. Admin notification settings

1. Sign in as an Admin and open **Admin -> Notifications**.
2. Send a test for each notification type with the default message; confirm delivery.
3. Disable one notification type and send its test; confirm the UI reports suppression and no push arrives.
4. Re-enable it, enter a distinctive template override, save, send a test, and confirm the override text arrives.
5. Clear the override, save, and confirm the standard server text returns.
6. Sign in as a Leader and Member; confirm neither can edit settings or send Admin tests.
7. Toggle `Competency updated`; confirm the row is available in Admin Notifications and that its enabled/disabled state is respected by the sender.

### C. Immediate event notifications

1. As a Leader, create a Practice and a Booking; subscribed test members should receive `event_created` notifications.
2. Change an event status to `Go`, then `No-go`; subscribed recipients should receive `event_status_changed` notifications.
3. Edit the date, location, description, or response deadline; recipients should receive `event_details_changed` notifications.
4. As a Member, change an RSVP to Attending, Maybe, and Not Attending; Leaders/Admins should receive `rsvp_changed` notifications.
5. Verify that an event or RSVP write still succeeds if push delivery is unavailable.
6. Open an event-linked notification for both a Booking and a Practice; confirm the correct Events tab opens and the event expands.

### D. Scheduled deadline reminders

1. In Admin Notifications, enable `deadline_reminder` and set a short test offset, such as `1` day.
2. Create a test event whose response deadline is exactly one UTC day ahead.
3. Ensure the test Member has a subscription and no RSVP for that event.
4. Invoke the reminder endpoint through the SQL `pg_net` request or wait for the daily cron run.
5. Confirm the Member receives one reminder and a row appears in `notification_deliveries` with `sent_at` set.
6. Invoke the reminder again; confirm no duplicate notification is sent because of the unique delivery key.
7. Add an RSVP and invoke again; confirm the responded Member is skipped.
8. Disable `deadline_reminder`; confirm no reminder is sent even when a deadline matches.

### E. Failure and security checks

- Confirm expired browser subscriptions are removed after a Web Push 404/410 response.
- Confirm a missing or incorrect `x-cron-secret` returns HTTP 401.
- Confirm VAPID private keys and cron secrets never appear in Flutter logs, SQL files, Git history, or browser-visible payloads.
- Confirm notification payloads contain only intended title, body, and navigation URL data.
- Record the notification type, event, recipient, result, and timestamp for any failed test.

## Troubleshooting

### Browser permission works but subscription fails

Refresh the browser after changes to `web/index.html` or the push service worker. Confirm the scoped worker at `push/` is active and that the deployed VAPID public key matches the VAPID private key configured in Supabase.

### `permission denied for table push_subscriptions`

Confirm both `20260914_register_push_subscription.sql` and `20260914_push_delivery_access.sql` were applied. The Flutter client must call `register_push_subscription`; it should not write directly to `push_subscriptions`.

### Reminder request returns 401

Confirm the function secret `CRON_SECRET` matches the Vault secret `deadline_reminder_cron_secret`. Do not use a service-role key as the cron header.

### Reminder request returns `sent: 0`

Check that:

- `deadline_reminder` is enabled in Admin Notifications.
- `reminder_days` contains the intended offset.
- The event has a response deadline.
- The event deadline is the configured number of days from the current UTC date.
- The member has not already submitted an RSVP.
- The member has an active browser subscription.

### Supabase CLI does not support `functions invoke`

That is expected for the installed CLI version. Use the SQL `pg_net` manual request or the Supabase Dashboard instead.
