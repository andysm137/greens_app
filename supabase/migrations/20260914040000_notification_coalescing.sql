-- Coalesces rapid repeat notifications (e.g. a member toggling RSVP several
-- times in a row) into the same still-unread inbox row instead of spamming
-- a fresh push/notification for every change.

DROP FUNCTION IF EXISTS public.insert_notification_for_delivery(UUID, TEXT, TEXT, TEXT, UUID, UUID, TEXT);

CREATE OR REPLACE FUNCTION public.insert_notification_for_delivery(
  p_member_id UUID,
  p_notification_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_event_id UUID DEFAULT NULL,
  p_related_member_id UUID DEFAULT NULL,
  p_dance_name TEXT DEFAULT NULL
)
-- Returns TRUE when a push should be sent (new notification, or the previous
-- one has already been read/expired); FALSE when coalesced into an existing
-- still-unread notification for the same (member, type, event, related member).
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_id UUID;
  v_cooldown INTERVAL := INTERVAL '5 minutes';
BEGIN
  IF p_notification_type <> 'test' THEN
    SELECT id INTO v_existing_id
    FROM public.notifications
    WHERE member_id = p_member_id
      AND notification_type = p_notification_type
      AND event_id IS NOT DISTINCT FROM p_event_id
      AND related_member_id IS NOT DISTINCT FROM p_related_member_id
      AND read_at IS NULL
      AND created_at > NOW() - v_cooldown
    ORDER BY created_at DESC
    LIMIT 1;
  END IF;

  IF v_existing_id IS NOT NULL THEN
    UPDATE public.notifications
    SET title = p_title,
        body = p_body,
        dance_name = p_dance_name,
        created_at = NOW()
    WHERE id = v_existing_id;
    RETURN FALSE;
  END IF;

  INSERT INTO public.notifications (
    member_id, notification_type, title, body, event_id, related_member_id, dance_name
  ) VALUES (
    p_member_id, p_notification_type, p_title, p_body, p_event_id, p_related_member_id, p_dance_name
  );
  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.insert_notification_for_delivery(
  UUID, TEXT, TEXT, TEXT, UUID, UUID, TEXT
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.insert_notification_for_delivery(
  UUID, TEXT, TEXT, TEXT, UUID, UUID, TEXT
) TO service_role;
