-- Apply as the database owner after the existing role-access migrations.
-- VAPID keys remain Supabase Edge Function secrets and are never stored here.

CREATE TABLE IF NOT EXISTS public.notification_settings (
  notification_type TEXT PRIMARY KEY,
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  reminder_days INTEGER[] NOT NULL DEFAULT '{}',
  message_template TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.push_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL,
  endpoint TEXT NOT NULL UNIQUE,
  p256dh TEXT NOT NULL,
  auth TEXT NOT NULL,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_subscriptions ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.notification_settings,
  public.push_subscriptions TO authenticated;

CREATE POLICY "Admins manage notification settings"
ON public.notification_settings FOR ALL TO authenticated
USING (public.current_member_is_admin())
WITH CHECK (public.current_member_is_admin());

CREATE POLICY "Members manage own push subscriptions"
ON public.push_subscriptions FOR ALL TO authenticated
USING (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
)
WITH CHECK (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
);

INSERT INTO public.notification_settings (
  notification_type, is_enabled, reminder_days, message_template
) VALUES
  ('event_created', TRUE, '{}', NULL),
  ('deadline_reminder', TRUE, '{3,1}', NULL),
  ('event_status_changed', TRUE, '{}', NULL),
  ('rsvp_changed', TRUE, '{}', NULL),
  ('event_details_changed', TRUE, '{}', NULL)
ON CONFLICT (notification_type) DO NOTHING;