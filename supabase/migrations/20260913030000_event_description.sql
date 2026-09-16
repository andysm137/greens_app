-- Add optional human-readable details to events and bookings.
ALTER TABLE public.events
  ADD COLUMN IF NOT EXISTS description TEXT;
