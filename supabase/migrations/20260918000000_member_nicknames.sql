ALTER TABLE public.team_members
ADD COLUMN IF NOT EXISTS nickname TEXT;

CREATE TABLE IF NOT EXISTS public.app_display_settings (
  id BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK (id),
  use_nicknames BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.app_display_settings (id, use_nicknames)
VALUES (TRUE, FALSE)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.app_display_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read display settings"
ON public.app_display_settings FOR SELECT TO authenticated
USING (TRUE);

CREATE POLICY "Admins manage display settings"
ON public.app_display_settings FOR UPDATE TO authenticated
USING (public.current_member_is_admin())
WITH CHECK (public.current_member_is_admin());

CREATE TRIGGER update_app_display_settings_timestamp
BEFORE UPDATE ON public.app_display_settings
FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();