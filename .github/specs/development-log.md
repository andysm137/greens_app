# Greens Development Breadcrumb

Last updated: 2026-09-12

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
- Added PWA deployment context from `.github/agent/PWA_DEPLOYMENT_NOTES.md` in the GitHub repository.
- Added password recovery routing and a change-password screen for Supabase `PASSWORD_RECOVERY` sessions.
- Added the first responsive UI slice: mobile uses bottom navigation, desktop retains the NavigationRail, and the Skill Matrix stacks its selectors on narrow screens while preserving horizontal table scrolling.
- Reworked Dance Builder around booking-scoped primary assignments, attending qualified candidates, musician competency dialogs, tap-to-edit position cards, red unavailable positions, and selectable 8/12-position layouts.
- Fixed Dance Builder MAF/MAB activation, included Learner (`L`) candidates alongside Qualified/Master, defaulted selection to the next chronological future Booking, and restored status-colored booking cards.
- Added persistent `booking_dance_settings` for per-booking/per-dance 8/12 position and MAF/MAB choices; builder changes now save immediately and reload for every leader.
- Restored full Admin dance catalog configuration: standard positions default to 8 with a `Can be performed as 12` option, plus MAF/MAB toggles and notes; Skill Matrix reads these catalog properties per dance.
- Updated Skill Matrix position columns to derive from `dance_catalog.standard_positions` instead of assuming eight positions.
- Replaced the Set Sheet placeholder with a booking-level printable report: booking header, attending musicians/instruments, catalog/settings-driven dance tiles, 8/12 formation rows, MAF/MAB, bold primary dancers, alternate candidates, and browser print-to-PDF.
- Removed the Set Sheet dependency on legacy `booking_set_layouts` after its table privileges could not be granted by the current Supabase SQL role; the report now uses booking assignments/settings as its active source.
- Retained all viable dancer candidates in Set Sheet rows when a primary exists, added duplicate-primary warnings/blocking in Dance Builder, added a dance-level insufficient-dancers banner, and added a database uniqueness migration for one primary dancer per booking/dance.
- Corrected the insufficient-dancers check to require a unique matching dancer across all active positions; one qualified dancer repeated across every position now triggers the warning.
- Updated Set Sheet to include Practices, show attending dancers above musicians, and grey dance tiles that lack unique attending `L/Q/M` coverage for every active position.
- Restored the Dance Builder formation graphic as a two-column grid, with centered MAF above and MAB below the numbered positions.
- Fixed expanded booking RSVP content so member and leader attendance changes refresh immediately.
- Limited booking status colors to the event header row so expanded RSVP content remains neutral.

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
- `supabase/migrations/20260912_booking_assignments.sql`: booking-scoped primary assignment table and RLS.
- `supabase/migrations/20260912_booking_dance_settings.sql`: persistent booking/dance formation settings and RLS.
- `supabase/migrations/20260912_unique_primary_dancers.sql`: database uniqueness constraint for one primary dancer per booking/dance.

PWA deployment:

- Source repository: `andysm137/greens_app`.
- Target GitHub Pages repository: `andysm137/SilkstoneGreensApp`.
- Workflow: `.github/workflows/static.yml`.
- Deployment method: build Flutter web in `greens_app`, then publish `build/web` to the target repository using `PAGES_REPO_TOKEN`.
- Expected public URL: `https://andysm137.github.io/SilkstoneGreensApp/`.
- Expected build command: `flutter build web --release --base-href "/SilkstoneGreensApp/"`.
- The PWA manifest, icons, standalone display mode, and Flutter web service worker are already configured according to the deployment notes.

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

For PWA deployment:

1. Verify `PAGES_REPO_TOKEN` in the `greens_app` repository's GitHub Actions secrets.
2. Confirm the token is a Classic Personal Access Token with `repo` and `workflow` scopes, if that is the token type required by the workflow.
3. Review the failed `Publish to Pages repository` step for the exact error; the deployment notes identify this as unresolved and suggest token permissions or expiry as likely causes.
4. Manually run the deployment workflow from the `main` branch after correcting the token.
5. Confirm that files update in `SilkstoneGreensApp` and verify the public Pages URL.

