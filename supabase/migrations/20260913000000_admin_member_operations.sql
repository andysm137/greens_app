-- Run in Supabase SQL Editor as the postgres/database owner.
-- These SECURITY DEFINER functions keep protected team_members writes out of
-- Edge Function PostgREST table operations.

CREATE OR REPLACE FUNCTION public.create_invited_member(
  p_id UUID,
  p_full_name TEXT,
  p_email TEXT,
  p_phone TEXT,
  p_is_leader BOOLEAN,
  p_is_admin BOOLEAN,
  p_instruments TEXT[],
  p_invited_at TIMESTAMPTZ
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.team_members (
    id, auth_user_id, full_name, email, phone, is_leader, is_admin, instruments, invited_at
  ) VALUES (
    p_id, p_id, p_full_name, p_email, p_phone, p_is_leader, p_is_admin, NULLIF(array_to_string(p_instruments, ', '), ''), p_invited_at
  );

  IF COALESCE(array_length(p_instruments, 1), 0) > 0 THEN
    INSERT INTO public.musician_profiles (member_id, primary_instrument)
    SELECT p_id, instrument
    FROM unnest(p_instruments) AS instrument;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_member_registered(
  p_member_id UUID,
  p_registered_at TIMESTAMPTZ
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.team_members
  SET registered_at = p_registered_at
  WHERE id = p_member_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_member_profile(p_member_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.musician_profiles WHERE member_id = p_member_id;
  DELETE FROM public.team_members WHERE id = p_member_id;
END;
$$;

REVOKE ALL ON FUNCTION public.create_invited_member(UUID, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN, TEXT[], TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_member_registered(UUID, TIMESTAMPTZ) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_member_profile(UUID) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.create_invited_member(UUID, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN, TEXT[], TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_member_registered(UUID, TIMESTAMPTZ) TO service_role;
GRANT EXECUTE ON FUNCTION public.delete_member_profile(UUID) TO service_role;
