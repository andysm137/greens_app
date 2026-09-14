-- Adds competency-change context to the notification inbox so a tap can
-- deep-link to the affected dancer/dance in the Skills Matrix.

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS related_member_id UUID,
  ADD COLUMN IF NOT EXISTS dance_name TEXT;

DROP FUNCTION IF EXISTS public.insert_notification_for_delivery(UUID, TEXT, TEXT, TEXT, UUID);

CREATE OR REPLACE FUNCTION public.insert_notification_for_delivery(
  p_member_id UUID,
  p_notification_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_event_id UUID DEFAULT NULL,
  p_related_member_id UUID DEFAULT NULL,
  p_dance_name TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO public.notifications (
    member_id, notification_type, title, body, event_id, related_member_id, dance_name
  ) VALUES (
    p_member_id, p_notification_type, p_title, p_body, p_event_id, p_related_member_id, p_dance_name
  );
$$;

REVOKE ALL ON FUNCTION public.insert_notification_for_delivery(
  UUID, TEXT, TEXT, TEXT, UUID, UUID, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.insert_notification_for_delivery(
  UUID, TEXT, TEXT, TEXT, UUID, UUID, TEXT
) TO service_role;
