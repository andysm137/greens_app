-- Apply in the Supabase SQL Editor as the database owner.
-- Replaces permissive public policies with the role model used by the app:
-- members manage their own RSVP and competency records; leaders manage events
-- and lineups; admins also manage the roster and dance catalog.

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
      AND is_admin = TRUE
  );
$$;

REVOKE ALL ON FUNCTION public.current_member_is_leader_or_admin() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_member_is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_member_is_leader_or_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_member_is_admin() TO authenticated;

REVOKE ALL ON TABLE public.team_members, public.musician_profiles,
  public.events, public.event_rsvps, public.competencies, public.dance_catalog,
  public.dance_assignments, public.booking_set_layouts,
  public.booking_dance_assignments, public.booking_dance_settings FROM anon;

GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.team_members,
  public.musician_profiles, public.events, public.event_rsvps,
  public.competencies, public.dance_catalog, public.dance_assignments,
  public.booking_set_layouts, public.booking_dance_assignments,
  public.booking_dance_settings TO authenticated;

DROP POLICY IF EXISTS "Allow full access to Leaders and Admins" ON public.team_members;
DROP POLICY IF EXISTS "Allow public access on team_members" ON public.team_members;
DROP POLICY IF EXISTS "Allow public read access on team_members" ON public.team_members;
DROP POLICY IF EXISTS "Allow read access to authenticated members" ON public.team_members;

DROP POLICY IF EXISTS "Leaders manage musician profiles" ON public.musician_profiles;
DROP POLICY IF EXISTS "Allow read access to musician profiles" ON public.musician_profiles;

DROP POLICY IF EXISTS "Allow authenticated insert to events" ON public.events;
DROP POLICY IF EXISTS "Allow authenticated update to events" ON public.events;
DROP POLICY IF EXISTS "Allow public read access to events" ON public.events;
DROP POLICY IF EXISTS "Allow read access to events" ON public.events;
DROP POLICY IF EXISTS "Leaders manage events" ON public.events;

DROP POLICY IF EXISTS "Allow authenticated insert/update to event_rsvps" ON public.event_rsvps;
DROP POLICY IF EXISTS "Allow public read access to event_rsvps" ON public.event_rsvps;
DROP POLICY IF EXISTS "Allow read access to RSVPs" ON public.event_rsvps;
DROP POLICY IF EXISTS "Members can manage own RSVP" ON public.event_rsvps;

DROP POLICY IF EXISTS "Allow Leaders/Admins to update competencies" ON public.competencies;
DROP POLICY IF EXISTS "Allow public access on competencies" ON public.competencies;
DROP POLICY IF EXISTS "Allow public insert access on competencies" ON public.competencies;
DROP POLICY IF EXISTS "Allow public read access on competencies" ON public.competencies;
DROP POLICY IF EXISTS "Allow public update access on competencies" ON public.competencies;
DROP POLICY IF EXISTS "Allow read access to competencies" ON public.competencies;
DROP POLICY IF EXISTS "Members can read own competencies" ON public.competencies;
DROP POLICY IF EXISTS "Members can update own competencies" ON public.competencies;
DROP POLICY IF EXISTS "Members can insert own competencies" ON public.competencies;

DROP POLICY IF EXISTS "Allow Admins to modify catalog" ON public.dance_catalog;
DROP POLICY IF EXISTS "Allow public access on dance_catalog" ON public.dance_catalog;
DROP POLICY IF EXISTS "Allow public read access on dance_catalog" ON public.dance_catalog;
DROP POLICY IF EXISTS "Allow read access to catalog for all authenticated users" ON public.dance_catalog;

DROP POLICY IF EXISTS "Allow public access on dance_assignments" ON public.dance_assignments;
DROP POLICY IF EXISTS "Allow Leaders/Admins to modify layouts" ON public.booking_set_layouts;
DROP POLICY IF EXISTS "Allow read access to layouts" ON public.booking_set_layouts;

DROP POLICY IF EXISTS "Authenticated users can read booking assignments" ON public.booking_dance_assignments;
DROP POLICY IF EXISTS "Leaders and admins manage booking assignments" ON public.booking_dance_assignments;
DROP POLICY IF EXISTS "Authenticated users can read booking dance settings" ON public.booking_dance_settings;
DROP POLICY IF EXISTS "Leaders and admins manage booking dance settings" ON public.booking_dance_settings;

CREATE POLICY "Authenticated users can read team members"
ON public.team_members FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins manage team members"
ON public.team_members FOR ALL TO authenticated
USING (public.current_member_is_admin())
WITH CHECK (public.current_member_is_admin());

CREATE POLICY "Authenticated users can read musician profiles"
ON public.musician_profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Leaders and admins manage musician profiles"
ON public.musician_profiles FOR ALL TO authenticated
USING (public.current_member_is_leader_or_admin())
WITH CHECK (public.current_member_is_leader_or_admin());

CREATE POLICY "Authenticated users can read events"
ON public.events FOR SELECT TO authenticated USING (true);

CREATE POLICY "Leaders and admins manage events"
ON public.events FOR ALL TO authenticated
USING (public.current_member_is_leader_or_admin())
WITH CHECK (public.current_member_is_leader_or_admin());

CREATE POLICY "Authenticated users can read RSVPs"
ON public.event_rsvps FOR SELECT TO authenticated USING (true);

CREATE POLICY "Members manage own RSVP"
ON public.event_rsvps FOR ALL TO authenticated
USING (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
)
WITH CHECK (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
);

CREATE POLICY "Leaders and admins manage RSVPs"
ON public.event_rsvps FOR ALL TO authenticated
USING (public.current_member_is_leader_or_admin())
WITH CHECK (public.current_member_is_leader_or_admin());

CREATE POLICY "Members can read own competencies"
ON public.competencies FOR SELECT TO authenticated
USING (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
);

CREATE POLICY "Members can update own competencies"
ON public.competencies FOR UPDATE TO authenticated
USING (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
)
WITH CHECK (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
);

CREATE POLICY "Members can insert own competencies"
ON public.competencies FOR INSERT TO authenticated
WITH CHECK (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
);

CREATE POLICY "Leaders and admins manage competencies"
ON public.competencies FOR ALL TO authenticated
USING (public.current_member_is_leader_or_admin())
WITH CHECK (public.current_member_is_leader_or_admin());

CREATE POLICY "Authenticated users can read dance catalog"
ON public.dance_catalog FOR SELECT TO authenticated USING (true);

CREATE POLICY "Admins manage dance catalog"
ON public.dance_catalog FOR ALL TO authenticated
USING (public.current_member_is_admin())
WITH CHECK (public.current_member_is_admin());

CREATE POLICY "Leaders and admins manage legacy dance assignments"
ON public.dance_assignments FOR ALL TO authenticated
USING (public.current_member_is_leader_or_admin())
WITH CHECK (public.current_member_is_leader_or_admin());

CREATE POLICY "Leaders and admins manage legacy booking layouts"
ON public.booking_set_layouts FOR ALL TO authenticated
USING (public.current_member_is_leader_or_admin())
WITH CHECK (public.current_member_is_leader_or_admin());

CREATE POLICY "Leaders and admins manage booking assignments"
ON public.booking_dance_assignments FOR ALL TO authenticated
USING (public.current_member_is_leader_or_admin())
WITH CHECK (public.current_member_is_leader_or_admin());

CREATE POLICY "Leaders and admins manage booking dance settings"
ON public.booking_dance_settings FOR ALL TO authenticated
USING (public.current_member_is_leader_or_admin())
WITH CHECK (public.current_member_is_leader_or_admin());