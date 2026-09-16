-- Default settings row for the member-self competency-change notification.

INSERT INTO public.notification_settings (
  notification_type, is_enabled, reminder_days, message_template
) VALUES
  ('competency_updated', TRUE, '{}', NULL)
ON CONFLICT (notification_type) DO NOTHING;
