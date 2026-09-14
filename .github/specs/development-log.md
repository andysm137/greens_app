# Greens Development Breadcrumb

Last updated: 2026-09-14

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
- Added date-only event creation, optional event descriptions, date-only booking display, and an expanded Details dialog beside the location; event type remains stored but is no longer shown in the card header.
- Restricted member Booking access to their own RSVP controls, added leader/admin dancer and musician attendance summaries, and restricted member Skill Matrix access to their own By Dancer view.
- Fixed the member Skill Matrix mode initialization so the own-competency query runs, and added `20260913_member_competency_access.sql` for authenticated own-record competency SELECT/INSERT/UPDATE access.
- Changed the competency scale to `L` Learner, `YP` Yes with a practice, and `Y` Ok; Dance Builder and Set Sheet use only `YP/Y` as performer-ready levels.
- Added the unset competency state `-`; the Skill Matrix now cycles `- -> L -> YP -> Y -> -`, and the migration normalizes null/unknown legacy values to `-`.
- Created a fresh local release PWA build with `flutter build web --release --base-href "/SilkstoneGreensApp/"`; output is in `build/web` with `404.html` copied for client-side routing.
- Updated the invitation Edge Function to resolve Supabase's current `SUPABASE_SECRET_KEYS` JSON default secret, with a legacy `SUPABASE_SERVICE_ROLE_KEY` fallback, after the function received permission-denied errors reading `team_members`.
- Added `20260913_record_member_invitation.sql` to perform the protected invitation metadata update through an owner-defined `SECURITY DEFINER` RPC when direct Edge Function table UPDATE privileges are unavailable.
- Verified the admin invitation flow works after applying `20260913_record_member_invitation.sql` and redeploying `invite-existing-member`.
- Restored the Dance Builder formation graphic as a two-column grid, with centered MAF above and MAB below the numbered positions.
- Fixed expanded booking RSVP content so member and leader attendance changes refresh immediately.
- Limited booking status colors to the event header row so expanded RSVP content remains neutral.
- Diagnosed stale local web builds: generated `main.dart.js` and related runtime/assets had been committed inside `web/` and could overwrite the fresh compiler output during packaging.
- Removed generated files from `web/`; source web files are now limited to `index.html`, `manifest.json`, `favicon.png`, and `icons/`.
- Verified clean release build output under `build/web`.
- Grouped leader/admin event RSVP rosters into alphabetized Musicians and Dancers for every event type.
- Updated Dance Builder event selection to show date-sorted event labels, hide past events by default, and provide the same past-event toggle as Events & Practices.
- Ordered Dance Builder candidates with the primary dancer first and bold, then `Y` before `YP`, with ascending same-rating position coverage and full-name tie breaks; candidate names use the Skills Matrix rating colors.
- Made paired Dance Builder position cards match the height of the tallest wrapped candidate list in their row.
- Updated Set Sheet position lists to mirror Dance Builder candidate eligibility, order, primary emphasis, and `YP`/`Y` name colors; paired rows now share the tallest wrapped row height.
- Applied `20260913_harden_role_access.sql`, removing permissive public policies and enforcing member, leader, and admin access boundaries.
- Applied `20260913_event_response_deadlines.sql`, adding event response deadlines, optional Maybe comments, and database-enforced RSVP cutoffs.
- Applied `20260913_delete_booking_with_artifacts.sql`, providing Admin-only transactional event deletion with RSVP, lineup, settings, and legacy-layout cleanup.
- Added the Admin Notifications tab and applied `20260914_web_push_notifications.sql` to store notification enablement, message-template overrides, deadline reminder days, and browser push subscriptions.
- Added scoped browser push registration, an authenticated subscription action, deployed `push-configuration`/`send-push-notification` Edge Functions, and configured hosted VAPID secrets.
- Deployed `register-push-subscription` so browser subscriptions are resolved and stored server-side, supporting legacy email-linked member profiles without weakening client RLS.
- Applied `20260914_register_push_subscription.sql` to register browser subscriptions through a database-native, legacy-profile-aware RPC after direct RLS registration was rejected by Supabase.
- Applied `20260914_push_delivery_access.sql` to give the deployed notification sender server-only access to subscription encryption keys and stale-subscription cleanup.
- Verified end-to-end Web Push: browser permission, subscription registration, hosted VAPID configuration, and server-generated test delivery all succeeded.
- Added a member-facing browser-specific disable action; `20260914_unregister_push_subscription.sql` is pending application before that control can remove the stored endpoint.
- Wired immediate event notifications for event creation, status changes, event detail changes, and RSVP changes; the deployed sender selects recipients and applies Admin notification settings/templates server-side.
- Added and deployed `send-deadline-reminders`, which uses Admin-configured reminder days, skips responded members, and prevents duplicate sends with `notification_deliveries`.
- Applied `20260914_notifications_inbox.sql`, adding a lightweight unread/read notification inbox; the single bell now shows a badge/list with individual and mark-all read actions, and immediate/deadline sender functions persist inbox records.
- Applied `20260914_notification_delivery_settings.sql` and redeployed both notification senders to read Admin settings through a server-only RPC.
- Added `20260914_notification_inbox_delivery_access.sql` and redeployed both notification senders so immediate and deadline deliveries insert inbox records through a server-only RPC instead of a direct RLS-blocked table write.
- Applied `20260914_event_notification_access.sql` and redeployed the immediate sender with server-only event context and recipient access.
- Applied `20260914_notifications_clear.sql` to allow members to clear only their own notification inbox records.
- Applied `20260914_notifications_clear_privileges.sql` so the authenticated role has the table-level DELETE privilege required by the own-notifications RLS policy.
- Applied `20260914_event_notification_context_date.sql` so notification delivery includes event dates and reactive event navigation has the required server context.
- Added a realtime Postgres Changes subscription on `notifications` in `main_shell.dart` so the bell badge count updates live instead of only on menu actions.
- Fixed `_EventStatusCardState` so a notification-driven auto-expand request is applied via `didUpdateWidget` even when `ListView` reuses an existing card's `State`.
- Added `competency_updated` notifications: when a member changes their own Skill Matrix entry, Leaders/Admins are notified with the dance, position, and old/new proficiency level; added `20260914_competency_notification_setting.sql` for its default settings row.
- Appended a `Sent: <date time> UTC` line to both `send-push-notification` and `send-deadline-reminders` delivered bodies.
- Changed the deployed PWA icon references in `web/manifest.json` and `web/index.html` to `icons/Greens App icon.jpg` (favicon, apple-touch-icon, and all manifest icon entries).
- Renamed the deployed PWA display name from `greens_app` to `Greens` in `web/manifest.json` (`name`/`short_name`) and `web/index.html` (`<title>`, `apple-mobile-web-app-title`).
- Fixed the Events tab "sticky" auto-expand: `main_shell.dart` now clears `_pendingEventId` via `addPostFrameCallback` immediately after passing it to `EventsScreen` once, so returning to the tab later never re-expands a past notification's event.
- Moved the Go/No-go/Pending status control into the colored header chip (`_buildStatusChip` in `_EventStatusCardState`), replacing the separate "Booking Status:" dropdown row; same options, callback, and Leader/Admin-only access.
- Added Member RSVP guard rails in `events_screen.dart`: No-go locks RSVP changes entirely; Go/past-deadline still allow moving to Attending but block moving away from it with a "discuss with a Leader" popup; changing from Attending to Not Attending now always prompts for a reason (mirroring the existing Maybe comment prompt). Leaders/Admins are unaffected. Notification dispatch on RSVP change is unchanged.
- Added `related_member_id`/`dance_name` columns to `notifications` and extended `insert_notification_for_delivery` (`20260914_notification_competency_context.sql`) so `competency_updated` deliveries carry deep-link context; `send-push-notification` now passes them through and has been redeployed.
- Tapping a `competency_updated` notification now switches to the Skill Matrix tab in By Dancer mode for the affected member and highlights the changed dance row (`SkillsMatrixView.initialDancerId`/`highlightDanceName`, wired through `main_shell.dart`'s pending-navigation pattern).

## Product TODOs

Dance Builder:

- [ ] Give a dancer a green background when they are not already primary in another position; use grey when they are already primary elsewhere.
- [ ] Reduce the height of Dance Builder dropdowns and switches on mobile without clipping labels or controls.
- [ ] Keep the insufficient-dancers warning fixed in the Dance Builder viewport instead of allowing it to scroll away.
- [ ] Decide whether practices require dance building in the same way as performances.
- [ ] Add widget coverage for event filtering and the candidate ordering rules: primary, `YP`/`Y`, position coverage, and full-name ties.
- [ ] Update Set Sheet planning so it shows the state of every possible dance, including dances that have not yet been built.
- [ ] Add a dance summary row showing whether the available dancers and positions form a valid combination, without requiring primary assignments first.

Set Sheet:

- [ ] Validate the equal-height, wrapped candidate rows on narrow mobile layouts and the printed output; adjust column sizing if long names still overflow.
- [ ] Format the printable/PDF Set Sheet for A4 paper, including page margins, repeatable headers, and sensible page breaks.
- [ ] Add widget coverage that verifies Set Sheet candidate presentation remains aligned with Dance Builder.

Bookings:

- [ ] Fix flickering on the booking page when updating attendance for team members.
- [ ] Test Member, Leader, and Admin RSVP behavior for historic, `Go`, and post-deadline events.
- [ ] Verify only Admins can delete any event and its related records.

Security and data integrity:

- [ ] Rotate the exposed Supabase service-role key, reset the affected account password, and remove the temporary password-reset script.
- [ ] Re-export the live `pg_policies` output and test member, leader, and admin workflows after the applied RLS hardening.
- [ ] Audit every direct write in `team_repository.dart` so role restrictions are enforced by RLS, not only by hidden UI screens.
- [ ] Restrict privileged Edge Function CORS responses to approved application origins.
- [ ] Make invitation and member-deletion workflows transactional or add reliable reconciliation for partial failures.
- [ ] Replace the implicit password-reset redirect with an allowlist of approved application URLs.

Notifications:

- [ ] Verify only Admins can manage notification settings while members can manage only their own subscriptions.
- [ ] Verify notification settings disable delivery and message-template overrides appear in delivered notifications.
- [ ] Verify the daily `send-deadline-reminders-daily` Cron job (confirmed active, schedule `0 8 * * *`) actually delivers and dedupes across a real deadline date.
- [ ] Verify `competency_updated` notifications end-to-end: self-edit by a Member, delivery to Leaders/Admins, inbox record, and realtime badge update.
- [ ] Rebuild and redeploy the PWA (`flutter build web ...`) to confirm the new app name/icon take effect in the installed/home-screen PWA.

Reliability and structure:

- [ ] Replace `dart:html` in Set Sheet with a supported printing/download boundary so WASM builds remain possible.
- [ ] Cancel the `AuthGate` auth-state subscription in `dispose()`.
- [ ] Remove the N+1 auth lookups and read-time writes from `member-auth-statuses`.
- [ ] Replace the generated counter widget test with auth, RLS, repository, Dance Builder, and Set Sheet coverage.
- [ ] Split the broad `team_repository.dart` into feature-specific services or repositories.
- [ ] Choose one authoritative musician data model between `team_members.instruments` and `musician_profiles`.

## Current files and boundaries

Flutter:

- `lib/main.dart`: Supabase initialization and app root.
- `lib/screens/auth_gate.dart`: session routing and sign-in.
- `lib/screens/main_shell.dart`: authenticated navigation and role display.
- `lib/screens/events_screen.dart`: event list, RSVP controls, and grouped musician/dancer roster.
- `lib/screens/dance_builder_view.dart`: event filtering, attendance-aware lineup candidates, primary assignments, and equal-height position matrix rows.
- `lib/screens/set_sheet_view.dart`: printable event set sheet with Dance Builder-aligned candidate lists and equal-height position rows.
- `lib/screens/admin_view.dart`: roster, profile editing, invitations, deletion, and catalog administration.
- `lib/services/team_repository.dart`: current data access, still broad and due for feature-specific separation.
- `lib/services/admin_auth_service.dart`: Edge Function calls for admin member operations.
- `lib/services/notification_settings_repository.dart`: Admin notification settings CRUD and per-type test-send.
- `lib/services/notification_subscription_service.dart`: browser push enable/disable for the current member.
- `lib/services/notifications_repository.dart`: in-app notification inbox fetch/read/clear.
- `lib/services/push_notifications.dart` (+ `_web.dart`/`_stub.dart`): browser push subscription bridge.
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
- `supabase/migrations/20260913_harden_role_access.sql`: applied role-based RLS cleanup for member, leader, and admin access.
- `supabase/migrations/20260913_event_response_deadlines.sql`: applied deadline/comment columns and RSVP cutoff policy.
- `supabase/migrations/20260913_delete_booking_with_artifacts.sql`: applied Admin-only transactional event deletion RPC.
- `supabase/migrations/20260914_web_push_notifications.sql`: applied notification settings and browser push subscription tables.
- `supabase/migrations/20260914_register_push_subscription.sql`: applied database-native browser subscription registration RPC.
- `supabase/migrations/20260914_push_delivery_access.sql`: applied server-only subscription read/delete RPCs for notification delivery.
- `supabase/functions/push-configuration/index.ts`: authenticated public VAPID-key endpoint.
- `supabase/functions/send-push-notification/index.ts`: server-owned Web Push sender, settings enforcement, templates, and browser-subscription cleanup.
- `supabase/functions/register-push-subscription/index.ts`: authenticated server-side browser subscription registration.
- `supabase/functions/send-deadline-reminders/index.ts`: deployed deadline reminder sender with response filtering, duplicate claims, and a sent timestamp; runs daily via Supabase Cron (`send-deadline-reminders-daily`, `0 8 * * *`) authenticated with a Vault-held `CRON_SECRET`.
- `supabase/migrations/20260914_deadline_reminders.sql`: applied reminder delivery log (`notification_deliveries`) and scheduler hand-off notes.
- `supabase/migrations/20260914_notifications_inbox.sql`: applied in-app `notifications` inbox table with member-owned read state.
- `supabase/migrations/20260914_notification_delivery_settings.sql`: applied server-only `get_notification_setting_for_delivery` RPC.
- `supabase/migrations/20260914_notification_inbox_delivery_access.sql`: applied server-only `insert_notification_for_delivery` RPC.
- `supabase/migrations/20260914_event_notification_access.sql`: applied server-only event context/recipient RPCs (`get_event_notification_context`, `get_event_notification_recipients`).
- `supabase/migrations/20260914_notifications_clear.sql` and `20260914_notifications_clear_privileges.sql`: applied member-owned inbox delete policy and its required table-level `DELETE` grant.
- `supabase/migrations/20260914_event_notification_context_date.sql`: applied event date/time addition to notification context.
- `supabase/migrations/20260914_competency_notification_setting.sql`: applied default settings row for `competency_updated`.
- `.github/specs/notification-system-operations.md`: Admin, Leader, and Member notification configuration, deployment, testing, and troubleshooting guide.

PWA deployment:

- Source repository: `andysm137/greens_app`.
- Target GitHub Pages repository: `andysm137/SilkstoneGreensApp`.
- Workflow: `.github/workflows/static.yml`.
- Deployment method: build Flutter web in `greens_app`, then publish `build/web` to the target repository using `PAGES_REPO_TOKEN`.
- Expected public URL: `https://andysm137.github.io/SilkstoneGreensApp/`.
- Expected build command: `flutter build web --release --base-href "/SilkstoneGreensApp/"`.
- The PWA manifest, icons, and standalone display mode are source-controlled; Flutter generates the service worker and runtime files into `build/web`.
- The source `web/` directory must not contain generated `main.dart.js`, `flutter.js`, `flutter_bootstrap.js`, `flutter_service_worker.js`, `version.json`, `assets/`, or `canvaskit/` files.
- For local static hosting from this Windows path, assign the resolved path to a variable before passing it to `dhttpd`; otherwise spaces in `Documents\Flutter code` are split into separate arguments.

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

After applying role-based RLS:

1. Re-export `pg_policies` to `supabase-policy-current.md` and test member, leader, and admin workflows against the live project.

After applying response deadlines and Maybe comments:

1. Verify that Members and Leaders cannot alter historic RSVPs, Members cannot alter `Go` events or responses after deadline, and Admin overrides work as intended.

After applying Admin event deletion:

1. Verify an Admin deletion removes the event, RSVPs, booking assignments, formation settings, and legacy layout records; verify Member and Leader calls are rejected.

For PWA deployment:

1. Verify `PAGES_REPO_TOKEN` in the `greens_app` repository's GitHub Actions secrets.
2. Confirm the token is a Classic Personal Access Token with `repo` and `workflow` scopes, if that is the token type required by the workflow.
3. Review the failed `Publish to Pages repository` step for the exact error; the deployment notes identify this as unresolved and suggest token permissions or expiry as likely causes.
4. Manually run the deployment workflow from the `main` branch after correcting the token.
5. Confirm that files update in `SilkstoneGreensApp` and verify the public Pages URL.

## Known risks and unfinished work

- Re-export the live RLS policy snapshot to verify `20260913_harden_role_access.sql` applied without unexpected legacy policies remaining.
- `team_members.instruments` and `musician_profiles` both exist. Choose one authoritative musician model before expanding musician features.
- Dance Builder identifies musicians from `team_members.instruments`, while Set Sheet's musician summary also consults `musician_profiles`; align these checks when selecting the authoritative model.
- Auth profile linkage currently supports both legacy `team_members.id` and `auth_user_id`; standardize this later.
- Existing widget test is stale and must be replaced with app-specific tests.
- `events_screen.dart` has an existing `use_build_context_synchronously` lint.
- OTP or magic-link login was discussed but deliberately deferred.
- A signed-in Change Password action is still to be added to the account/profile UI. It should collect a new password and confirmation, then call `auth.updateUser(UserAttributes(password: ...))` without requiring a reset email.
- Password reset redirects require Supabase Auth URL configuration for the active local debug URL and the current GitHub Pages URL; previously issued reset emails may still use the old redirect.
- Edge Function deployment is external to Flutter analysis; local code can compile while deployed functions remain stale.
- The invitation Edge Function must use the current `SUPABASE_SECRET_KEYS` reserved secret JSON, with legacy `SUPABASE_SERVICE_ROLE_KEY` only as a fallback. Direct `team_members` updates from the function are avoided through `record_member_invitation`.
- PWA deployment may build successfully while cross-repository publishing fails; verify the GitHub Actions publish step separately.
- The local PWA release build succeeds. The build reports the known `dart:html` WebAssembly incompatibility in Set Sheet; use `--no-wasm-dry-run` for the standard JavaScript build.
- Generated web output is ignored in both `/build/` and the source `web/` artifact paths; do not restore generated files into `web/`.
- Events, Dance Builder, and Admin still need targeted mobile layouts; they should adapt their controls and cards rather than relying only on global scaling.
- The booking-scoped assignment migration must be applied before the new Dance Builder can save or load primary assignments.
- The booking formation settings migration must be applied before MAF/MAB and 8/12 choices can persist.
- Existing `dance_assignments` rows are legacy/global assignments and have not been automatically migrated into booking-scoped assignments.
- The booking assignment/settings migrations intentionally omit foreign keys because the current SQL role lacks `REFERENCES` permission on existing tables; referential integrity remains a follow-up database-owner task.
- `supabase/migrations/20260912_unique_primary_dancers.sql` requires a duplicate check before applying; it enforces one primary member per booking/dance across positions.
- `supabase/migrations/20260913_competency_levels.sql` maps legacy `Q/M` values to `YP/Y` and replaces the proficiency constraint.
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
9. Re-export the RLS policy snapshot and manually test member, leader, and admin boundaries.
10. Verify Admin notification enablement, template override, and subscription ownership controls using the deployed test sender.
11. Add event-trigger dispatch and scheduled deadline-reminder delivery with duplicate-send protection.
12. Replace the stale widget test and add repository/auth, RLS, and notification coverage.
13. Refactor the broad repository into feature-specific services.
14. Decide whether to implement email OTP or magic-link login.
15. Add the signed-in Change Password account action.
16. Complete responsive layouts for Events, Dance Builder, and Admin.
17. Continue with booking validation and Set Sheet.
18. Retire legacy `booking_set_layouts` after data preservation and owner-level permission checks.
19. Keep local web validation on the generated `build/web` directory, using `$webPath = (Resolve-Path .\build\web).Path` before starting `dhttpd`.
20. Address the Security and data integrity TODOs before expanding privileged administration features.

## Session update rule

At the end of a meaningful development session, update:

- `Last updated`
- `Completed today`
- `Required deployment state`
- `Known risks and unfinished work`
- `Recommended next sequence`

Keep entries concise and factual. Link to code rather than copying implementation details into this log.
