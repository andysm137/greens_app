-- Apply after 20260914_web_push_notifications.sql.

CREATE OR REPLACE FUNCTION public.unregister_push_subscription(
  p_endpoint TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.push_subscriptions
  WHERE endpoint = p_endpoint
    AND (
      member_id = auth.uid()
      OR member_id IN (
        SELECT id FROM public.team_members WHERE auth_user_id = auth.uid()
      )
      OR member_id IN (
        SELECT id
        FROM public.team_members
        WHERE email = (auth.jwt() ->> 'email')
      )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.unregister_push_subscription(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.unregister_push_subscription(TEXT) TO authenticated;