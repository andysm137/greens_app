-- Apply after the notification tables and delivery-access RPCs.
-- The unique key prevents duplicate reminders for the same event/member/day.

CREATE TABLE IF NOT EXISTS public.notification_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_type TEXT NOT NULL,
  event_id UUID NOT NULL,
  member_id UUID NOT NULL,
  days_before_deadline INTEGER NOT NULL,
  sent_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_notification_delivery
    UNIQUE (notification_type, event_id, member_id, days_before_deadline)
);

ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.notification_deliveries FROM anon, authenticated;

-- Scheduling note:
-- Generate a random CRON_SECRET and set it as an Edge Function secret.
-- Store the same value in Supabase Vault as deadline_reminder_cron_secret.
-- The cron job reads that Vault secret and sends it in the x-cron-secret header.
-- Do not use the service-role key for scheduled calls.