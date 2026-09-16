-- Server-only context and recipient access for immediate event notifications.

CREATE OR REPLACE FUNCTION public.get_event_notification_context(
  p_event_id UUID,
  p_member_id UUID DEFAULT NULL
)
RETURNS TABLE (event_title TEXT, member_name TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    event.title,
    member.full_name
  FROM public.events AS event
  LEFT JOIN public.team_members AS member ON member.id = p_member_id
  WHERE event.id = p_event_id;
$$;

CREATE OR REPLACE FUNCTION public.get_event_notification_recipients(
  p_leaders_only BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (member_id UUID)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id
  FROM public.team_members
  WHERE NOT p_leaders_only OR is_leader = TRUE OR is_admin = TRUE;
$$;

REVOKE ALL ON FUNCTION public.get_event_notification_context(UUID, UUID)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_event_notification_recipients(BOOLEAN)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_event_notification_context(UUID, UUID)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.get_event_notification_recipients(BOOLEAN)
  TO service_role;