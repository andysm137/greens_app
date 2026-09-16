-- Run this in Supabase SQL Editor as the postgres/database owner.
-- It lets the invitation Edge Function record the Auth link without requiring
-- PostgREST UPDATE privileges on team_members for its API role.

CREATE OR REPLACE FUNCTION public.record_member_invitation(
  p_member_id UUID,
  p_auth_user_id UUID,
  p_invited_at TIMESTAMPTZ
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.team_members
  SET auth_user_id = p_auth_user_id,
      invited_at = p_invited_at
  WHERE id = p_member_id
    AND auth_user_id IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Member profile was not found or has already been invited';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.record_member_invitation(UUID, UUID, TIMESTAMPTZ)
FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.record_member_invitation(UUID, UUID, TIMESTAMPTZ)
TO service_role;
