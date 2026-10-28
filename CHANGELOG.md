# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0/).

## [Unreleased]

### Added

- Hosts can override `messages_panel_right_header(group_recording)`, `messages_panel_right_header_mobile(group_recording)`, and `messages_panel_after(group_recording)`. Defaults return nil. The panel fills Flatpack `Chat::Panel` `right_header` and `right_header_mobile` only when that hook returns content, and renders `messages_panel_after` once after the panel. A blank return leaves the panel markup unchanged.

### Changed

- Gemspec floor is `flat_pack >= 0.1.329`. Development and the dummy still pin Flatpack tag `v0.1.329`.

## [0.9.1] - 2026-10-28

Dummy Flatpack 0.1.329 and Users 0.26.3. Drop the Card `style:` shim.

### Removed

- Dummy `config/initializers/flatpack_card_styles.rb` and `test/dummy/test/integration/flatpack_card_styles_test.rb`. That test only covered the shim.

### Changed

- Development and dummy pin Flatpack `v0.1.329` and Users `v0.26.3` (`59c0e16`). Users 0.26.3 views pass `shadow: :md` on cards, not `style:`. Gemspec floor stays `flat_pack >= 0.1.315`. Admin stays `v2.6.2`. Root Switchable stays `v0.10.0`. Dummy Tailwind checks keep alert tokens in the Tailwind build; secondary button tokens live in Flatpack CSS.

### Upgrade notes

- Bump to **0.9.1**. No Messages migration.
- Dummy no longer maps Card `style:`. Hosts still on Users below 0.26 must stop passing `style:` to `FlatPack::Card`. Use `background:`, `shadow:`, `border:`, and `hover:`.

## [0.9.0] - 2026-10-27

### Changed

- Conversation lists, the staff desk, the inbox, and the dummy home use Recording Studio 6.1's default layout. `RecordingStudioMessages.configuration.layout` defaults to `nil`. `nil` uses `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`. `false` renders no layout. A string is a layout name. A callable is invoked as `call(controller:)` and must return a String, `nil`, or `false`.
- Page titles are `content_for :title` and `content_for :subtitle`. The default layout renders one `FlatPack::PageTitle`. Back and close use `flat_pack_page_nav(round: true, style: :default, ...)`.
- The desk wrapper defaults to `h-[calc(100dvh-15.5rem)]` so the title stays below the sticky top nav and the page does not scroll. The old `8.5rem` offset was the shorter nav from before Recording Studio 6. Hosts that pass `desk_height_class` keep their own value.
- Public contact asks Users `Services::IssueOtp` for a code and `resend_otp!` for another. Both return a result. A throttled result tells the visitor to wait. A suppressed result says email codes are required. `RecordingStudioUser.issue_otp!` is gone in Users 0.24.
- Gemspec floors are `recording_studio >= 6.1.0` and `flat_pack >= 0.1.315`. Development and the dummy pin Recording Studio `v6.1.0`, Flatpack `v0.1.315`, and `view_component` `4.19.0`.

### Removed

- `include RecordingStudio::UsesDefaultLayout`. That module is gone in Recording Studio 5.
- `recording_studio_page_nav`. That helper is gone in Recording Studio 6. The dummy still defines it so Users, Admin, and Site Settings screens that have not migrated keep a back and close row.

### Upgrade notes

