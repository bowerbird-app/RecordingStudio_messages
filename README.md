# Recording Studio Messages

One gem for every conversation desk. A host enables `:messages` on a recording, then hangs one keyed mount per desk — staff help, a site inbox, or both at once.

People and agents stay actors. Membership is an Accessible grant on the conversation, not a child record.

## How it fits together

```text
Any recording that enables :messages
└── MessageMount (key: support, inbox, …)
    └── Conversation
        ├── Access grants (people and agents)
        └── Messages
            └── Attachments
```

Two desks are two mounts of this gem, not two gems.

| Type | Role | Access |
|---|---|---|
| `MessageMount` | Keyed child of a messages-enabled recording | Capability-owned |
| `MessageGroup` | A conversation | Accessible |
| `Message` | A line in that conversation | Attachable |

Notifications stay on their own tables. This gem calls `RecordingStudioNotifications.notify_each` when someone sends. Do not add a Notifications → Messages dependency.

## Install

Add the gem next to Recording Studio 4.2, Accessible, Attachable, Notifications, and Flatpack.

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.3.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.11.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.7.1"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.5.0"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.198"
gem "recording_studio_messages", github: "bowerbird-app/RecordingStudio_messages"
```

```ruby
# gemspec / host Gemfile constraints
gem "recording_studio", "~> 4.2"
gem "recording_studio_accessible", "~> 0.11"
gem "recording_studio_attachable", "~> 0.7"
gem "recording_studio_notifications", ">= 0.3.1", "< 1"
gem "flat_pack", "~> 0.1.148"
```

Then:

```bash
bundle install
bin/rails generate recording_studio_messages:install
bin/rails generate recording_studio_messages:migrations
bin/rails generate recording_studio_accessible:migrations
bin/rails generate recording_studio_attachable:migrations
bin/rails generate recording_studio_notifications:migrations
bin/rails db:migrate
```

### Upgrading to 0.3.0

Messages now follows the current Recording Studio family: Core `4.2.1`,
Accessible `0.9.1`, Attachable `0.5.1`, Notifications `0.3.1`, Users `0.8.2`,
and Flatpack `0.1.148`.

1. Install Messages `0.3.0`.
2. Run `bin/rails generate recording_studio_accessible:migrations` and migrate
   to add `depends_on_recording_id`.
3. Update host Tailwind sources for current Flatpack and Recording Studio gem
   views, then rebuild CSS.

## Enablement

Accessible on a root stays `RecordingStudio.enable_capability`. Mixins use `.to`.

```ruby
class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  RecordingStudio.enable_capability(:accessible, on: self)
  include RecordingStudio::Capabilities::Messages.to(keys: [:support])
end

class Mailbox < ApplicationRecord
  recording_studio_recordable label: "Mailbox",
                              root: false,
                              allowed_parent_types: ["Workspace"]

  include RecordingStudio::Capabilities::Messages.to(keys: [:inbox])
end
```

Lock membership on a mount key when people must not invite others from the desk
(for example a Support ticket conversation). Default is unlocked.

```ruby
include RecordingStudio::Capabilities::Messages.to(
  keys: [:support],
  membership_locked: [:support]
)
```

`membership_locked: true` locks every key listed in `keys` for that type. When
locked, the panel hides **+ Access** / avatars, and Accessible manage/grant/
update/revoke for conversations under that mount is denied (including direct
manage-access URLs). Conversation view and send auth are unchanged.

Trusted paths that must still grant under a locked mount wrap the call:

```ruby
RecordingStudioMessages.allow_membership_change do
  RecordingStudioAccessible.grant_access(...)
end
```

`create_group` already uses that for the owner grant. Support `sync_staff_grants`
will use the same helper when Support enables the lock.

Register every type the dummy or host uses:

```ruby
RecordingStudio.configure do |config|
  config.recordable_types = [
    "Workspace",
    "Mailbox",
    "RecordingStudioMessages::MessageMount",
    "RecordingStudioMessages::MessageGroup",
    "RecordingStudioMessages::Message",
    "RecordingStudioAttachable::Attachment"
  ]
end
```

`MessageGroup` enables Accessible itself. `Message` includes Attachable itself. Do not add Participant recordables.

Mount the screens:

```ruby
mount RecordingStudioMessages::Engine, at: "/recording_studio_messages"
mount RecordingStudioAccessible::Engine, at: "/recording_studio_accessible"
mount RecordingStudioAttachable::Engine, at: "/recording_studio_attachable"
```

## Public API

```ruby
mount = workspace_recording.ensure_message_mount(:support, actor: current_actor)
group = RecordingStudioMessages.create_group(mount, title: "Studio help", actor: current_actor)

