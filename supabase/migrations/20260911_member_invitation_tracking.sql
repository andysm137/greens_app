-- Run this migration in the Supabase SQL Editor before deploying the updated functions.

ALTER TABLE public.team_members
  ADD COLUMN IF NOT EXISTS auth_user_id UUID UNIQUE REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS invited_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS registered_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS team_members_auth_user_id_idx
  ON public.team_members(auth_user_id);
