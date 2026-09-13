-- Allow authenticated members to read and update only their own competencies.
-- Leaders/admins retain the existing broader policy.
-- This supports team_members.id = auth.uid() and auth_user_id = auth.uid().

GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.competencies TO authenticated;

DROP POLICY IF EXISTS "Members can read own competencies"
ON public.competencies;

CREATE POLICY "Members can read own competencies"
ON public.competencies FOR SELECT TO authenticated
USING (
  member_id = auth.uid()
  OR member_id IN (
    SELECT id
    FROM public.team_members
    WHERE auth_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Members can update own competencies"
ON public.competencies;

CREATE POLICY "Members can update own competencies"
ON public.competencies FOR UPDATE TO authenticated
USING (
  member_id = auth.uid()
  OR member_id IN (
    SELECT id
    FROM public.team_members
    WHERE auth_user_id = auth.uid()
  )
)
WITH CHECK (
  member_id = auth.uid()
  OR member_id IN (
    SELECT id
    FROM public.team_members
    WHERE auth_user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "Members can insert own competencies"
ON public.competencies;

CREATE POLICY "Members can insert own competencies"
ON public.competencies FOR INSERT TO authenticated
WITH CHECK (
  member_id = auth.uid()
  OR member_id IN (
    SELECT id
    FROM public.team_members
    WHERE auth_user_id = auth.uid()
  )
);
