-- Drop the legacy booking_set_layouts table.
-- Verified empty (0 rows) on 2026-09-16 before dropping.
-- Corresponding Dart model (booking_layout.dart) and repository methods
-- (fetchBookingLayouts, saveBookingLayout) have been removed from the codebase.

DROP TABLE IF EXISTS public.booking_set_layouts;

