-- Shortens the notification coalescing cooldown from 5 minutes to 1 minute.

CREATE OR REPLACE FUNCTION public.insert_notification_for_delivery(
  p_member_id UUID,
  p_notification_type TEXT,
  p_title TEXT,
  p_body TEXT,
  p_event_id UUID DEFAULT NULL,
  p_related_member_id UUID DEFAULT NULL,
  p_dance_name TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_id UUID;
  v_cooldown INTERVAL := INTERVAL '1 minute';
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
