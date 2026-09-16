-- Prevent one dancer from being primary in multiple positions of the same booking/dance.
-- Check for duplicates before running if booking_dance_assignments already contains data.

ALTER TABLE public.booking_dance_assignments
  ADD CONSTRAINT unique_booking_dance_primary_member
  UNIQUE (booking_id, dance_name, member_id);