- Bump to **0.9.0**. No Messages migration. Hosts still run the Notifications and Users generators listed below.
- Require `recording_studio` `>= 6.1.0` (git tag `v6.1.0`) and `flat_pack` `>= 0.1.315` (git tag `v0.1.315`). `v0.1.319` is not a published tag. `view_component` resolves at `4.19.0` (`>= 4.14, < 5`).
- Set the shell with `config.layout`. Leave it `nil` to follow the host's `RecordingStudio.configuration.layout`.
- Delete host copies of `layouts/recording_studio/default_layout` that still draw `FlatPack::PageNav` by hand. Core's layout is the shell. It sets `data-theme="rounded"` on `<html>`.
- Replace `recording_studio_page_nav(title:)` with `content_for :title` and `flat_pack_page_nav`. Put extra actions in `register_page_nav` or `content_for :page_nav_right`.
- `FlatPack::Card` no longer accepts `style:`. Use `background:`.
- These latest sibling tags still require `recording_studio` below 5, so a host Gemfile cannot resolve 6.1.0 until they publish a compatible tag. This repo's Gemfiles load `test/support/widen_recording_studio_requirement.rb` so Bundler can boot. Delete that file when the tags below allow `>= 6.1.0`.
  - `recording_studio_accessible` `v0.21.0` (`~> 4.7`, `>= 4.7.1`). Open PR 42 (`cursor/rs-6-1-default-layout-7e10`) allows 6.1 and is not tagged.
  - `recording_studio_admin` `v2.6.2` depends on `recording_studio_logs` `>= 0.4.1, < 1` (pinned `v0.7.0`, which itself requires `recording_studio ~> 4.2`)
  - `recording_studio_attachable` `v0.21.1` (`~> 4.2`)
  - `recording_studio_cache` `v0.5.1` (`~> 4.2`)
  - `recording_studio_internationalization` `v0.1.7` (`~> 4.2`)
  - `recording_studio_metrics` `v0.6.1` (`~> 4.2`)
  - `recording_studio_notifications` `v0.13.1` (`~> 4.2`)
  - `recording_studio_publishable` `v0.11.0` (`~> 4.2`)
  - `recording_studio_root_switchable` `v0.10.0` (`~> 4.1`)
  - `recording_studio_site_settings` `v0.5.1` (`~> 4.2`, and `include RecordingStudio::UsesDefaultLayout` with no `defined?` guard)
  - `recording_studio_terms_and_conditions` `v0.13.4` (`~> 4.2`)
  - `recording_studio_trashable` `v0.11.3` (`~> 4.7`)
  - `recording_studio_user` `v0.25.2` (`~> 4.2`)
- The dummy defines an empty `RecordingStudio::UsesDefaultLayout` so Site Settings 0.5.1 can load. Remove that stub when Site Settings stops including it.
- Attachable 0.21 no longer ships `Library` or `Placement` recordables. Drop those names from `config.recordable_types`. Register `RecordingStudioAttachable::Attachment` only.
- Run `bin/rails generate recording_studio_notifications:migrations` and migrate. Notifications 0.13 writes an `inbox` flag on each notice.
- Run `bin/rails generate recording_studio_user:migrations` and migrate. Users 0.24 adds a partial unique index on open OTP challenges (`index_rs_user_otp_challenges_open_purpose`).

## [0.8.3] - 2026-10-22

Widen the Metrics runtime ceiling.

### Changed

- Gemspec `recording_studio_metrics >= 0.3.0, < 1.0` (CI tested with 0.3.0). No code change.

### Upgrade notes

- Bump to **0.8.3**. No migration
- Dummy and development stay on Metrics `v0.3.1` (0.3.0)

## [0.8.2] - 2026-10-20

Allow Metrics 0.5.

### Changed

- Gemspec `recording_studio_metrics >= 0.3.0, < 0.6` so hosts can install Metrics 0.5. Dummy and development stay on Metrics `v0.3.1` (0.3.0) until Attachable widens its `< 0.4` cap.

### Upgrade notes

- Bump to **0.8.2**. No migration
- Hosts that stay on Metrics 0.3.x do not need to change
- To use Metrics 0.5, raise the host pin to a 0.5.x tag. Attachable 0.20.0 still requires Metrics `< 0.4`

## [0.8.0] - 2026-10-16

### Added

- `admin_notification_root` files `:message_received` for staff under an Admin root recording. Default `nil` keeps every recipient on the conversation root. A recording or a callable that returns one opts in. Recipients with Accessible `:view` on that recording are staff for this purpose (the same check as `Api::Access.can_view?`). The ticket owner stays on the ticket root. Tickets do not move. Notification type stays `scope: :root`. Staff copies omit `recording` when the Admin root is not the message's tree root, because Notifications requires those two to match. URL and metadata stay.

### Upgrade notes

- Bump to **0.8.0**. No migration
- Hosts and Support that want staff copies in the Admin notifications inbox set `config.admin_notification_root` to the Admin root recording, commonly `-> { RecordingStudioMessages::Api::Access.admin_root_recording }`
- Unset, filing is unchanged

