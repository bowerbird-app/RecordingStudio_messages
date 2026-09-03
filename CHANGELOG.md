# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0/).

## [0.3.0] - 2026-09-03

The dummy host now uses Recording Studio Users for shared password auth, and
Messages follows the current Recording Studio dependency family.

### Added
- Recording Studio Users `0.8.0` from PR
  [#20](https://github.com/bowerbird-app/RecordingStudio_users/pull/20), pinned
  to commit `1adc7722ec58fcfeb43ff1e2e96849936a6e9411` until `v0.8.0` is tagged.
- Users People, Profile, Identity, registration, confirmation, and optional OTP
  migrations in the dummy host.
- Accessible's `depends_on_recording_id` migration from `0.8.0`.

### Changed
- Dummy `/users/sign_in` and `/users/sign_up` use
  `recording_studio_user_auth_for :users`. The copied Devise login view is gone;
  the Users gem shared auth shell is the source of truth.
- Dummy Propshaft rewrites Flatpack's logical CSS `@import` paths to digested
  URLs so `variables`, `rich_text`, and `content_editor` load without 404s.
- Updated Core to `4.2.1`, Accessible to `0.9.1`, Attachable to `0.5.1`,
  Notifications to `0.3.1`, Root Switchable to `0.5.1`, Admin to `2.0.2`, and
  Flatpack to `0.1.144`. Root and dummy lockfiles update all dependencies.

### Upgrade notes
- Bump Messages to `0.3.0` and use the dependency versions above.
- Run `bin/rails generate recording_studio_accessible:migrations`, then
  `bin/rails db:migrate`, for `depends_on_recording_id`.
- Hosts adopting Users `0.8.0` should skip Devise sessions, registrations, and
  passwords, call `recording_studio_user_auth_for :users`, mount the Users
  engine, register People and Profile, run its migrations, and remove copied
  Devise auth views. Add the OmniAuth callbacks controller only when the User
  model is `:omniauthable`.
- Replace the temporary Users commit ref with `tag: "v0.8.0"` after PR #20 is
  merged and tagged.

## [0.2.1] - 2026-09-02

Cloud Agent Builds for this gem now match Billing 0.9.13. Conversations, mounts,
and screens are unchanged.

### Added
- `.cursor/fetch-skills.sh`, `.cursor/install.sh`, `.cursor/start.sh`, and
  `.cursor/environment.json` for Cloud Agent boot. Install skips apt,
  ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
  already usable. A skippable provision failure does not fail the Build.
  Fetch-skills always runs last. Start only brings PostgreSQL up.

### Upgrade notes
- No host or schema changes. Rebuild the Cloud Agent environment with Draft
  off so Build loads the pack.

## [0.2.0] - 2026-08-22

Conversations land. One gem, keyed mounts, Accessible membership, Attachable files, and a Flatpack chat panel.

### Added
- `:messages` capability. Host types include `RecordingStudio::Capabilities::Messages.to`
- `MessageMount` (keyed child), `MessageGroup` (Accessible conversation), `Message` (Attachable line)
- `ensure_message_mount`, `create_group`, `send_message`, and `granted_actors`
- `:message_received` notification type. Send calls `RecordingStudioNotifications.notify_each` for other granted actors
- Flatpack `Chat::Panel` screens (header, messages, composer). Header faces use `recording_studio_accessible_avatars`
- Dummy staff desk and inbox that prove two mounts at once, with seeded people, an agent, lines, and one attachment
- `message_groups#index` is Flatpack `Chat::Layout` `:split`. Accessible `:view` scopes the sidebar. Sidebar rows are `Chat::InboxRow` only. The panel slot is `Chat::Panel`. Hollow empty-grant conversations stay off the sidebar
- `viewable_group_recordings(actor:, mount_recording:)` scopes that list. Dummy support mount seeds two real conversations so the list is not a single jump to a panel
- Send replaces the Chat::Panel thread and composer over Turbo so the new line lands in place. There is no Action Cable in this version
- InboxRow clicks target the `messages-desk-panel` turbo frame. Layout Stimulus `openPanel` / `showPanel` shows the conversation under `md` without a full show visit

### Changed
- README is the product guide for mounts, enablement, and the dummy proof
- Core PageNav is the one back on the desk. Chat::Header has no `back_href`. Chat::Layout's injected mobile Back is hidden so the two do not stack
- Dummy puts `data-theme="rounded"` on the `html` element. Core default layout only sets it on `body`, which is not enough for Flatpack named themes
- Flatpack pin moves to [PR #159](https://github.com/bowerbird-app/flatpack/pull/159) (`~> 0.1.135`, HEAD `daceb04b76578b2d7adfa42a65e1f66f42d24f23`) so rounded rebinds primary-wired tokens (charcoal Send and mine bubbles). No Messages CSS fork

### Upgrade notes
- Bump to `0.2.0` and keep the family pins from 0.1.0, except Flatpack
- Point host and dummy Gemfiles at Flatpack PR `#159` HEAD (`0.1.135`, ref `daceb04b76578b2d7adfa42a65e1f66f42d24f23`). Do not use a merge commit or `tag: "v0.1.135"` — that tag does not exist. Do not stay on `v0.1.133` if you want charcoal rounded CTAs
- Put `data-theme="rounded"` on `html`. Body-only theme is not enough. The dummy helper is the host workaround while core leaves `<html>` bare
- Send now answers Turbo by replacing `conversation-<id>-messages` and the composer. Do not add Action Cable. HTML posts still redirect with a flash
- Open a mount on `message_groups#index` (`?mount_id=`). Do not jump straight to show when a desk has conversations. Index uses Accessible `:view` on each `MessageGroup`
- InboxRow must set `turbo_frame` to `messages-desk-panel`. A row click must not full-visit show and remount the split desk
- Include `RecordingStudio::Capabilities::Messages.to` on each host type that should hold a mount
- Register `MessageMount`, `MessageGroup`, `Message`, and `RecordingStudioAttachable::Attachment` in `recording_studio.rb`
- Run `recording_studio_messages:migrations` plus Accessible, Attachable, and Notifications migrations
- Mount Messages, Accessible, and Attachable
- Do not add a Notifications → Messages edge
- Do not add Participant recordables. Grants on the conversation are the membership list
- v1 has no realtime, typing, read receipts, email channel, or Admin slice

## [0.1.0] - 2026-08-22

First version of Recording Studio Messages. The engine is renamed from the addon template. Family pins are real. Threads, groups, and screens are not in this slice.

### Added
- Engine identity `recording_studio_messages` / `RecordingStudioMessages`
- Gemspec pins: `recording_studio ~> 4.2`, `recording_studio_accessible ~> 0.7.0`, `recording_studio_attachable ~> 0.4`, `recording_studio_notifications ~> 0.2.5`, `flat_pack ~> 0.1.133`
- Dummy GitHub tags for the same family, plus Root Switchable `v0.5.0` for host chrome

### Changed
- Renamed the engine from the addon template to `recording_studio_messages`
- Dummy authenticated pages use Recording Studio's default layout chrome and load Flatpack CSS/JS (including `flat_pack/application` and Turbo)
- Configuration hooks come from `RecordingStudio::Hooks` in core

### Removed
- Leftover template identity in the public README and gemspec
- Dummy starter docs pages and custom `flat_pack_sidebar` shell
- Copied Hooks, BaseService, example service, and engine sample home controller
- Example engine pages migration

### Upgrade notes
- Point host and dummy Gemfiles at Recording Studio `v4.2.0`, Accessible `v0.7.0`, Attachable `0.4.0`, Notifications `v0.2.5`, and Flatpack `v0.1.133`
- Declare the gemspec constraints above. GitHub hosting is not a reason to skip them
- There is no `recording_studio_flatpack` gem; depend on `flat_pack`
- Do not add a Notifications → Messages edge
- Do not enable Message types in this slice

[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.2.1
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.1.0
