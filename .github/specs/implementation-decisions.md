# Implementation Decisions

Updated 2026-09-11.

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
- Live RLS currently includes public unrestricted policies that conflict with the product security requirements. Policy hardening remains outstanding.
- The live schema and policy snapshots are in `supabase-schema-current.md` and `supabase-policy-current.md`.
- The migration `supabase/migrations/20260911_member_invitation_tracking.sql` must be applied before invitation tracking works.
- Edge Functions must be deployed after changes before the Flutter workflow can use them.
