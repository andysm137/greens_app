-- Allow members to clear only their own in-app notification records.

CREATE POLICY "Members delete own notifications"
ON public.notifications FOR DELETE TO authenticated
USING (
  member_id = auth.uid()
  OR member_id IN (SELECT id FROM public.team_members WHERE auth_user_id = auth.uid())
);