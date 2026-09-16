-- Add foreign key constraints to booking_dance_assignments and booking_dance_settings.
-- Verified: 0 orphaned rows exist across all current records.

-- 1. booking_dance_assignments
ALTER TABLE public.booking_dance_assignments
  DROP CONSTRAINT IF EXISTS booking_dance_assignments_booking_id_fkey,
  DROP CONSTRAINT IF EXISTS booking_dance_assignments_member_id_fkey,
  DROP CONSTRAINT IF EXISTS booking_dance_assignments_dance_name_fkey;

ALTER TABLE public.booking_dance_assignments
  ADD CONSTRAINT booking_dance_assignments_booking_id_fkey
    FOREIGN KEY (booking_id) REFERENCES public.events(id) ON DELETE CASCADE,
  ADD CONSTRAINT booking_dance_assignments_member_id_fkey
    FOREIGN KEY (member_id) REFERENCES public.team_members(id) ON DELETE CASCADE,
  ADD CONSTRAINT booking_dance_assignments_dance_name_fkey
    FOREIGN KEY (dance_name) REFERENCES public.dance_catalog(dance_name) ON UPDATE CASCADE ON DELETE CASCADE;

-- 2. booking_dance_settings
ALTER TABLE public.booking_dance_settings
  DROP CONSTRAINT IF EXISTS booking_dance_settings_booking_id_fkey,
  DROP CONSTRAINT IF EXISTS booking_dance_settings_dance_name_fkey;

ALTER TABLE public.booking_dance_settings
  ADD CONSTRAINT booking_dance_settings_booking_id_fkey
    FOREIGN KEY (booking_id) REFERENCES public.events(id) ON DELETE CASCADE,
  ADD CONSTRAINT booking_dance_settings_dance_name_fkey
    FOREIGN KEY (dance_name) REFERENCES public.dance_catalog(dance_name) ON UPDATE CASCADE ON DELETE CASCADE;