## [0.7.0] - 2026-10-16

### Added

- Docs and tests for operations metric MCP tool names. RecordingStudio MCP `0.17.0` turns each identifier's single dot into a hyphen (`messages.sent_over_time` → `messages-sent_over_time`). `from`, `to`, and `interval` apply to the three timeseries only. `contact_intents.converted` is a breakdown and does not take a window.
- `public_contact_sign_in_after_verification` signs a signed-out visitor in through Devise/Warden after the public contact email code verifies (new registration or existing login). Default `false`.
- `public_contact_success_redirect_url` (String or callable receiving `mount_recording:`, `group_recording:`, `user:`, `request:`) and `public_contact_success_redirect_label` replace the single "Message sent" button on the page and in the dialog. Unset, a signed-in sender gets "View conversation" to the new conversation. Set, that button uses the URL for new and existing users. The label defaults to the translated "View conversation". A blank URL hides the button.

### Changed

- Gemspec `recording_studio_metrics >= 0.3.0, < 0.4`, GitHub pin `v0.3.1`
- `public_contact_sent_icon` still defaults to the heroicon `rocket-launch`. A path or URL — an image extension, a value starting with `/`, `http://`, or `https://`, or any other asset path — renders an image in that slot at the same size. `nil` hides the slot.

### Upgrade notes

- Bump to **0.7.0**. No migration
- Pin `recording_studio_metrics` to `>= 0.3.0, < 0.4` (git tag `v0.3.1`)
- This gem still registers definitions only. Hosts that expose Admin operations call `RecordingStudioMetrics::Api.register!(api: :operations)`
- Registration and `api_authorize` (`RecordingStudioMessages::Api::Access.can_view?`) are unchanged
- Staff with AdminRoot view see the metrics. Other actors are denied

## [0.6.0] - 2026-10-09

Operations metrics for messages, conversations, and public contact intents.

### Added
- `RecordingStudioMessages::Metrics.register!` from `config.to_prepare` (idempotent on reload)
- Site-wide operations metrics, all `expose: { api: [:operations] }`, `blast_radius: :site`
- `messages.sent_over_time` and `message_groups.created_over_time` count live `RecordingStudio::Recording` rows (`recordable_type` + `trashed_at: nil`)
- `contact_intents.submitted_over_time` and `contact_intents.converted` (`converted` / `expired` / `pending`) on `PublicContactIntent`
- `RecordingStudioMessages::Api::Access.can_view?` — AdminRoot `:view` through Accessible
- Gemspec `recording_studio_metrics ~> 0.2`, GitHub pin `v0.2.0`

### Upgrade notes
- Bump to **0.6.0**. No migration
- Hosts that expose Admin operations call `RecordingStudioMetrics::Api.register!(api: :operations)`. This gem only registers metric definitions
- Staff with AdminRoot view see the metrics. Other actors are denied

## [0.5.2] - 2026-10-08

Allow Notifications 0.4.

### Changed
- Gemspec accepts `recording_studio_notifications >= 0.3.1, < 1` so hosts can install Notifications 0.4
- Dummy and development pins move to Notifications `v0.4.0`

### Upgrade notes
- Bump to **0.5.2**. No migration
- Hosts that stay on Notifications 0.3.x do not need to change
- To use Notifications 0.4 (translated customer notification screens), pin `recording_studio_notifications` at `v0.4.0` in the host Gemfile

## [0.5.0] - 2026-10-08

Customer-facing Messages copy now lives under `recording_studio.messages.*` so hosts can translate contact forms, conversation chrome, flashes, and related screens.

### Added
- Engine ships English only in `config/locales/en.yml`
- Nested keys: `t("recording_studio.messages.contact.submit")` (not a top-level `recording_studio_messages:` namespace)
- Dummy hosts English and French via Recording Studio Internationalization, with a compact language selector in the top nav