RecordingStudioMessages.send_message(
  group_recording: group,
  body: "The quieter crop is in.",
  actor: current_actor,
  files: uploaded_files,
  url: staff_desk_path
)

RecordingStudioAccessible.authorized?(actor: current_actor, recording: group, role: :view)
RecordingStudioMessages.granted_actors(group)
RecordingStudioMessages.viewable_group_recordings(actor: current_actor, mount_recording: mount)
```

Sending checks Accessible `:edit` on the conversation, writes a Message, stores files through Attachable, and notifies every other granted actor with `:message_received`. The URL should open that same panel.

## Public contact

Public contact is off until a host opts in. Pass `public_contact` to `Messages.to` on the recordable that owns the mount. `true` opts in every key in `keys`. An array opts in those keys. A missing value, `false`, or `[]` leaves the mount off.

```ruby
class Mailbox < ApplicationRecord
  include RecordingStudio::Capabilities::Messages.to(
    keys: [:inbox],
    public_contact: [:inbox]
  )
end
```

The gem page is `recording_studio_messages.public_contact_path(mount_id: mount.id)`. `GET /public_contact` renders the form. A signed-out visitor sees name, email, and message. A signed-in person sees a badge with their name and the message field. The email stays off that screen. Posting a different email does not change who sends. A successful post redirects to `public_contact_sent_path`. That screen centers the copy, with a hero icon above a larger "Message sent" and "Powered by" the site name. The page loads Flatpack's application stylesheet so primary buttons use the theme colors. The site name comes from Site Settings on that root when the host has it, otherwise the root's name. "View conversation" is a primary button and leaves the dialog. In the dialog, the Contact title is hidden on this step. The icon defaults to `rocket-launch`. Set `public_contact_sent_icon` to another heroicon name, or to `nil`, to change that slot. Refreshing that page does not send again.

`public_contact_form` renders that same form on a host page. The post still leaves for the full-page code step or the sent screen.

```erb
<%= public_contact_form(mount) %>
<%= public_contact_form(mount, title: "Contact", introduction: "We reply by email.", submit_label: "Send message") %>
```

`public_contact_modal` keeps every step in a dialog on the host page. The button opens a Flatpack modal. The body is a Turbo Frame, `public_contact`, loaded from the same URL with `presentation=modal`. Compose, the code step, resend, a wrong code, and "Message sent" replace that frame. On the code step the heading is "Verify it's you", the button is "Next", "Resend code" is a link, and the Contact title is hidden. A notice or error in the dialog has space under it. On "Message sent" the Contact title is hidden. The dialog stays open. A signed-in person still skips the code. "View conversation" is a primary button and leaves the dialog. Closing during the code step does not send another code. Opening the dialog again shows that step while the code is still open. After "Message sent", opening it again starts a new note. An expired code stays in the dialog with "Send it again".

```erb
<%= public_contact_modal(mount) %>
<%= public_contact_modal(mount, title: "Contact", introduction: "We reply by email.", submit_label: "Send message") %>
```

One dialog per page. A normal visit to `public_contact_path`, including `presentation=modal` without the frame header, still uses the centered page. The page posts are full document posts. Coming back to the host page does not restore an open dialog.

Include `RecordingStudioMessages::PublicContactHelper` on the host controller that embeds either helper. The defaults are title "Contact", no introduction, and submit label "Send message". Those strings follow I18n (`recording_studio.messages.contact.*`). Passing `title`, `introduction`, or `submit_label` still overrides the locale. The dialog needs Turbo on that page.

Signed-in `begin_public_contact` skips OTP, ignores the submitted email and name, and returns the conversation. The title is `actor.name` when present, otherwise the titleized email local-part, otherwise "Message".

Signed-out contact needs Recording Studio Users with `otp_enabled`. Users is not a dependency of this gem. The host mounts Users, turns OTP on, and registers the notification channels those codes use. Registration defaults to email. Login defaults to email and push.

A signed-out send proves the typed address before anything is delivered. A new email gets a registration code and a new user. An existing unconfirmed user, whether that account was created with a password or with a code, is reused and gets a registration code. An existing confirmed user who can sign in gets a login code. This gem does not create a second user for an address that already exists. The address on the pending row is not trusted until `verify_otp!` succeeds.

Users confirms the account through `complete_email_proof!`. That call stores the submitted name when the person has no profile yet. "Ada Lovelace" is stored as Ada and Lovelace. "Madonna" is stored as Madonna with no surname. Messages does not invent a surname or a time zone, and it does not revise a profile that already exists. `registered_with` stays the way the account was created, so a password still signs in after the code confirms the email.

```ruby
outcome = RecordingStudioMessages.begin_public_contact(
  mount_recording: mount,
  name: "Ada Lovelace",
  email: "ada@example.com",
  body: "The quieter crop is in.",
  current_actor: current_actor,
  request: request,
  session: session
)

