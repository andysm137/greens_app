# Implementation Decisions

Updated 2026-09-12.

## Authentication

- Supabase Auth owns credentials, sessions, password resets, and invitation tokens.
- Flutter routes through `AuthGate` and requires an authenticated session.
- A signed-in user must resolve to a `team_members` profile.
- Profile resolution supports either `team_members.id = auth.users.id` or `team_members.auth_user_id = auth.users.id`.
- Admin workspace access is based on the loaded `is_admin` flag; the UI must not manufacture admin privileges locally.
- The current login method is email and password.
- Email OTP or magic-link login was discussed but is deferred for a later decision.

## Member lifecycle

- **Add Member** creates or edits a team profile and does not require an email address or Auth account.
- **Send Invite** is a separate action in the member edit dialog.
- An invitation requires an email address and is sent through the server-side `invite-existing-member` Edge Function.
- New invited profiles track `auth_user_id` and `invited_at`.
- Registration status is checked server-side by `member-auth-statuses` and displayed as `Not invited`, `Invite sent`, or `Member registered`.
- `invite-member` remains available for the older create-and-invite flow, but the primary UI flow is create profile first, invite later.
- Admins can delete members through the server-side `delete-member` Edge Function. Self-deletion is blocked.

## Set Sheet and assignment behavior

- Set Sheet replaces the placeholder workspace and is a read-only booking/practice report with browser print-to-PDF.
- It shows attending dancers above attending musicians, then renders each configured dance in a compact two-column formation layout.
- Primary dancers are bold; all viable attending `L/Q/M` candidates remain visible even when a primary exists.
- Non-compliant dances are greyed out when unique dancer coverage cannot satisfy every active position, including enabled MAF/MAB positions.
- Practices are included in the Set Sheet selector as well as Bookings.
- A primary dancer cannot be used in more than one position for the same booking and dance; this is checked in the UI and can be enforced with `20260912_unique_primary_dancers.sql`.
- The Set Sheet no longer queries legacy `booking_set_layouts`; active output uses booking assignments/settings, RSVP data, competencies, roster, musicians, and dance catalog data.

## Server-side boundaries

- Auth Admin APIs and service-role credentials must remain inside Supabase Edge Functions.
- Flutter calls Edge Functions using the authenticated Supabase session.
- Deployed function names currently expected by the app:
  - `invite-member`
  - `invite-existing-member`
  - `member-auth-statuses`
  - `delete-member`

## Database decisions and open work

- The live database contains both `team_members.instruments` and `musician_profiles`; consolidation is still undecided.
- Booking-specific primary assignments are stored in `booking_dance_assignments`.
- Booking-specific formation choices are stored in `booking_dance_settings`, keyed by booking and dance.
- The new booking tables currently omit foreign keys because the SQL Editor role lacks `REFERENCES` permission on the existing tables. Add those constraints later using an owner-capable migration role after checking existing data.
- Live RLS currently includes public unrestricted policies that conflict with the product security requirements. Policy hardening remains outstanding.
- The live schema and policy snapshots are in `supabase-schema-current.md` and `supabase-policy-current.md`.
- The migration `supabase/migrations/20260911_member_invitation_tracking.sql` must be applied before invitation tracking works.
- Edge Functions must be deployed after changes before the Flutter workflow can use them.