### Upgrade notes
- Bump to **0.5.0** (minor: hosts can translate customer Messages screens). No migration
- English screens stay the same. Helper arguments that already accept custom text (`title`, `introduction`, `submit_label` on `public_contact_form` / `public_contact_modal`) still win over the locale default
- To offer another language, copy `recording_studio.messages.*` from `config/locales/en.yml` into the host (`config/locales/<locale>.yml`) and list that locale in `config.i18n.available_locales`. Dummy `test/dummy/config/locales/fr.yml` is a complete starting point
- Do not add `RecordingStudio_Internationalization` as a gem dependency of this engine. Use plain Rails I18n. Internationalization is a host (and dummy) concern
- Conversation titles, message bodies, attachment names, and notification titles stored in the database are data. This gem does not translate them. Host-configured form titles and submit labels passed into the helpers are also data
- OTP email copy is owned by Recording Studio Users, not this gem
- Staff Admin screens and recordable labels stay English

Development and dummy pins climb the Recording Studio family through layer 2. Core stays on `v4.2.2`. Dummy Flatpack moves to `v0.1.206` so chat kit copy can follow the locale. This gem's gemspec still accepts `flat_pack ~> 0.1.148`.

### Changed
- Accessible tag `v0.11.1` (gem `VERSION` `0.11.0`), Attachable tag `v0.7.1` (`0.7.0`), Notifications tag `v0.3.4` (`0.3.2`), Users tag `v0.12.5` (`0.12.3`), Admin tag `v2.0.4` (`2.0.2`), Root Switchable tag `v0.5.3` (`0.5.1`), and Site Settings tag `v0.1.3` (`0.1.0`). Bundler matches those `VERSION` constants; the git tags are newer than the constants.
- Dummy Accessible schema now includes access invitations and stores roles as strings (`view`, `edit`, `admin`). Dummy Attachable also stores `root_recording_id` plus caption, credit, and alt text.
- Gemspec widens Accessible to `~> 0.11` and Attachable to `~> 0.7` so those tags resolve.

### Upgrade notes
- Run `bin/rails generate recording_studio_accessible:migrations` and migrate. Hosts need Accessible's 0.8–0.11 migrations: `depends_on_recording_id` if missing, the access invitations table, and `recording_studio_accesses.role` as a string.
- Grant through Accessible's public services. `RecordingStudio::Access` is readonly.
- Publishable stays on `v0.3.1` in the dummy because Terms `v0.7.3` still requires `recording_studio_publishable ~> 0.3`.
- API is not a Messages dependency and is not pinned here.

## [0.4.5] - 2026-10-06

A host can open public contact in a modal. The full page stays the default.

### Added
- `public_contact_modal(mount)` renders a Flatpack modal and a button that opens it. Compose, the email code, resend, errors, and "Message sent" replace the dialog body. A signed-in person still skips the code. Closing on the code step and opening again shows that same step. After "Message sent", opening again starts a new note.

### Changed
- The sent screen says "Powered by" the site name. "View conversation" is a primary button. In the dialog, the Contact title is hidden on that step.
- The email code screen says "Verify it's you". The button says "Next". "Resend code" is a link. In the dialog, the Contact title is hidden on that step. The code, the field, and the actions have space between them.
- A notice or error in the contact dialog has space under it.
- The public contact page loads Flatpack's application stylesheet so primary buttons use the theme colors.
- `presentation=modal` on the public contact URL. A normal visit still uses the centered page. A Turbo Frame request for `public_contact` renders only that step.

### Upgrade notes
- Hosts that do not call `public_contact_modal` keep the full page. No migration.
- Include `RecordingStudioMessages::PublicContactHelper` on the host controller. The dialog needs Turbo on that page.
- One dialog per page. The frame id is `public_contact`.
- The sent screen no longer says "Your message has been sent." It says "Powered by" the site name. Site Settings supplies that name when the host has the gem.
- The email code screen no longer says "Check your email" or "Confirm & send". It says "Verify it's you", the button says "Next", and "Resend code" is a link.
- Notices and errors in the contact dialog have space under them.
- The standalone contact page includes `flat_pack/application`. Primary buttons, including "View conversation", use the theme colors.

## [0.4.1] - 2026-10-02

The dummy host mounts Site Settings and Terms. The Messages API is the same as 0.4.0.