if outcome.awaiting_verification?
  intent = outcome.intent
else
  group = outcome.group_recording
end

group = RecordingStudioMessages.complete_public_contact(intent: intent, actor: verified_user)
```

`complete_public_contact` is the host call after the code has been verified. Calling it again returns the same conversation and does not send a second message. The code form calls `RecordingStudioMessages::PublicContact.submit_code!` and `resend!` itself. Those two methods are not on the host facade.

Set `public_contact_recipient_resolver` to a callable. `begin` and `complete` call it with `mount_recording:` and `actor:`. A value that does not respond to `call` is ignored. The first recipient who is already an admin on the mount path is the actor for `create_group`. Admin on an ancestor counts. Every other recipient gets an `:edit` grant on the new conversation. The sender gets `:edit` too, unless they are that admin. A second grant would replace `:admin`. `create_group` does not notify. `send_message` notifies the other direct grants, which is why those grants exist. There is no file field on this form.

```ruby
RecordingStudioMessages.configure do |config|
  config.public_contact_recipient_resolver = lambda { |mount_recording:, actor:|
    [User.find_by(email: "admin@admin.com")].compact
  }
  config.public_contact_sent_icon = "rocket-launch"
end
```

If nobody in that list is already an admin on the mount path, `begin` raises `RecordingStudioMessages::Error` with "Nobody can receive this message." and does not send a code.

```text
form
└── pending intent, body stored for 24 hours
    └── email code
        └── verify_otp!
            └── confirmed user, profile written from the submitted name when none exists
                └── create_group as the admin recipient
                    └── :edit grants
                        └── send_message
                            └── intent fulfilled, body cleared
```

The pending row expires 24 hours after `begin`. An expired row does not send. Once the conversation exists, the body is cleared and `message_group_id` is set in the same write as the group, the grants, and the message. A retry of that intent returns the conversation. It cannot send twice. The form does not accept attachments.

Header faces come from `recording_studio_accessible_avatars`. That helper shows **+ Access** only when the grant list is empty. On a `membership_locked` mount the header omits that control and Accessible refuses membership changes (see Enablement).

## Screens

The desk opens on `message_groups#index` as Flatpack `Chat::Layout` `:split`. Accessible (`authorized?` `:view` on each `MessageGroup`) scopes the sidebar. There is no Participant list, Pundit, CanCan, or host `admin?` check. Sidebar rows are `Chat::InboxRow` only (name + latest line). The panel slot is the existing `Chat::Panel` in a `messages-desk-panel` turbo frame. Clicking a row keeps the split desk mounted: InboxRow sets `turbo_frame`, and Layout Stimulus `openPanel` / `showPanel` shows the panel under the split breakpoint (`sm` by default). Do not full-visit show from a row. Hollow empty-grant groups stay off the sidebar. Product pages use core `UsesDefaultLayout`. Put `data-theme="rounded"` on the `html` element — core often leaves it on body only, and body-only is not enough for named themes. Do not fork Chat::Panel CSS. Do not fork Chat::Layout split CSS. Flatpack `0.1.148` supplies a fluid split from `sm` and the rounded theme tokens for charcoal Send buttons and mine bubbles. Core PageNav owns page back and close. Chat::Header has no back. On stacked widths, Chat::Layout's Back to conversations returns to the list; do not hide it. Square PageNav back is Flatpack, not a Messages restyle. Do not put Sign out or Root Switchable in the page slot.

The desk fills the viewport under the host's page nav. `Chat::Layout` is `h-full`, so height lives on the wrapper (`h-[calc(100dvh-8.5rem)]`, matching core's layout padding plus page nav). The same wrapper is `w-full min-w-0` so the split can shrink inside core `main`. Messages scroll inside the panel and the composer stays on the bottom edge instead of sitting under the browser chrome. A host with different chrome passes `desk_height_class` to the partial. Do not set the height on `Chat::Layout` itself; its own `h-full` wins.

