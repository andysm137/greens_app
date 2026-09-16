-- Apply after 20260914_web_push_notifications.sql.
-- Resolve the calling member inside the database so browser subscriptions do
-- not depend on direct-table RLS matching legacy profile links.

CREATE OR REPLACE FUNCTION public.register_push_subscription(
  p_endpoint TEXT,
  p_p256dh TEXT,
  p_auth TEXT,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_member_id UUID;
BEGIN
  SELECT id
  INTO resolved_member_id
  FROM public.team_members
  WHERE id = auth.uid()
     OR auth_user_id = auth.uid()
     OR email = (auth.jwt() ->> 'email')
  ORDER BY CASE
    WHEN id = auth.uid() THEN 1
    WHEN auth_user_id = auth.uid() THEN 2
    ELSE 3
  END
  LIMIT 1;

  IF resolved_member_id IS NULL THEN
    RAISE EXCEPTION 'Team profile not found';
  END IF;

  IF COALESCE(trim(p_endpoint), '') = ''
    OR COALESCE(trim(p_p256dh), '') = ''
    OR COALESCE(trim(p_auth), '') = '' THEN
    RAISE EXCEPTION 'A complete browser push subscription is required';
  END IF;

  INSERT INTO public.push_subscriptions (
    member_id, endpoint, p256dh, auth, user_agent, updated_at
  ) VALUES (
    resolved_member_id, p_endpoint, p_p256dh, p_auth, p_user_agent, NOW()
  )
  ON CONFLICT (endpoint) DO UPDATE
  SET member_id = EXCLUDED.member_id,
      p256dh = EXCLUDED.p256dh,
      auth = EXCLUDED.auth,
      user_agent = EXCLUDED.user_agent,
      updated_at = NOW();
END;
$$;

REVOKE ALL ON FUNCTION public.register_push_subscription(TEXT, TEXT, TEXT, TEXT)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_push_subscription(TEXT, TEXT, TEXT, TEXT)
  TO authenticated;