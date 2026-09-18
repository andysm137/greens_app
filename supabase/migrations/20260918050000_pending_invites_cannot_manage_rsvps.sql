CREATE OR REPLACE FUNCTION public.current_member_can_manage_event_rsvp(
  p_event_id UUID,
  p_member_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT
    public.current_member_is_registered()
    AND (
      public.current_member_is_admin()
      OR EXISTS (
        SELECT 1
        FROM public.events
        WHERE id = p_event_id
          AND event_date::date >= current_date
          AND (
            public.current_member_is_leader_or_admin()
            OR (
              status <> 'Go'
              AND (response_deadline IS NULL OR response_deadline >= current_date)
              AND (
                p_member_id = auth.uid()
                OR p_member_id IN (
                  SELECT id
                  FROM public.team_members
                  WHERE auth_user_id = auth.uid()
                )
              )
            )
          )
      )
    );
$$;

REVOKE ALL ON FUNCTION public.current_member_can_manage_event_rsvp(UUID, UUID)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_member_can_manage_event_rsvp(UUID, UUID)
  TO authenticated;