## Known risks and unfinished work

- Live RLS contains unrestricted public policies on several tables. This conflicts with the product security requirements and must be hardened deliberately.
- `team_members.instruments` and `musician_profiles` both exist. Choose one authoritative musician model before expanding musician features.
- Auth profile linkage currently supports both legacy `team_members.id` and `auth_user_id`; standardize this later.
- Existing widget test is stale and must be replaced with app-specific tests.
- `events_screen.dart` has an existing `use_build_context_synchronously` lint.
- OTP or magic-link login was discussed but deliberately deferred.
- A signed-in Change Password action is still to be added to the account/profile UI. It should collect a new password and confirmation, then call `auth.updateUser(UserAttributes(password: ...))` without requiring a reset email.
- Password reset redirects require Supabase Auth URL configuration for the active local debug URL and the current GitHub Pages URL; previously issued reset emails may still use the old redirect.
- Edge Function deployment is external to Flutter analysis; local code can compile while deployed functions remain stale.
- PWA deployment may build successfully while cross-repository publishing fails; verify the GitHub Actions publish step separately.
- The GitHub deployment notes report that stale build artifacts were addressed by ignoring `/build/` and `web/flutter_service_worker.js`; confirm those `.gitignore` changes are present in the local checkout.
- Events, Dance Builder, and Admin still need targeted mobile layouts; they should adapt their controls and cards rather than relying only on global scaling.
- The booking-scoped assignment migration must be applied before the new Dance Builder can save or load primary assignments.
- The booking formation settings migration must be applied before MAF/MAB and 8/12 choices can persist.
- Existing `dance_assignments` rows are legacy/global assignments and have not been automatically migrated into booking-scoped assignments.
- The booking assignment/settings migrations intentionally omit foreign keys because the current SQL role lacks `REFERENCES` permission on existing tables; referential integrity remains a follow-up database-owner task.
- `supabase/migrations/20260912_unique_primary_dancers.sql` requires a duplicate check before applying; it enforces one primary member per booking/dance across positions.
- Builder candidates require an exact `competencies.dance_name` match for the selected catalog dance and an `event_rsvps.rsvp_status` of `Attending`; mismatched dance names or RSVP values will correctly exclude a member.
- Set Sheet dance membership is currently inferred from `booking_dance_assignments` and `booking_dance_settings`; a dedicated booking-to-dance planning table may be needed if leaders must schedule dances before any builder/settings record exists.
- `booking_set_layouts` is now a legacy table candidate for removal. Before dropping it, check/export any rows, remove the unused `BookingLayout` repository/model code, verify no deployed code references it, and confirm an owner-capable SQL role can perform the drop.

## Recommended next sequence

1. Verify the GitHub Actions `Publish to Pages repository` step and `PAGES_REPO_TOKEN`.
2. Confirm the PWA appears at `https://andysm137.github.io/SilkstoneGreensApp/` after a fresh workflow run.
3. Verify the Supabase migration and all four Edge Functions.
4. Test Add Member, edit, Send Invite, invitation completion, status refresh, and delete.
5. Apply and verify `supabase/migrations/20260912_booking_assignments.sql`.
6. Apply and verify `supabase/migrations/20260912_booking_dance_settings.sql`.
7. Migrate or retire legacy `dance_assignments` data deliberately.
8. Capture live constraints, foreign keys, triggers, and functions.
9. Harden RLS and remove public write policies.
10. Replace the stale widget test and add repository/auth tests.
11. Refactor the broad repository into feature-specific services.
12. Decide whether to implement email OTP or magic-link login.
13. Add the signed-in Change Password account action.
14. Complete responsive layouts for Events, Dance Builder, and Admin.
15. Continue with booking validation and Set Sheet.
16. Retire legacy `booking_set_layouts` after data preservation and owner-level permission checks.

## Session update rule

At the end of a meaningful development session, update:

- `Last updated`
- `Completed today`
- `Required deployment state`
- `Known risks and unfinished work`
- `Recommended next sequence`

Keep entries concise and factual. Link to code rather than copying implementation details into this log.
