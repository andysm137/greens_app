-- The RLS policy from 20260914_notifications_clear.sql limits deletion to
-- the current member's own notification rows. This grants the table-level
-- privilege required for that policy to be evaluated.

GRANT DELETE ON public.notifications TO authenticated;