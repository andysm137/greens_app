-- Competency scale migration:
-- L = Learner, YP = Yes, with a practice, Y = Ok.
-- Run as the database owner after reviewing existing competency data.

DO $$
DECLARE
  constraint_record RECORD;
BEGIN
  FOR constraint_record IN
    SELECT con.conname
    FROM pg_constraint con
    JOIN pg_class rel ON rel.oid = con.conrelid
    JOIN pg_namespace ns ON ns.oid = rel.relnamespace
    WHERE ns.nspname = 'public'
      AND rel.relname = 'competencies'
      AND con.contype = 'c'
      AND pg_get_constraintdef(con.oid) ILIKE '%proficiency_level%'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.competencies DROP CONSTRAINT %I',
      constraint_record.conname
    );
  END LOOP;
END $$;

UPDATE public.competencies SET proficiency_level = 'YP' WHERE proficiency_level = 'Q';
UPDATE public.competencies SET proficiency_level = 'Y' WHERE proficiency_level = 'M';

ALTER TABLE public.competencies
  DROP CONSTRAINT IF EXISTS competencies_proficiency_level_check;

ALTER TABLE public.competencies
  ADD CONSTRAINT competencies_proficiency_level_check
  CHECK (proficiency_level IN ('L', 'YP', 'Y'));
