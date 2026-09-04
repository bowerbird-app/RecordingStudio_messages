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
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.1"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.3.1"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.148"
gem "recording_studio_messages", github: "bowerbird-app/RecordingStudio_messages"
```

```ruby
# gemspec / host Gemfile constraints
gem "recording_studio", "~> 4.2"
gem "recording_studio_accessible", "~> 0.9.1"
gem "recording_studio_attachable", "~> 0.5.1"
gem "recording_studio_notifications", "~> 0.3.1"
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

Header faces come from `recording_studio_accessible_avatars`. That helper shows **+ Access** only when the grant list is empty.

## Screens

The desk opens on `message_groups#index` as Flatpack `Chat::Layout` `:split`. Accessible (`authorized?` `:view` on each `MessageGroup`) scopes the sidebar. There is no Participant list, Pundit, CanCan, or host `admin?` check. Sidebar rows are `Chat::InboxRow` only (name + latest line). The panel slot is the existing `Chat::Panel` in a `messages-desk-panel` turbo frame. Clicking a row keeps the split desk mounted: InboxRow sets `turbo_frame`, and Layout Stimulus `openPanel` / `showPanel` shows the panel under the split breakpoint (`sm` by default). Do not full-visit show from a row. Hollow empty-grant groups stay off the sidebar. Product pages use core `UsesDefaultLayout`. Put `data-theme="rounded"` on the `html` element — core often leaves it on body only, and body-only is not enough for named themes. Do not fork Chat::Panel CSS. Do not fork Chat::Layout split CSS. Flatpack `0.1.148` supplies a fluid split from `sm` and the rounded theme tokens for charcoal Send buttons and mine bubbles. Core PageNav owns page back and close. Chat::Header has no back. On stacked widths, Chat::Layout's Back to conversations returns to the list; do not hide it. Square PageNav back is Flatpack, not a Messages restyle. Do not put Sign out or Root Switchable in the page slot.

The desk fills the viewport under the host's page nav. `Chat::Layout` is `h-full`, so height lives on the wrapper (`h-[calc(100dvh-8.5rem)]`, matching core's layout padding plus page nav). The same wrapper is `w-full min-w-0` so the split can shrink inside core `main`. Messages scroll inside the panel and the composer stays on the bottom edge instead of sitting under the browser chrome. A host with different chrome passes `desk_height_class` to the partial. Do not set the height on `Chat::Layout` itself; its own `h-full` wins.

Composer uploads go through Attachable. Send replaces the thread in place over Turbo (the message list and composer). There is no Action Cable in this version. Look at the live kit: [Chat::Layout](https://flatpack.bowerbird.io/demo/chat/layout), [Chat::InboxRow](https://flatpack.bowerbird.io/demo/chat/inbox_row), [Chat::Panel](https://flatpack.bowerbird.io/demo/chat/panel), and [Chat demo](https://flatpack.bowerbird.io/demo/chat/demo).

## Dummy host

`test/dummy/` is a host that proves the gem. It is not the product.

Authenticated dummy pages use Recording Studio's shared default layout (`UsesDefaultLayout` / `recording_studio/default_layout`) so back/close chrome and Flatpack alerts come from core. Do not put Sign out or Root Switchable in that slot. The Users gem owns `/users/sign_in` and renders its auth layout (`layouts/recording_studio_user/auth`), with Flatpack CSS/JS plus Turbo.

| Field    | Value              |
|----------|--------------------|
| Email    | admin@admin.com    |
| Password | Password           |
| Email    | casey@example.com  |
| Password | Password           |

The dummy proves two mounts at once:

- `support` on Studio Workspace → Staff desk (`/staff/desk`) lands on the conversation list
- `inbox` on the Site mailbox → Inbox (`/inbox`) lands on the conversation list (one row)

Seeds add **Studio help** and **Launch notes** on support, **Site inbox** on the mailbox, Ada Staff, Casey Patron, the Relay agent, lines in each desk, and a hero-still attachment on the inbox. An empty conversation stays on the support mount so `+ Access` can be shown when opened by URL.

| Gem | Constraint | Tag | Default-branch `VERSION` |
|---|---|---|---|
| `recording_studio` | `~> 4.2` | `v4.2.1` | `4.2.1` |
| `recording_studio_accessible` | `~> 0.9.1` | `v0.9.1` | `0.9.1` |
| `recording_studio_attachable` | `~> 0.5.1` | `v0.5.1` | `0.5.1` |
| `recording_studio_notifications` | `~> 0.3.1` | `v0.3.1` | `0.3.1` |
| `flat_pack` (repo `bowerbird-app/flatpack`) | `~> 0.1.148` | `v0.1.148` | `0.1.148` |
| `recording_studio_user` (dummy host only) | `~> 0.8.2` | `v0.8.2` | `0.8.2` |

There is no `recording_studio_flatpack` gem. The UI kit is `flat_pack` from [github.com/bowerbird-app/flatpack](https://github.com/bowerbird-app/flatpack). Use the live kit at [https://flatpack.bowerbird.io/](https://flatpack.bowerbird.io/).

## Out of this version

Realtime, typing, read receipts, email as a notice channel, Admin, and Support-specific copy.

## Documentation

Engine internals stay in `docs/gem_template/` as architectural reference. The README and dummy app are the source of truth for this gem.

## Cloud Agent boot

Cloud Agent Builds run `.cursor/install.sh`, then `.cursor/fetch-skills.sh`.
The install hook provisions a cold image. On a warm snapshot it skips apt,
ruby-build, db:prepare, and tailwind when Ruby, bundle, and Postgres are
already usable. Fetch-skills always runs last. `.cursor/start.sh` starts
PostgreSQL on each boot. Rebuild with Draft off to load a new pack. See
[Cursor skills in Cloud Agents](docs/cursor-skills.md).
