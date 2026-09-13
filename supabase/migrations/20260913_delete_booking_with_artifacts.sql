-- Apply after 20260913_harden_role_access.sql.
-- Booking tables intentionally have no foreign keys, so deletion must remove
-- dependent records before the parent event in one database transaction.

CREATE OR REPLACE FUNCTION public.delete_event_with_artifacts(
  p_event_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.current_member_is_admin() THEN
    RAISE EXCEPTION 'Admin access required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.events
    WHERE id = p_event_id
  ) THEN
    RAISE EXCEPTION 'Event not found';
  END IF;

  DELETE FROM public.event_rsvps WHERE event_id = p_event_id;
  DELETE FROM public.booking_dance_assignments WHERE booking_id = p_event_id;
  DELETE FROM public.booking_dance_settings WHERE booking_id = p_event_id;
  DELETE FROM public.booking_set_layouts WHERE booking_id = p_event_id;
  DELETE FROM public.events WHERE id = p_event_id;
END;
$$;

REVOKE ALL ON FUNCTION public.delete_event_with_artifacts(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_event_with_artifacts(UUID)
  TO authenticated;

DROP POLICY IF EXISTS "Leaders and admins manage events" ON public.events;

CREATE POLICY "Leaders and admins create events"
ON public.events FOR INSERT TO authenticated
WITH CHECK (public.current_member_is_leader_or_admin());

CREATE POLICY "Leaders and admins update events"
ON public.events FOR UPDATE TO authenticated
USING (public.current_member_is_leader_or_admin())
WITH CHECK (public.current_member_is_leader_or_admin());