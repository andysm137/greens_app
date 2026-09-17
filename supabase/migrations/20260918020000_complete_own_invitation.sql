CREATE OR REPLACE FUNCTION public.complete_own_invitation()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.team_members
  SET registered_at = NOW()
  WHERE (id = auth.uid() OR auth_user_id = auth.uid())
    AND invited_at IS NOT NULL
    AND registered_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No pending invitation found';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_own_invitation() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_own_invitation() TO authenticated;