### Added
- Dummy host gems: Site Settings `v0.1.0`, Terms and Conditions `v0.7.3`, and Publishable `v0.3.1`.
- An Admin root at `/admin`, with Site and Terms sections. Site settings follow the current Workspace.
- Dummy Flatpack pin `v0.1.196`, which Terms requires. The messages gemspec stays `~> 0.1.148`.

### Upgrade notes
- Hosts that only use Messages do not take a new dependency. Site Settings, Terms, Publishable, and Admin stay off the messages gemspec.
- No published terms are seeded, so the acceptance gate stays quiet until a live version exists.

## [0.4.0] - 2026-10-02

A mount can accept a public contact form. Signed-in people send immediately.
Signed-out people confirm an email code first, then the same send path runs once.

### Added
- `public_contact` option on `RecordingStudio::Capabilities::Messages.to`.
  Default off. `true` opts in every key. An array opts in those keys.
- `RecordingStudioMessages.public_contact_enabled?`, `begin_public_contact`,
  and `complete_public_contact`.
- `RecordingStudioMessages::PublicContact` for the code form. `submit_code!`
  and `resend!` stay on that module. The host facade does not publish them.
- `public_contact_recipient_resolver`. The first actor who is already an
  admin on the mount path calls `create_group`. Other recipients and the
  sender get an `:edit` grant, unless that grant would replace `:admin`.
- Pending rows in `recording_studio_messages_public_contact_intents`. The row
  exists only while a code is outstanding. `message_group_id` marks it sent.
  The body is cleared in that same write. A second complete returns the same
  conversation.
- Gem routes and a signed-out layout for `/public_contact`, plus
  `public_contact_form` for a host page that wants the same form.
  A successful post redirects to `GET /public_contact/sent`. A refresh
  does not send again. The sent screen centers the copy and shows a
  hero icon above the title. `public_contact_sent_icon` defaults to
  `rocket-launch`. Set it to another heroicon name, or to `nil`, to
  change that slot.
- Signed-out contact uses the Recording Studio Users public OTP API.
  A new email, an existing unconfirmed user, and an existing confirmed
  user can all send after that person proves the address. An unconfirmed
  password account is reused and confirmed in place. The password and
  `registered_with` stay as they were. The typed email is not trusted
  until `verify_otp!` succeeds. A submitted name is stored as given.
  A one-word name has no surname, and no time zone is invented. An
  existing profile is left alone. Users is not a gemspec dependency.

### Upgrade notes
- No change for hosts that do not set `public_contact`.
- To turn it on, list the mount key and set the recipient resolver.

```ruby
include RecordingStudio::Capabilities::Messages.to(
  keys: [:inbox],
  public_contact: [:inbox]
)

RecordingStudioMessages.configure do |config|
  config.public_contact_recipient_resolver = lambda { |mount_recording:, actor:|
    [User.find_by(email: "admin@admin.com")].compact
  }
end
```

- Mount Recording Studio Users and set `otp_enabled` before signed-out
  visitors can send. Run `bin/rails generate recording_studio_messages:migrations`
  and migrate.

## [0.3.1] - 2026-09-25

Hosts can lock membership on a Messages mount key so conversations under that
desk cannot invite or manage Accessible grants from the chat UI or Accessible
manage-access screens.

### Added
- `membership_locked` option on `RecordingStudio::Capabilities::Messages.to`
  (default unlocked). Pass key names or `true` for every key on that type.
- When a mount key is locked: the panel hides **+ Access** / avatars, and
  Messages wraps Accessible `access_management_authorizer` to deny
  manage/grant/update/revoke for `MessageGroup`s under that mount.
- `RecordingStudioMessages.allow_membership_change` for trusted paths
  (`CreateGroup` owner grant; Support `sync_staff_grants` later).

### Upgrade notes
- No required host changes. Default mounts stay unlocked.
- To lock a mount key (for example Support tickets):

```ruby
include RecordingStudio::Capabilities::Messages.to(
  keys: [:support],
  membership_locked: [:support]
)
```

- Trusted grants under a locked mount must call
  `RecordingStudioMessages.allow_membership_change { ... }`.
  `create_group` already does this for the owner grant.

