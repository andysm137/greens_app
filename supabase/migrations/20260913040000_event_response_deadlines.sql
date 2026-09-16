-- Apply after 20260913_harden_role_access.sql.
-- Adds RSVP response deadlines and comments, then protects RSVP changes by
-- event date, event status, and deadline at the database boundary.

ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS response_deadline DATE;

ALTER TABLE public.event_rsvps
  ADD COLUMN IF NOT EXISTS comment TEXT;

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
    );
$$;

REVOKE ALL ON FUNCTION public.current_member_can_manage_event_rsvp(UUID, UUID)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_member_can_manage_event_rsvp(UUID, UUID)
  TO authenticated;

DROP POLICY IF EXISTS "Members manage own RSVP" ON public.event_rsvps;
DROP POLICY IF EXISTS "Leaders and admins manage RSVPs" ON public.event_rsvps;

CREATE POLICY "Event RSVP changes respect date and deadline"
ON public.event_rsvps FOR ALL TO authenticated
USING (public.current_member_can_manage_event_rsvp(event_id, member_id))
WITH CHECK (public.current_member_can_manage_event_rsvp(event_id, member_id));