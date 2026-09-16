-- Persistent per-booking/per-dance formation settings.
-- Foreign keys are omitted to match the current SQL role privileges.

CREATE TABLE IF NOT EXISTS public.booking_dance_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID NOT NULL,
    dance_name TEXT NOT NULL,
    standard_positions INT NOT NULL CHECK (standard_positions IN (8, 12)),
    has_maf BOOLEAN NOT NULL DEFAULT FALSE,
    has_mab BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_booking_dance_settings UNIQUE (booking_id, dance_name)
);

ALTER TABLE public.booking_dance_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read booking dance settings"
ON public.booking_dance_settings;

CREATE POLICY "Authenticated users can read booking dance settings"
ON public.booking_dance_settings FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Leaders and admins manage booking dance settings"
ON public.booking_dance_settings;

CREATE POLICY "Leaders and admins manage booking dance settings"
ON public.booking_dance_settings FOR ALL TO authenticated
USING (public.booking_is_leader_or_admin())
WITH CHECK (public.booking_is_leader_or_admin());

DROP TRIGGER IF EXISTS update_booking_dance_settings_timestamp
ON public.booking_dance_settings;

CREATE TRIGGER update_booking_dance_settings_timestamp
BEFORE UPDATE ON public.booking_dance_settings
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