## [0.3.0] - 2026-09-04

The dummy host now uses Recording Studio Users for shared password auth, and
Messages follows the current Recording Studio dependency family.

### Added
- Recording Studio Users `0.8.2` from
  [v0.8.2](https://github.com/bowerbird-app/RecordingStudio_users/releases/tag/v0.8.2).
- Users People, Profile, Identity, registration, confirmation, and optional OTP
  migrations in the dummy host.
- Accessible's `depends_on_recording_id` migration from `0.8.0`.

### Changed
- Dummy `/users/sign_in` and `/users/sign_up` use
  `recording_studio_user_auth_for :users`. The copied Devise login view is gone;
  Users `0.8.2` renders those screens in `layouts/recording_studio_user/auth`
  (one full-viewport centered chrome). The host `application` layout is not
  nested around them.
- Dummy Propshaft rewrites Flatpack's logical CSS `@import` paths to digested
  URLs so `variables`, `rich_text`, and `content_editor` load without 404s.
- Chat desks fill the viewport under PageNav (`h-[calc(100dvh-8.5rem)]` on the
  desk wrapper) so the composer sits on the bottom edge. The wrapper is also
  `w-full min-w-0` so Flatpack's fluid split can shrink. Chat::Layout's stacked
  Back to conversations stays visible; do not hide it and do not fork the split
  CSS.
- Dummy profile screens use core `recording_studio/default_layout`. Root
  Switchable uses its own blank shell so PageNav is not stacked. Home Staff
  desk and Inbox buttons use Flatpack `href` so they are real links.
- Dummy Tailwind scans system gem paths so mounted engine utilities such as
  `pt-16` are in the build.
- Updated Core to `4.2.1`, Accessible to `0.9.1`, Attachable to `0.5.1`,
  Notifications to `0.3.1`, Root Switchable to `0.5.1`, Admin to `2.0.2`,
  Users to `0.8.2`, and Flatpack to `0.1.148`. Root and dummy lockfiles update
  all dependencies.

### Upgrade notes
- Bump Messages to `0.3.0` and use the dependency versions above.
- Pin Flatpack with `tag: "v0.1.148"`. Chat::Layout `:split` is fluid from
  `sm` (`clamp(12rem, 30%, 16rem)` plus `minmax(0, 1fr)`). Do not restore a
  `280px` grid in Messages CSS. Pass `split_breakpoint: :md` only if a host
  must keep the old stacking point.
- The desk wrapper is `w-full min-w-0` plus the existing height class. Keep
  `min-w-0` on any flex or grid parent so the card can shrink.
- Do not hide Chat::Layout's stacked Back to conversations. Below the split
  breakpoint (`sm` by default), that control returns to the conversation list.
  Core PageNav Back leaves the desk.
- Pin Users with `tag: "v0.8.2"`. Auth screens use the gem auth layout; do not
  wrap them in a second full-viewport host shell.
- Run `bin/rails generate recording_studio_accessible:migrations`, then
  `bin/rails db:migrate`, for `depends_on_recording_id`.
- Hosts adopting Users should skip Devise sessions, registrations, and
  passwords, call `recording_studio_user_auth_for :users`, mount the Users
  engine, register People and Profile, run its migrations, and remove copied
  Devise auth views. Add the OmniAuth callbacks controller only when the User
  model is `:omniauthable`.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_messages/compare/v0.8.3...HEAD
[0.8.3]: https://github.com/bowerbird-app/RecordingStudio_messages/compare/v0.8.2...v0.8.3
[0.8.0]: https://github.com/bowerbird-app/RecordingStudio_messages/compare/v0.7.0...v0.8.0
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_messages/compare/v0.5.2...v0.6.0
[0.5.2]: https://github.com/bowerbird-app/RecordingStudio_messages/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/bowerbird-app/RecordingStudio_messages/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_messages/compare/v0.4.6...v0.5.0
[0.4.5]: https://github.com/bowerbird-app/RecordingStudio_messages/compare/v0.4.4...v0.4.5
[0.4.1]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.4.1
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.4.0
[0.3.1]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.3.1
[0.2.1]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.2.1
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_messages/releases/tag/v0.1.0
