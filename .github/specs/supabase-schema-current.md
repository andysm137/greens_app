# Supabase Schema Snapshot

Captured from the live Supabase project on 2026-09-11.

This is a current-state reference, not yet a migration. The column snapshot is based on the live `information_schema.columns` output supplied during this session. The policy snapshot is based on the live `pg_policies` output supplied during this session.

## Current schema facts

- Tables: `audit_logs`, `booking_set_layouts`, `competencies`, `dance_assignments`, `dance_catalog`, `event_rsvps`, `events`, `musician_profiles`, and `team_members`.
- `team_members.instruments` exists, and `musician_profiles` also exists. These are duplicate musician representations that need a deliberate consolidation decision.
- The live booking layout table is `booking_set_layouts`.
- The live dance assignment table is `dance_assignments`.
- `dance_catalog.notes` exists even though it was absent from the original table definition.
- UUID defaults use both `uuid_generate_v4()` and `gen_random_uuid()`.
- `competencies.proficiency_level` is `text` in the live schema.

## Policy findings

The current policies include public access with `USING (true)` and/or `WITH CHECK (true)` for:

- `team_members` with `ALL`
- `competencies` with `ALL`, `INSERT`, and `UPDATE`
- `dance_assignments` with `ALL`
- `dance_catalog` with `ALL`
- `event_rsvps` with `ALL` or unrestricted insert/update
- `events` with unrestricted insert/update

These policies allow unauthenticated reads and writes and conflict with the product specification's requirement that unauthenticated access be completely restricted. They also bypass the intended leader/admin checks.

## Required follow-up before more feature work

1. Capture foreign keys, unique constraints, indexes, triggers, functions, and views.
2. Decide whether `team_members.instruments` or `musician_profiles` is authoritative.
3. Add authenticated-only baseline policies and remove public write policies.
4. Restrict event creation and updates to leaders/admins.
5. Restrict competencies and dance assignments to leaders/admins for writes.
6. Restrict RSVP writes to the authenticated member's own `member_id`, with a separate leader/admin override policy if required.
7. Confirm whether `team_members.id` is intentionally equal to `auth.users.id`; the current Flutter auth gate assumes that relationship.

Do not apply policy cleanup until the required leader/admin and member workflows have been confirmed against the live application.