Composer uploads go through Attachable. Send replaces the thread in place over Turbo (the message list and composer). There is no Action Cable in this version. Look at the live kit: [Chat::Layout](https://flatpack.bowerbird.io/demo/chat/layout), [Chat::InboxRow](https://flatpack.bowerbird.io/demo/chat/inbox_row), [Chat::Panel](https://flatpack.bowerbird.io/demo/chat/panel), and [Chat demo](https://flatpack.bowerbird.io/demo/chat/demo).

## Dummy host

`test/dummy/` is a host that proves the gem. It is not the product.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

Authenticated dummy pages use Recording Studio's shared default layout (`UsesDefaultLayout` / `recording_studio/default_layout`) so back/close chrome and Flatpack alerts come from core. Do not put Sign out or Root Switchable in that slot. The Users gem owns `/users/sign_in` and renders its auth layout (`layouts/recording_studio_user/auth`), with Flatpack CSS/JS plus Turbo.

| Field    | Value              |
|----------|--------------------|
| Email    | admin@admin.com    |
| Password | Password           |
| Email    | casey@example.com  |
| Password | Password           |

The dummy switches English and French with Recording Studio Internationalization. The compact language selector sits in PageNav. Conversation titles and seeded message bodies stay in the language they were written.

The dummy proves two mounts at once:

- `support` on Studio Workspace → Staff desk (`/staff/desk`) lands on the conversation list
- `inbox` on the Site mailbox → Inbox (`/inbox`) lands on the conversation list (one row)

Home also has a Contact button to that inbox's public form, and an Admin button. Admin mounts Site Settings (`v0.1.3`) and Terms and Conditions (`v0.8.1`). Publishable is on `v0.6.0` (i18n release; Terms still allows `~> 0.4`); it serves public `/terms/:uuid/:slug` and `/privacy/:uuid/:slug`. Terms requires Flatpack `>= 0.1.196`. Dummy pins `v0.1.213`. The messages gemspec stays `~> 0.1.148`.

Seeds add **Studio help** and **Launch notes** on support, **Site inbox** on the mailbox, Ada Staff, Casey Patron, the Relay agent, lines in each desk, and a hero-still attachment on the inbox. An empty conversation stays on the support mount so `+ Access` can be shown when opened by URL.

| Gem | Constraint | Tag | Default-branch `VERSION` |
|---|---|---|---|
| `recording_studio` | `~> 4.2` | `v4.3.0` | `4.3.0` |
| `recording_studio_accessible` | `~> 0.11` | `v0.11.1` | `0.11.0` |
| `recording_studio_attachable` | `~> 0.7` | `v0.7.1` | `0.7.0` |
| `recording_studio_notifications` | `>= 0.3.1, < 1` | `v0.5.0` | `0.5.0` |
| `flat_pack` (repo `bowerbird-app/flatpack`) | `~> 0.1.148` | `v0.1.207` | `0.1.207` |
| `recording_studio_user` (dummy host only) | `~> 0.16` | `v0.16.0` | `0.16.0` |

There is no `recording_studio_flatpack` gem. The UI kit is `flat_pack` from [github.com/bowerbird-app/flatpack](https://github.com/bowerbird-app/flatpack). Use the live kit at [https://flatpack.bowerbird.io/](https://flatpack.bowerbird.io/).

## Internationalization

The gem ships **English only** in `config/locales/en.yml`. Keys nest under `recording_studio.messages.*`:

```ruby
t("recording_studio.messages.contact.submit")
t("recording_studio.messages.composer.placeholder")
t("recording_studio.messages.flashes.sent")
```

Hosts own other languages. Copy `recording_studio.messages.*` into `config/locales/<locale>.yml` and list that locale in `config.i18n.available_locales`. Do not add `RecordingStudio_Internationalization` as a dependency of this gem — it is optional on the host (the dummy uses it to switch English/French).

Conversation titles, message bodies, attachment names, and notification titles written to the database are data and stay in the language they were stored. OTP mail is owned by Recording Studio Users.

## Out of this version

Realtime, typing, read receipts, email as a notice channel, and Support-specific copy. The dummy host mounts Admin for Site Settings and Terms. Messages itself does not ship an admin screen.

## Documentation

Engine internals stay in `docs/gem_template/` as architectural reference. The README and dummy app are the source of truth for this gem.

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. If `RAILS_MASTER_KEY` is set, it writes gitignored
`test/dummy/config/master.key` so dummy credentials decrypt. Fetch-skills
always runs last. `.cursor/start.sh` starts
PostgreSQL on each boot. Rebuild with Draft off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).
