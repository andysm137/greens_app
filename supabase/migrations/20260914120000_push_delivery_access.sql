-- Apply after 20260914_web_push_notifications.sql.
-- Browser clients never receive subscription encryption keys. These RPCs are
-- restricted to the service-role context used by the notification sender.

CREATE OR REPLACE FUNCTION public.get_push_subscriptions_for_delivery(
  p_member_id UUID
)
RETURNS TABLE (id UUID, endpoint TEXT, p256dh TEXT, auth TEXT)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id, endpoint, p256dh, auth
  FROM public.push_subscriptions
  WHERE member_id = p_member_id;
$$;

CREATE OR REPLACE FUNCTION public.delete_push_subscription_for_delivery(
  p_subscription_id UUID
)
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.push_subscriptions
  WHERE id = p_subscription_id;
$$;

REVOKE ALL ON FUNCTION public.get_push_subscriptions_for_delivery(UUID)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_push_subscription_for_delivery(UUID)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_push_subscriptions_for_delivery(UUID)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.delete_push_subscription_for_delivery(UUID)
  TO service_role;