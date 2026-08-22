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
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.7.0"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "0.4.0"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.2.5"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.133"
gem "recording_studio_messages", github: "bowerbird-app/RecordingStudio_messages"
```

```ruby
# gemspec / host Gemfile constraints
gem "recording_studio", "~> 4.2"
gem "recording_studio_accessible", "~> 0.7.0"
gem "recording_studio_attachable", "~> 0.4"
gem "recording_studio_notifications", "~> 0.2.5"
gem "flat_pack", "~> 0.1.133"
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

## Enablement

Accessible on a root stays `RecordingStudio.enable_capability`. Mixins use `.to`.

```ruby
class Workspace < ApplicationRecord
  recording_studio_recordable label: "Workspace", root: true
  RecordingStudio.enable_capability(:accessible, on: self)
  include RecordingStudio::Capabilities::Messages.to
end

class Mailbox < ApplicationRecord
  recording_studio_recordable label: "Mailbox",
                              root: false,
                              allowed_parent_types: ["Workspace"]

  include RecordingStudio::Capabilities::Messages.to
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
```

Sending checks Accessible `:edit` on the conversation, writes a Message, stores files through Attachable, and notifies every other granted actor with `:message_received`. The URL should open that same panel.

Header faces come from `recording_studio_accessible_avatars`. That helper shows **+ Access** only when the grant list is empty.

## Screens

v1 is one Flatpack `Chat::Panel` (header, messages, composer). There is no group list, no second inbox, and no Support-specific copy. Product pages use core `UsesDefaultLayout` and `html data-theme="rounded"`. Core owns back and close. Do not put Sign out or Root Switchable in the page slot.

Composer uploads go through Attachable. Look at the live kit: [Chat::Panel](https://flatpack.bowerbird.io/demo/chat/panel) and [Chat demo](https://flatpack.bowerbird.io/demo/chat/demo).

## Dummy host

`test/dummy/` is a host that proves the gem. It is not the product.

Authenticated dummy pages use Recording Studio's shared default layout (`UsesDefaultLayout` / `recording_studio/default_layout`) so back/close chrome and Flatpack alerts come from core. Root Switchable sits in that chrome. Devise sign-in keeps `layouts/application` and still loads Flatpack CSS/JS plus Turbo.

| Field    | Value              |
|----------|--------------------|
| Email    | admin@admin.com    |
| Password | Password           |
| Email    | casey@example.com  |
| Password | Password           |

The dummy proves two mounts at once:

- `support` on Studio Workspace → Staff desk (`/staff/desk`)
- `inbox` on the Site mailbox → Inbox (`/inbox`)

Seeds add both conversations, Ada Staff, Casey Patron, the Relay agent, lines in each desk, and a hero-still attachment on the inbox. An empty conversation stays on the support mount so `+ Access` can be shown.

| Gem | Constraint | Tag | Default-branch `VERSION` |
|---|---|---|---|
| `recording_studio` | `~> 4.2` | `v4.2.0` | `4.2.0` |
| `recording_studio_accessible` | `~> 0.7.0` | `v0.7.0` | `0.7.0` |
| `recording_studio_attachable` | `~> 0.4` | `0.4.0` | `0.4.0` |
| `recording_studio_notifications` | `~> 0.2.5` | `v0.2.5` | `0.2.5` |
| `flat_pack` (repo `bowerbird-app/flatpack`) | `~> 0.1.133` | `v0.1.133` | `0.1.134` (untagged) |

There is no `recording_studio_flatpack` gem. The UI kit is `flat_pack` from [github.com/bowerbird-app/flatpack](https://github.com/bowerbird-app/flatpack). Use the live kit at [https://flatpack.bowerbird.io/](https://flatpack.bowerbird.io/).

## Out of this version

Group-list layout, realtime, typing, read receipts, email as a notice channel, Admin, and Support-specific copy.

## Documentation

Engine internals stay in `docs/gem_template/` as architectural reference. The README and dummy app are the source of truth for this gem.
