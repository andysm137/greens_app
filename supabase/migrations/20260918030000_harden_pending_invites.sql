CREATE OR REPLACE FUNCTION public.current_member_is_registered()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.team_members
    WHERE (id = auth.uid() OR auth_user_id = auth.uid())
      AND (registered_at IS NOT NULL OR invited_at IS NULL)
  );
$$;

CREATE OR REPLACE FUNCTION public.current_member_is_leader_or_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.team_members
    WHERE (id = auth.uid() OR auth_user_id = auth.uid())
      AND (registered_at IS NOT NULL OR invited_at IS NULL)
      AND (is_leader = TRUE OR is_admin = TRUE)
  );
$$;

CREATE OR REPLACE FUNCTION public.current_member_is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.team_members
    WHERE (id = auth.uid() OR auth_user_id = auth.uid())
      AND (registered_at IS NOT NULL OR invited_at IS NULL)
      AND is_admin = TRUE
  );
$$;

CREATE OR REPLACE FUNCTION public.booking_is_leader_or_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT public.current_member_is_leader_or_admin();
$$;

REVOKE ALL ON FUNCTION public.current_member_is_registered() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_member_is_leader_or_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_member_is_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.booking_is_leader_or_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_member_is_registered() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_member_is_leader_or_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_member_is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.booking_is_leader_or_admin() TO authenticated;

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

DROP POLICY IF EXISTS "Authenticated users can read team members" ON public.team_members;
CREATE POLICY "Registered users can read team members"
ON public.team_members FOR SELECT TO authenticated
USING (
  public.current_member_is_registered()
  OR id = auth.uid()
  OR auth_user_id = auth.uid()
);

DROP POLICY IF EXISTS "Authenticated users can read events" ON public.events;
CREATE POLICY "Registered users can read events"
ON public.events FOR SELECT TO authenticated
USING (public.current_member_is_registered());

DROP POLICY IF EXISTS "Authenticated users can read RSVPs" ON public.event_rsvps;
CREATE POLICY "Registered users can read RSVPs"
ON public.event_rsvps FOR SELECT TO authenticated
USING (public.current_member_is_registered());

DROP POLICY IF EXISTS "Authenticated users can read dance catalog" ON public.dance_catalog;
CREATE POLICY "Registered users can read dance catalog"
ON public.dance_catalog FOR SELECT TO authenticated
USING (public.current_member_is_registered());

DROP POLICY IF EXISTS "Authenticated users can read musician profiles" ON public.musician_profiles;
CREATE POLICY "Registered users can read musician profiles"
ON public.musician_profiles FOR SELECT TO authenticated
USING (public.current_member_is_registered());

DROP POLICY IF EXISTS "Authenticated users can read booking assignments" ON public.booking_dance_assignments;
CREATE POLICY "Registered users can read booking assignments"
ON public.booking_dance_assignments FOR SELECT TO authenticated
USING (public.current_member_is_registered());

DROP POLICY IF EXISTS "Authenticated users can read booking dance settings" ON public.booking_dance_settings;
CREATE POLICY "Registered users can read booking dance settings"
ON public.booking_dance_settings FOR SELECT TO authenticated
USING (public.current_member_is_registered());

DROP POLICY IF EXISTS "Authenticated users can read display settings" ON public.app_display_settings;
CREATE POLICY "Registered users can read display settings"
ON public.app_display_settings FOR SELECT TO authenticated
USING (public.current_member_is_registered());

DROP POLICY IF EXISTS "Members can read own competencies" ON public.competencies;
CREATE POLICY "Registered members can read own competencies"
ON public.competencies FOR SELECT TO authenticated
USING (
  public.current_member_is_registered()
  AND (member_id = auth.uid() OR member_id IN (
    SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
  ))
);

DROP POLICY IF EXISTS "Members can update own competencies" ON public.competencies;
CREATE POLICY "Registered members can update own competencies"
ON public.competencies FOR UPDATE TO authenticated
USING (
  public.current_member_is_registered()
  AND (member_id = auth.uid() OR member_id IN (
    SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
  ))
)
WITH CHECK (
  public.current_member_is_registered()
  AND (member_id = auth.uid() OR member_id IN (
    SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
  ))
);

DROP POLICY IF EXISTS "Members can insert own competencies" ON public.competencies;
CREATE POLICY "Registered members can insert own competencies"
ON public.competencies FOR INSERT TO authenticated
WITH CHECK (
  public.current_member_is_registered()
  AND (member_id = auth.uid() OR member_id IN (
    SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
  ))
);

DROP POLICY IF EXISTS "Members manage own push subscriptions" ON public.push_subscriptions;
CREATE POLICY "Registered members manage own push subscriptions"
ON public.push_subscriptions FOR ALL TO authenticated
USING (
  public.current_member_is_registered()
  AND (member_id = auth.uid() OR member_id IN (
    SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
  ))
)
WITH CHECK (
  public.current_member_is_registered()
  AND (member_id = auth.uid() OR member_id IN (
    SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
  ))
);

DROP POLICY IF EXISTS "Members read own notifications" ON public.notifications;
CREATE POLICY "Registered members read own notifications"
ON public.notifications FOR SELECT TO authenticated
USING (
  public.current_member_is_registered()
  AND (member_id = auth.uid() OR member_id IN (
    SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
  ))
);

DROP POLICY IF EXISTS "Members mark own notifications read" ON public.notifications;
CREATE POLICY "Registered members mark own notifications read"
ON public.notifications FOR UPDATE TO authenticated
USING (
  public.current_member_is_registered()
  AND (member_id = auth.uid() OR member_id IN (
    SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
  ))
)
WITH CHECK (
  public.current_member_is_registered()
  AND (member_id = auth.uid() OR member_id IN (
    SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
  ))
);

DROP POLICY IF EXISTS "Members delete own notifications" ON public.notifications;
CREATE POLICY "Registered members delete own notifications"
ON public.notifications FOR DELETE TO authenticated
USING (
  public.current_member_is_registered()
  AND (member_id = auth.uid() OR member_id IN (
    SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
  ))
);