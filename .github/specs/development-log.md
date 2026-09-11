# Greens Development Breadcrumb

Last updated: 2026-09-11

This file preserves the current implementation context for future development sessions. It records decisions and verified state, not every conversation detail.

## Current product direction

Silkstone Greens is a Flutter web app backed by Supabase for dance-team operations: members, events, RSVPs, skills, dance assignments, booking layouts, musicians, and set sheets.

Primary roles:

- Member: view relevant team information and manage their own RSVP.
- Leader: manage events, competencies, and assignments.
- Admin: manage configuration, roster, invitations, and users.

## Completed today

- Added a Supabase session-based `AuthGate` and email/password sign-in.
- Added current-member profile loading and sign-out.
- Removed the hard-coded test member ID and local admin-mode switch from the shell.
- Added admin workspace gating.
- Added server-side invitation and deletion workflows using Supabase Edge Functions.
- Added admin invite UI and admin member deletion UI.
- Split roster lifecycle: Add Member creates a profile; invitation is sent later from the edit dialog.
- Added invitation status display: `Not invited`, `Invite sent`, and `Member registered`.
- Added `auth_user_id`, `invited_at`, and `registered_at` migration design.
- Corrected booking repository references to `booking_set_layouts`.
- Added current live schema and RLS policy snapshots.
- Fixed the Admin roster `ListTile` overflow by keeping the avatar in the leading slot and placing status beside the subtitle.

## Current files and boundaries

Flutter:

- `lib/main.dart`: Supabase initialization and app root.
- `lib/screens/auth_gate.dart`: session routing and sign-in.
- `lib/screens/main_shell.dart`: authenticated navigation and role display.
- `lib/screens/admin_view.dart`: roster, profile editing, invitations, deletion, and catalog administration.
- `lib/services/team_repository.dart`: current data access, still broad and due for feature-specific separation.
- `lib/services/admin_auth_service.dart`: Edge Function calls for admin member operations.
- `lib/models/team_member.dart`: member profile and invitation status model.

Supabase:

- `supabase/migrations/20260911_member_invitation_tracking.sql`
- `supabase/functions/invite-member/index.ts`
- `supabase/functions/invite-existing-member/index.ts`
- `supabase/functions/member-auth-statuses/index.ts`
- `supabase/functions/delete-member/index.ts`

Documentation:

- `.github/specs/supabase-schema-current.md`: live column snapshot and schema observations.
- `.github/specs/supabase-policy-current.md`: live RLS policy output.
- `.github/specs/implementation-decisions.md`: auth, member lifecycle, and backend decisions.
- `.github/agents/SQL setup code.txt`: older working SQL reference; not automatically authoritative.
- `.github/agents/Silkstone Greens App - System Requirements Specification (V3).txt`: product requirements source.

## Required deployment state

Before testing invitation tracking:

1. Apply `supabase/migrations/20260911_member_invitation_tracking.sql` in the Supabase SQL Editor.
2. Deploy the changed Edge Functions:
   - `invite-member`
   - `invite-existing-member`
   - `member-auth-statuses`
   - `delete-member`
3. Ensure the current admin profile has `is_admin = true` and is linked through either `team_members.id` or `team_members.auth_user_id`.
4. Configure Supabase Auth email and redirect URLs.

## Known risks and unfinished work

- Live RLS contains unrestricted public policies on several tables. This conflicts with the product security requirements and must be hardened deliberately.
- `team_members.instruments` and `musician_profiles` both exist. Choose one authoritative musician model before expanding musician features.
- Auth profile linkage currently supports both legacy `team_members.id` and `auth_user_id`; standardize this later.
- Existing widget test is stale and must be replaced with app-specific tests.
- `events_screen.dart` has an existing `use_build_context_synchronously` lint.
- OTP or magic-link login was discussed but deliberately deferred.
- Edge Function deployment is external to Flutter analysis; local code can compile while deployed functions remain stale.

## Recommended next sequence

1. Verify migration and all four Edge Functions in Supabase.
2. Test Add Member, edit, Send Invite, invitation completion, status refresh, and delete.
3. Capture live constraints, foreign keys, triggers, and functions.
4. Harden RLS and remove public write policies.
5. Replace the stale widget test and add repository/auth tests.
6. Refactor the broad repository into feature-specific services.
7. Decide whether to implement email OTP or magic-link login.
8. Continue with booking validation and Set Sheet.

## Session update rule

At the end of a meaningful development session, update:

- `Last updated`
- `Completed today`
- `Required deployment state`
- `Known risks and unfinished work`
- `Recommended next sequence`

Keep entries concise and factual. Link to code rather than copying implementation details into this log.
