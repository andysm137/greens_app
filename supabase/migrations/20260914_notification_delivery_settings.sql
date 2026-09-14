-- Server-only access for deployed notification senders.
-- Browser clients must continue using the Admin-only RLS policy directly.

CREATE OR REPLACE FUNCTION public.get_notification_setting_for_delivery(
  p_notification_type TEXT
)
RETURNS TABLE (
  is_enabled BOOLEAN,
  reminder_days INTEGER[],
  message_template TEXT
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT is_enabled, reminder_days, message_template
  FROM public.notification_settings
  WHERE notification_type = p_notification_type;
$$;

REVOKE ALL ON FUNCTION public.get_notification_setting_for_delivery(TEXT)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_notification_setting_for_delivery(TEXT)
  TO service_role;