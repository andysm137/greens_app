-- Add last_sign_in_at tracking to public.team_members, synced from auth.users.

-- 1. Add column to team_members
ALTER TABLE public.team_members
  ADD COLUMN IF NOT EXISTS last_sign_in_at TIMESTAMPTZ;

-- 2. Backfill existing last_sign_in_at values from auth.users
UPDATE public.team_members tm
SET last_sign_in_at = au.last_sign_in_at
FROM auth.users au
WHERE tm.auth_user_id = au.id
  AND au.last_sign_in_at IS NOT NULL;

-- 3. Trigger function to automatically keep team_members.last_sign_in_at updated
CREATE OR REPLACE FUNCTION public.sync_member_last_sign_in()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.last_sign_in_at IS DISTINCT FROM OLD.last_sign_in_at THEN
    UPDATE public.team_members
    SET last_sign_in_at = NEW.last_sign_in_at
    WHERE auth_user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

-- 4. Trigger on auth.users for login updates
DROP TRIGGER IF EXISTS on_auth_user_sign_in ON auth.users;
CREATE TRIGGER on_auth_user_sign_in
  AFTER UPDATE OF last_sign_in_at ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_member_last_sign_in();

