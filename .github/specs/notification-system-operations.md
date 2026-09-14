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

## Database Migrations

Apply these in the Supabase SQL Editor as the database owner, in this order:

1. `20260914_web_push_notifications.sql`
2. `20260914_register_push_subscription.sql`
3. `20260914_push_delivery_access.sql`
4. `20260914_deadline_reminders.sql`
5. `20260914_unregister_push_subscription.sql`

The last migration is currently the remaining database step for the browser-specific Disable notifications action. The other notification migrations have been applied and the test push path has been verified.

Check the notification tables after applying the migrations:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'notification_settings',
    'push_subscriptions',
    'notification_deliveries'
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

## Notification Types

- `event_created`: a new Booking or Practice is created.
- `deadline_reminder`: a configured number of days remains before an event response deadline.
- `event_status_changed`: an event changes status, such as `Go` or `No-go`.
- `rsvp_changed`: an RSVP response changes, including a Maybe comment where applicable.
- `event_details_changed`: event date, location, description, or response deadline changes.

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

### C. Immediate event notifications

1. As a Leader, create a Practice and a Booking; subscribed test members should receive `event_created` notifications.
2. Change an event status to `Go`, then `No-go`; subscribed recipients should receive `event_status_changed` notifications.
3. Edit the date, location, description, or response deadline; recipients should receive `event_details_changed` notifications.
4. As a Member, change an RSVP to Attending, Maybe, and Not Attending; Leaders/Admins should receive `rsvp_changed` notifications.
5. Verify that an event or RSVP write still succeeds if push delivery is unavailable.

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
