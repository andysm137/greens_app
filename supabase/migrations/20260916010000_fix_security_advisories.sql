-- Fix Supabase Security Advisor warnings:
-- 1. Fix mutable search_path on public functions
ALTER FUNCTION public.update_timestamp() SET search_path = public;
ALTER FUNCTION public.is_leader_or_admin() SET search_path = public;
ALTER FUNCTION public.log_competency_changes() SET search_path = public;
ALTER FUNCTION public.booking_is_leader_or_admin() SET search_path = public;

-- 2. Revoke anonymous execution of internal SECURITY DEFINER functions
REVOKE EXECUTE ON FUNCTION public.booking_is_leader_or_admin() FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.is_leader_or_admin() FROM anon, public;
REVOKE EXECUTE ON FUNCTION public.log_competency_changes() FROM anon, public;

-- Ensure authenticated role can execute them as required
GRANT EXECUTE ON FUNCTION public.booking_is_leader_or_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_leader_or_admin() TO authenticated;
