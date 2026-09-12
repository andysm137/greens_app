-- Booking-scoped primary dancer assignments.
-- Run after confirming existing dance_assignments data has been preserved or migrated.

CREATE OR REPLACE FUNCTION public.booking_is_leader_or_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM public.team_members
        WHERE (id = auth.uid() OR auth_user_id = auth.uid())
            AND (is_leader = TRUE OR is_admin = TRUE)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TABLE IF NOT EXISTS public.booking_dance_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    -- Cross-table foreign keys are intentionally omitted here because the
    -- current SQL role lacks REFERENCES privilege on the existing tables.
    booking_id UUID NOT NULL,
    dance_name TEXT NOT NULL,
    position_number INT NOT NULL CHECK (position_number BETWEEN 1 AND 12 OR position_number IN (98, 99)),
    member_id UUID NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT unique_booking_dance_position UNIQUE (booking_id, dance_name, position_number)
);

ALTER TABLE public.booking_dance_assignments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Authenticated users can read booking assignments"
ON public.booking_dance_assignments;

CREATE POLICY "Authenticated users can read booking assignments"
ON public.booking_dance_assignments FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Leaders and admins manage booking assignments"
ON public.booking_dance_assignments;

CREATE POLICY "Leaders and admins manage booking assignments"
ON public.booking_dance_assignments FOR ALL TO authenticated
USING (public.booking_is_leader_or_admin())
WITH CHECK (public.booking_is_leader_or_admin());

DROP TRIGGER IF EXISTS update_booking_dance_assignments_timestamp
ON public.booking_dance_assignments;

CREATE TRIGGER update_booking_dance_assignments_timestamp
BEFORE UPDATE ON public.booking_dance_assignments
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();
