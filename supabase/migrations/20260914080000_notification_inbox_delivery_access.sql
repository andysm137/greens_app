-- Server-only inbox insertion for deployed notification senders.

CREATE OR REPLACE FUNCTION public.insert_notification_for_delivery(
  p_member_id UUID,
  p_notification_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_event_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO public.notifications (
    member_id, notification_type, title, body, event_id
  ) VALUES (
    p_member_id, p_notification_type, p_title, p_body, p_event_id
  );
$$;

REVOKE ALL ON FUNCTION public.insert_notification_for_delivery(
  UUID, TEXT, TEXT, TEXT, UUID
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.insert_notification_for_delivery(
  UUID, TEXT, TEXT, TEXT, UUID
) TO service_role;