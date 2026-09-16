-- Persistent lightweight inbox backing the unread badge and notification list.

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  member_id UUID NOT NULL,
  notification_type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  event_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  read_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS notifications_member_unread_idx
  ON public.notifications (member_id, read_at, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
GRANT SELECT, UPDATE ON public.notifications TO authenticated;

CREATE POLICY "Members read own notifications"
ON public.notifications FOR SELECT TO authenticated
USING (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
);

CREATE POLICY "Members mark own notifications read"
ON public.notifications FOR UPDATE TO authenticated
USING (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
)
WITH CHECK (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
);

REVOKE INSERT, DELETE ON public.notifications FROM anon, authenticated;