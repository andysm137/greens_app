-- Extend the server-only event context used by notification delivery.

DROP FUNCTION IF EXISTS public.get_event_notification_context(UUID, UUID);

CREATE FUNCTION public.get_event_notification_context(
  p_event_id UUID,
  p_member_id UUID DEFAULT NULL
)
RETURNS TABLE (event_title TEXT, event_date TIMESTAMPTZ, member_name TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    event.title,
    event.event_date,
    member.full_name
  FROM public.events AS event
  LEFT JOIN public.team_members AS member ON member.id = p_member_id
  WHERE event.id = p_event_id;
$$;

REVOKE ALL ON FUNCTION public.get_event_notification_context(UUID, UUID)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_event_notification_context(UUID, UUID)
  TO service_role;