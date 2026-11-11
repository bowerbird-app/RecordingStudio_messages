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

Notifications stay on their own tables. This gem calls `RecordingStudioNotifications.notify_each` when someone sends. Do not add a Notifications → Messages dependency. Message group tags are a join table next to this tree, not children. Hosts choose the keys. Message references are the same kind of fact table. They point a line at another recording. They are not children.

## Install

Add the gem next to Recording Studio 6.1, Accessible, Attachable, Notifications, and Flatpack.

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.1"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.21.1"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.13.1"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.349"
gem "view_component", "4.19.0"
gem "recording_studio_messages", github: "bowerbird-app/RecordingStudio_messages"
```

```ruby
# gemspec / host Gemfile constraints
gem "recording_studio", ">= 6.1.0"
gem "recording_studio_accessible", "~> 0.24"
gem "recording_studio_attachable", "~> 0.13"
gem "recording_studio_notifications", ">= 0.3.1", "< 1"
gem "flat_pack", ">= 0.1.349"
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

### Composer actions and message cards

Other gems can add a + menu item and a card under a line. This gem does not name those gems. Register in a host or gem initializer.

`register_composer_action` adds an item next to **Upload files or images**. The `if:` proc receives the conversation, the current actor, and the desk mount. A missing `if:` keeps the item. The + menu renders every item that returns true.

Messages owns the modal. It renders one Flatpack modal per item (id, title from `title:` or `label`, close control, `size:` default `:sm`). Pass exactly one of `partial:` or `src:`. `partial:` is a light body. `src:` is a URL (or a proc of `(group, actor, mount)` that returns one). Search and pickers should use `src:` with their own endpoint and their own Accessible checks. The shell loads that URL in a Turbo frame with `loading: lazy` when the modal opens. The body receives `group_recording`, `actor`, `mount`, and `action`. Do not render `FlatPack::Modal` or match a `modal_id` in the gem.

The body inserts into the composer with a document event. The composer closes the open action modal when that event fires:

```js
window.dispatchEvent(new CustomEvent("messages:composer-insert", {
  bubbles: true,
  detail: {
    reference: { recording_id: "…", title: "Brand notes", url: "/pages/…" }
  }
}))
```

A `reference` becomes a removable chip in the composer attachments slot and submits as `message[references]`. It does not insert title or URL text. Optional `text` still appends to the box for hosts that need a paste. Do not parse references out of the body.

`send_message(..., references:)` writes those rows in the same commit as the line. Each value may be a recording, an id, or `{ recording_id:, title:, url: }`. The sender must have Accessible `:view` on the target. The target must sit in the subtree of the mount's parent (the messages-enabled recording). The stored body stays as sent. A blank body is allowed when a reference or file is present. `preview_text(body, references:)` supplies notice and inbox fallback copy from the titles when the body is blank.

`register_message_embed` remains an override for a recordable class name. Unregistered types use Flatpack `Chat::LinkCard` in their own MessageGroup `messages` slot below the bubble. Render loads one page of references in one query, then filters with Accessible `recordings_for` on each distinct parent. Missing, trashed, and unseen targets still render a slot with no `href`, so the kit paints Unavailable. They do not leak a title.

```ruby
RecordingStudioMessages.register_composer_action(
  :attach_page,
  label: "Attach a page",
  icon: "document-text",
  src: ->(_group, _actor, mount) { dummy_page_picker_path(mount_id: mount.id) },
  if: ->(_group, actor, mount) { actor.present? && mount.present? }
)

RecordingStudioMessages.register_message_embed("Page", partial: "dummy/page_embed")

RecordingStudioMessages.send_message(
  group_recording: group,
  body: "See this page.",
  actor: current_actor,
  references: [{ recording_id: page.id, title: "Brand notes", url: "/pages/#{page.id}" }]
)
```

Pin `recording_studio_messages/controllers` in the host importmap so `recording-studio-messages--composer` loads. The dummy pin sits next to the Admin pin. Message bodies auto-link `http` and `https` only. The helper escapes first, then wraps. `javascript:` and `data:` stay text.

The dummy staff desk proves the + item, a lazy picker with **Find a page**, a pending composer chip, Brand notes LinkCards (outgoing and incoming), and the Unavailable card. Screenshots live in `docs/screenshots/composer-pending-reference-desktop.png`, `docs/screenshots/message-link-card-outgoing-desktop.png`, `docs/screenshots/message-link-card-incoming-desktop.png`, `docs/screenshots/message-link-card-unavailable-desktop.png`, and the matching `*-mobile.png` files.

### Upgrading to 0.22.0

Messages `0.22.0` adds `access:` on `Messages.to`. Existing mounts stay `:members`. Conversations you already granted stay granted. There is no migration.

1. Install Messages `0.22.0`.
2. On a desk under an owner root, add `access: :inherited` to that type's `Messages.to`. Leave a shared membership desk on the default.
3. Keep calling `create_group(mount, title:, actor:, tags:)`. Pass `admin:` only on `:members` when someone other than the creator should own the conversation. `:inherited` ignores `admin:` and writes no staff grant.
4. Public contact on `:inherited` no longer needs an opener. The resolver may return no one. It only drives `:message_received` notices. The sender still gets a direct `:edit` grant, so they see the thread in `/my_messages`. Team members who only inherit access do not.

### Upgrading to 0.21.0

Messages `0.21.0` adds composer actions, typed recording references, and safe URL auto-linking. Conversation desks, unread cursors, seen faces, and the v0.17–v0.19 host slots stay as they are.

1. Install Messages `0.21.0`.
2. Run `bin/rails generate recording_studio_messages:migrations` and `bin/rails db:migrate`.
3. Pin `app/javascript/recording_studio_messages/controllers` in the host importmap (`under: "controllers/recording_studio_messages"`).
4. Pin Flatpack git tag `v0.1.349` and rebuild Tailwind. The gemspec floor is `flat_pack >= 0.1.349`.
5. Call `register_composer_action` from a host or gem initializer when you need a + item. Use `src:` for search and pickers. Leave actions unregistered to keep the upload-only + menu. Call `register_message_embed` only when a typed card should replace LinkCard. Auto-linking still runs.

The migration creates `recording_studio_message_references` (`message_recording_id`, `target_recording_id`, unique pair). Tags never grant access. Accessible does not learn about Messages.

### Upgrading to 0.20.1

Messages `0.20.1` leaves the conversation list header without a mount name. The unread toggle, host toolbar slot, and open conversation title stay as they are.

1. Install Messages `0.20.1`. No new migration on top of 0.20.0.
2. Mount desks and `/my_messages` no longer put a name in that list header. Page titles are unchanged.
3. Define `messages_list_header_title(mount:, actor:)` when the host wants a name there. `mount` is nil on `/my_messages`. Leave it undefined to keep the header as controls only.

```ruby
def messages_list_header_title(mount:, actor:)
  return if actor.blank?
  return messages_t("inbox.my_title") if mount.blank?

  messages_inbox_title(mount)
end
```

### Upgrading to 0.20.0

Messages `0.20.0` keeps bubble times in the DOM and shows them on hover, tap, or focus. A `Chat::DateDivider` with the clock sits between consecutive lines when the gap is more than 15 minutes, in addition to the existing day breaks. Last-line status is `Chat::SentAt` until someone else has read it, then the seen faces move into the group `status` slot. The v0.17 header hooks, v0.18 rename, and v0.19 toolbar/unread stay as they are.

1. Install Messages `0.20.0`. No new migration on top of 0.19.0.
2. Pin Flatpack git tag `v0.1.347`. The gemspec floor is `flat_pack >= 0.1.347`. Reload Flatpack CSS. The timestamp clip lives in kit CSS, so do not rebuild Tailwind for it. Rebuild only if the host is still on a Flatpack older than `v0.1.346` that lacked the bubble radius tokens.
3. `pin_all_from` on Flatpack controllers already loads `flat-pack--chat-timestamp-reveal`. If the host copied `build_stimulus.js`, register `ChatTimestampRevealController` as `flat-pack--chat-timestamp-reveal`.
4. Leave `time_break_after` unset to keep the 15-minute gap. Set `RecordingStudioMessages.configure { |c| c.time_break_after = 20.minutes }` (or `20` for 20 minutes) to change it.

```ruby
RecordingStudioMessages.configure do |config|
  config.time_break_after = 15.minutes
end
```

### Upgrading to 0.19.0

Messages `0.19.0` filters a mount inbox to unread conversations and opens the list header as a host toolbar slot. The v0.17 panel header hooks, the v0.18 rename, unread cursors, and seen faces stay as they are.

1. Install Messages `0.19.0`. No new migration on top of 0.18.0.
2. Mount desks and `/my_messages` both show the round unread toggle above the conversation list. `/my_messages` still shows the unread badge next to it.
3. Define `messages_list_toolbar(mount:, actor:)` when the host needs a control beside that toggle. Check Accessible in the host. Messages does not. `mount` is nil on `/my_messages`.

```ruby
def messages_list_toolbar(mount:, actor:)
  return unless mount&.recordable&.key.to_s == "support"
  return unless RecordingStudioAccessible.authorized?(
    actor: actor,
    recording: mount.parent_recording,
    role: :view
  )

  render "support/new_conversation", mount: mount, actor: actor
end
```

`viewable_group_recordings(..., unread: true)` is the same filter the mount toggle uses. `after:` and `limit:` still page that list.

### Upgrading to 0.18.0

Messages `0.18.0` lets people with Accessible edit access rename the open conversation from the panel header. The name is still `MessageGroup#title`. Sending, unread cursors, seen faces, and the v0.17 header hooks stay as they are.

1. Install Messages `0.18.0`. No new migration on top of 0.17.1.
2. Use Flatpack `>= 0.1.346` (`InlineEdit`). Hosts already on the 0.17.1 pin are fine.
3. Pin `flat_pack/copy` next to the existing Flatpack controller pins. Without it, clicking the name does nothing.
4. People with `:edit` or stronger click the name, type, and save on blur or Enter. `:view` still sees a plain title. Tags never grant access.

`rename_group(group_recording:, title:, actor:)` is the same write the panel uses. It strips whitespace, requires a name, caps it at 120 characters, and revises the conversation.

```ruby
RecordingStudioMessages.rename_group(
  group_recording: group,
  title: "Studio help",
  actor: current_actor
)
```

### Upgrading to 0.17.1

Messages `0.17.1` pins Flatpack `v0.1.346` so rounded chat bubbles use `--chat-message-radius`, `--chat-message-padding-x`, and `--chat-message-padding-y`. Default theme bubbles stay as they were. Conversation desks, unread cursors, and seen faces stay as they are.

1. Install Messages `0.17.1`. No new migration on top of 0.17.0.
2. Pin Flatpack git tag `v0.1.346`. Gemspec floor stays `flat_pack >= 0.1.331`.
3. Rebuild host Tailwind.

### Upgrading to 0.17.0

Messages `0.17.0` adds three overridable panel helpers. Conversation desks, unread cursors, and seen faces stay as they are.

1. Install Messages `0.17.0`. No new migration on top of 0.16.0.
2. Leave the helpers undefined if the open conversation header should stay as it is.
3. Define a helper with the same name when the host needs a control in that slot. Check Accessible in the host. Messages does not.

```ruby
def messages_panel_right_header(group_recording, actor:, mount:)
  return unless mount&.recordable&.key.to_s == "support"
  return unless RecordingStudioAccessible.authorized?(
    actor: actor,
    recording: ticket_for(group_recording),
    role: :view
  )

  render "support/ticket_status", group_recording: group_recording, actor: actor
end
```

`ticket_for` is host code. This gem has no ticket type.

### Upgrading to 0.16.0

Messages `0.16.0` can show who has caught up to the latest line. Unread cursors, `#show` mark-read, and tags stay as they are. The check mark next to every timestamp is gone.

1. Install Messages `0.16.0`. No new migration on top of 0.15.0.
2. Leave `read_receipts` off (the default) if seen faces should stay hidden.
3. Set `RecordingStudioMessages.configure { |c| c.read_receipts = true }` to show up to three `Avatar` faces in the last group's `status` slot, then `+N`. Earlier lines have none. Flatpack `AvatarGroup` always overlaps, so the row is a `Cluster` of `Avatar`s instead. When nobody else has caught up, that slot is `Chat::SentAt`.

`seen_by(group_recording:, viewer:)` is the same lookup the thread uses. A reader counts when `last_read_message_recording_id` is the latest message, or `last_read_at` is at least that message's time. It only includes people who currently have a ranked Accessible grant on that conversation. Tags never grant access. Opening a conversation still marks that person read on `#show` only. Other open windows pick up new faces on the next render.

```ruby
RecordingStudioMessages.configure do |config|
  config.read_receipts = true
end

RecordingStudioMessages.seen_by(group_recording: group, viewer: current_actor)
```

### Upgrading to 0.15.0

Messages `0.15.0` stores a private read cursor per person per conversation. Sending, delivery, and conversation shape are unchanged. Existing public methods keep the same arguments. Unread is a fact table, not a recording.

1. Install Messages `0.15.0`.
2. Run `bin/rails generate recording_studio_messages:migrations` and `bin/rails db:migrate`.
3. Link `unread_count(actor:)` to a nav badge when you want a number. `/my_messages` already shows a row dot when unread, a round unread filter, and `messages-unread-badge`. An explicit conversation open updates that row's avatar and the badge over Turbo. It does not remount the list.

The migration creates `recording_studio_message_reads` and backfills current membership as read (`last_read_at = last_message_at`) in batches. After that, a conversation is unread when someone else sends, until that person opens it (`#show`). A `/my_messages` row click requests a Turbo stream. The stream marks the conversation read, then updates that row's unread avatar and `messages-unread-badge`. A turbo-frame open still marks read. Opening the index does not mark the auto-selected conversation read. Opening a conversation also marks that person's unread `:message_received` notices for it. Notifications does not depend on Messages.

Read state is private until the host sets `read_receipts`.

```ruby
RecordingStudioMessages.unread_count(actor: current_actor)
RecordingStudioMessages.my_group_recordings(actor: current_actor, unread: true, limit: 50)
RecordingStudioMessages.mark_read(group_recording: group, actor: current_actor)
RecordingStudioMessages.unread?(group_recording: group, actor: current_actor)
```

### Upgrading to 0.14.0

Messages `0.14.0` lets the public contact popup carry the same tag hash as `begin_public_contact`. The helpers sign that hash into `tag_token`. The controller verifies the token, then checks that each tagged recording is live and inside the mount parent's tree. Tags still do not grant access. Keep the 0.13.0 inbox.

1. Install Messages `0.14.0`. No new migration on top of 0.13.0.
2. Pass `tags:` to `public_contact_form` or `public_contact_modal` when the host already has the recordings.
3. Leave `begin_public_contact(tags:)` as it is for host Ruby that does not use the popup.

Omit `tags:` and the popup matches 0.12.0.

### Upgrading to 0.13.0

Messages `0.13.0` adds a cross-mount inbox of conversations the current actor was added to. Accessible still decides who can open a conversation. The mount desk, `ListGroups`, and `viewable_group_recordings` stay as they are. Keep the 0.11.1 development pins and the 0.11.2 lockfile floors. The Accessible floor stays `~> 0.24`.

1. Install Messages `0.13.0`.
2. Run `bin/rails generate recording_studio_messages:migrations` and `bin/rails db:migrate`.
3. Link to `my_messages_path` from the host. The engine route has no `mount_id`.
4. Call `my_group_recordings(actor:)` when you need that same list in your own screen. Pass `limit:` and `after:` to page it.

The new migration adds `last_message_at` on `recording_studio_message_groups` and backfills it from each conversation's newest kept message. `send_message` keeps the column current.

Inherited view on a workspace or mount still opens the mount desk. It does not put a conversation in this inbox. Only a kept, effective direct grant on the conversation does. Tags are not involved. Unread is a private cursor as of 0.15.0.

```ruby
RecordingStudioMessages.my_group_recordings(actor: current_actor).limit(50)
```

### Upgrading to 0.12.0

Messages `0.12.0` tags a conversation in the same commit that creates it, lists those conversations without an actor, and can pass the same hash into public contact. Accessible still decides who can open a conversation. Keep the 0.11.1 development pins and the 0.11.2 lockfile floors. The Accessible floor stays `~> 0.24`.

1. Install Messages `0.12.0`.
2. Run `bin/rails generate recording_studio_messages:migrations` and `bin/rails db:migrate`.
3. Pass `tags:` to `create_group` and `begin_public_contact` when the recordings are already known.
4. Send counts that have no actor to `tagged_group_recordings`.
5. Add `tags:` or `**` to the public-contact resolver when the desk depends on those recordings. A lambda that only takes `mount_recording:` and `actor:` keeps working.

The new migration adds `tags` `jsonb` on `recording_studio_messages_public_contact_intents`, not null, default `{}`. Leave that column alone. `complete_public_contact` reads it. If a tagged recording or the contact mount is missing or trashed at complete, start a new message.

`tagged_group_recordings` is not an ACL. A conversation with matching tags is included when the caller has no grant. `press_center` and `press_kit` in the samples are examples. A later kit is another key in the same hash.

A failed owner grant now removes the new conversation. In `0.10.0`, `record!` could commit the conversation and a later grant failure could leave it in place.

```ruby
group = RecordingStudioMessages.create_group(
  mount,
  title: "Center desk",
  actor: editor,
  tags: { "press_center" => press_center, "press_kit" => press_kit }
)

RecordingStudioMessages.tagged_group_recordings(
  mount_recording: mount,
  tags: { "press_center" => press_center }
).count
```

### Upgrading to 0.11.1

Messages `0.11.1` checks Accessible `:view` on the mount parent before the engine desk renders, and refreshes development pins. Gemspec floors stay `recording_studio >= 6.1.0` and `flat_pack >= 0.1.331`.

1. Install Messages `0.11.1`.
2. Pin Recording Studio `v6.3.0` and Flatpack `v0.1.341`. Gemfile constraints stay `recording_studio >= 6.1.0` and `flat_pack >= 0.1.331`. Accessible stays `v0.24.1`. Notifications stays `v0.13.1`, Metrics `v0.6.1`, Logs `v0.7.0`, Trashable `v0.11.3`, Cache `v0.5.1` (`~> 0.5`). Users stays `v0.26.3` (0.27.0 renders sign-in in Default Layout). Root Switchable stays `v0.10.0` (0.11.4 drops `layouts/recording_studio_root_switchable/blank`). Admin stays `v2.6.2`. Terms and Conditions has no tag that allows Recording Studio 6.x, so the dummy still loads `test/support/widen_recording_studio_requirement.rb`.
3. There is no Messages migration.
4. Engine `GET /message_groups?mount_id=` 404s without parent view. Conversation `#show` still redirects without a group grant.

### Upgrading to 0.11.0

Messages `0.11.0` pins Flatpack `0.1.331` and uses kit APIs for contact headings, chat TextArea, and modal Turbo cache. Core stays `6.1.0`. Gemspec floors are `recording_studio >= 6.1.0` and `flat_pack >= 0.1.331`.

1. Install Messages `0.11.0`.
2. Pin Flatpack git tag `v0.1.331`. Reload kit CSS and JavaScript. Rebuild host Tailwind.
3. There is no Messages migration.
4. Drop a host `turbo:before-cache` close/unlock on Flatpack Modal. Keep a title unhide if you hid the modal heading. Pass `variant: :chat` on a composer TextArea.

### Upgrading to 0.10.0

Messages `0.10.0` adds message group tags. A conversation can join to host recordings by a host-chosen key. `ListGroups` can require those tags. Accessible still decides who can see the conversation. Core stays `6.1.0`. The Accessible floor stays `~> 0.24`.

1. Install Messages `0.10.0`.
2. Run `bin/rails generate recording_studio_messages:migrations` and `bin/rails db:migrate`.
3. Tag after create, or from a host callback. There is no picker in this gem.

```ruby
RecordingStudioMessages.tag(group, key: "press_center", recording: press_center)
RecordingStudioMessages.tag(group, key: "press_kit", recording: press_kit)

RecordingStudioMessages.viewable_group_recordings(
  actor: current_actor,
  mount_recording: mount,
  tags: { "press_center" => press_center, "press_kit" => press_kit }
)
```

`press_kit` in that hash is optional at the call site. Omit a key to skip that filter. Keys are yours. This gem does not hardcode press names.

### Upgrading to 0.9.3

Messages `0.9.3` lists conversations under one mount with Accessible `recordings_for`. Core stays `6.1.0`. Attachable stays `0.21.1`. Notifications stays `0.13.1`. Users stays `0.26.3`. Metrics stays `0.6.1`. Flatpack stays `0.1.329`. Gemspec floors stay `recording_studio >= 6.1.0` and `flat_pack >= 0.1.315`. The Accessible floor is `~> 0.24`.

1. Install Messages `0.9.3`.
2. Pin Accessible `~> 0.24` and git tag `v0.24.0`. That gem depends on `recording_studio_trashable ~> 0.10` and allows `recording_studio ~> 6.1`.
3. Pass a mount to `viewable_group_recordings`. A blank mount returns an empty list. Hosts that already pass a mount keep the same visible conversations.
4. There is no Messages migration. Accessible `0.24.0` ships the same migrations as `0.21.0`.

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

  include RecordingStudio::Capabilities::Messages.to(
    keys: [:inbox],
    access: :inherited,
    public_contact: [:inbox]
  )
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

### Choose an access mode

`Messages.to` takes `access:`. Callers of `create_group` and public contact do not pick a mode. They read it from the mount's parent type.

| Mode | When | `create_group` | Public contact |
|---|---|---|---|
| `:members` (default) | A shared desk whose people are the conversation members | Grants `:admin` to `admin:` when passed, otherwise to the creating actor | Needs an opener. The first resolver recipient who is already an admin on the mount path opens the conversation. Other resolver recipients and the sender get `:edit`. An empty list, or a list with no admin, raises "Nobody can receive this message." |
| `:inherited` | A desk under an owner root (a workspace or similar) | Writes the conversation under the mount and grants nobody | No opener. The sender gets a direct `:edit` grant on that conversation only. The resolver is notification-only and may return nothing. That error never appears. |

Team members on an `:inherited` mount see and reply through Accessible inheritance (`:view` reads, `:edit` or stronger creates and replies). A staff member who starts a thread gets no direct grant, so the thread does not appear in `/my_messages`. Explicit **+ Access** grants still do. Tags never grant access. Send and view still go through Accessible. Accessible does not learn about Messages.

Existing direct grants stay as they are. There is no migration. Hosts that already mint staff grants on every new conversation under an owner root should add `access: :inherited` so new conversations stop doing that.

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
RecordingStudioMessages.tag(group, key: "press_center", recording: press_center)
RecordingStudioMessages.untag(group, key: "press_center")
RecordingStudioMessages.viewable_group_recordings(
  actor: current_actor,
  mount_recording: mount,
  tags: { "press_center" => press_center },
  unread: true
)
RecordingStudioMessages.my_group_recordings(actor: current_actor)
RecordingStudioMessages.my_group_recordings(actor: current_actor, unread: true)
RecordingStudioMessages.unread_count(actor: current_actor)
RecordingStudioMessages.mark_read(group_recording: group, actor: current_actor)
RecordingStudioMessages.unread?(group_recording: group, actor: current_actor)
RecordingStudioMessages.seen_by(group_recording: group, viewer: current_actor)
RecordingStudioMessages.create_group(
  mount,
  title: "Center desk",
  actor: current_actor,
  tags: { "press_center" => press_center, "press_kit" => press_kit }
)
RecordingStudioMessages.tagged_group_recordings(
  mount_recording: mount,
  tags: { "press_center" => press_center }
)
```

`create_group` still takes `title:`, `actor:`, and optional `tags:`. Optional `admin:` sets the `:members` owner instead of the creating actor. On `:inherited` it writes no grant.

`viewable_group_recordings(actor:, mount_recording:, tags: nil, unread: false, after: nil, limit: nil)` returns the kept `MessageGroup` recordings the actor can view under that mount. It calls Accessible `recordings_for` with `minimum_role: :view` and `recordable_type` set to `MessageGroup`, then sorts by the latest message time and then by title. Pass the mount. A blank actor or a blank mount returns `[]`. Pass `unread: true` to keep conversations whose `last_message_at` is after that actor's `last_read_at`, or that have a `last_message_at` and no read row. That filter reuses `MessageReads.unread_ids_among` after Accessible and tags. `after:` and `limit:` still page that filtered list. The engine index, the staff desk, and the inbox all use this list.

`my_group_recordings(actor:, after: nil, limit: nil, unread: false)` returns a relation of kept conversations that have a kept, effective direct Accessible grant for that actor, across every mount. It does not call `recordings_for`. Inherited access on a root or mount is not enough. The relation orders by `last_message_at` descending, then recording id. Pass `unread: true` to keep conversations whose `last_message_at` is after that actor's `last_read_at`, or that have a `last_message_at` and no read row. `after:` and `limit:` still page that filtered list. A blank actor returns `Recording.none`. Use this for `GET /my_messages`. Keep `viewable_group_recordings` for one mount.

`mark_read(group_recording:, actor:)` upserts that person's cursor (`last_read_at` and the latest message id). It requires Accessible `:view`. It also marks that person's unread `:message_received` notices for that conversation as read, through the Notifications model. It does not grant access. `unread?(group_recording:, actor:)` is true only for a viewer who still has a newer `last_message_at`. `unread_count(actor:)` counts unread rows in `my_group_recordings` with one join. Read rows are private until `read_receipts` is on. `seen_by(group_recording:, viewer:)` then lists current granted readers whose cursor has reached the latest message. Bell clear-all does not change these cursors.

`tag` writes a message group tag row. One group can hold many keys. Each key points at one tagged recording. `untag` deletes that key, or the exact row when you also pass `recording:`. Optional `tags:` on the list is an AND filter over those rows. It does not replace Accessible. Example keys are `press_center` and `press_kit`. This gem does not define a press vocabulary.

`create_group` accepts the same hash. Omit `tags:`, or pass `nil` or `{}`, and the conversation is created with no tag rows. The conversation, the owner grant, and the tag rows commit together. If the owner grant fails, the conversation and the tag rows are gone. A second successful `create_group` with the same tags creates a second conversation. `tag` and `untag` still change tags after the conversation exists.

`tagged_group_recordings(mount_recording:, tags:)` returns an unsorted relation of kept conversations on that mount. Every pair in the hash must match. `nil` and `{}` leave the tag filter off, so the relation is every kept conversation on the mount. The relation does not call Accessible. It is not an ACL. Pass a mount. A blank mount raises `ArgumentError`. A recording that is not a message mount raises `RecordingStudioMessages::Error`. Use this for counts, migrations, and the check before create. Use `viewable_group_recordings` for the desk. Call `.count`, `.exists?`, or `.to_a`. Trashed conversations are left out. Two processes can both read zero and both create. That race stays in the host.

Sending checks Accessible `:edit` on the conversation, writes a Message, stores files through Attachable, stamps `last_message_at`, upserts the sender's read cursor, and notifies every other granted actor with `:message_received`. The URL should open that same panel.

`:message_received` stays root-scoped. By default every copy is filed under the conversation's root, so a ticket owner sees it when that workspace is selected. Staff who should see the same notice in the Admin inbox need a host opt-in:

```ruby
RecordingStudioMessages.configure do |config|
  config.admin_notification_root = -> {
    RecordingStudioMessages::Api::Access.admin_root_recording
  }
end
```

Set `admin_notification_root` to an Admin root `Recording`, or a callable that returns one. Recipients with Accessible `:view` on that recording (the same staff check as operations metrics) get the notice filed there. Everyone else, including the ticket owner, stays on the conversation root. Tickets, mounts, and groups do not move. Leave it `nil` to keep today's filing. This gem does not add an Admin dependency. Support and hosts that already resolve the Admin root through `Api::Access.admin_root_recording` pass that recording in.

Notifications requires `root_recording` to match the attached `recording` when both are set. Staff copies that file under Admin omit `recording` and keep the URL plus `message_group_id` / `message_id` in metadata. Ticket-root copies still attach the message recording.

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

The gem page is `recording_studio_messages.public_contact_path(mount_id: mount.id)`. `GET /public_contact` renders the form. A signed-out visitor sees name, email, and message. A signed-in person sees a badge with their name and the message field. The email stays off that screen. Posting a different email does not change who sends. A successful post redirects to `public_contact_sent_path`. That screen centers the copy, with a hero icon above a larger "Message sent" and "Powered by" the site name. The page loads Flatpack's application stylesheet so primary buttons use the theme colors. The site name comes from Site Settings on that root when the host has it, otherwise the root's name. One primary button leaves the dialog. By default a signed-in sender sees "View conversation" to the new conversation. `public_contact_success_redirect_url` sends that same button to another URL for every sender. In the dialog, the Contact title is hidden on this step. The icon defaults to `rocket-launch`. Set `public_contact_sent_icon` to another heroicon name, or to an image path or URL. A value that ends in a common image extension (png, jpg, jpeg, gif, webp, svg, avif, ico), starts with `/`, `http://`, or `https://`, or is any other asset path, renders an `<img>` in that same slot at the heroicon's size. `nil` hides the slot. Refreshing that page does not send again.

`public_contact_form` renders that same form on a host page. The post still leaves for the full-page code step or the sent screen.

```erb
<%= public_contact_form(mount) %>
<%= public_contact_form(mount, title: "Contact", introduction: "We reply by email.", submit_label: "Send message") %>
<%= public_contact_form(mount, tags: { "press_center" => press_center }) %>
```

`public_contact_modal` keeps every step in a dialog on the host page. The button opens a Flatpack modal. The body is a Turbo Frame, `public_contact`, loaded from the same URL with `presentation=modal`. Compose, the code step, resend, a wrong code, and "Message sent" replace that frame. On the code step the heading is "Verify it's you", the button is "Next", "Resend code" is a link, and the Contact title is hidden. A notice or error in the dialog has space under it. On "Message sent" the Contact title is hidden. The dialog stays open. A signed-in person still skips the code. That same single button leaves the dialog. Closing during the code step does not send another code. Opening the dialog again shows that step while the code is still open. After "Message sent", opening it again starts a new note. An expired code stays in the dialog with "Send it again".

```erb
<%= public_contact_modal(mount) %>
<%= public_contact_modal(mount, title: "Contact", introduction: "We reply by email.", submit_label: "Send message") %>
<%= public_contact_modal(mount, tags: { "press_center" => press_center }) %>
```

`tags:` is the same hash as `begin_public_contact` and `create_group`. A key is a string. A value is any recording. Messages does not know kits. The helper signs the ids into `tag_token` with Rails `MessageVerifier`, a purpose, and a 24-hour expiry. The modal src carries that token as a query param. The form keeps it in a hidden field. Restart keeps it too. The public contact controller verifies the token before `PublicContact.begin`. A tampered or expired token is rejected. Each tagged recording must be live and inside the subtree of the mount's parent recording. That check walks `parent_recording_id` in batches. It does not use recursive SQL. A rejected token does not create a conversation. The visitor sees "We couldn't send that message. Start a new one." Tags never grant access. Omit `tags:` and nothing in the request changes.

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

`begin_public_contact` accepts `tags:`. Signed in, it tags the new conversation and passes the hash to the resolver. Signed out, it stores the tagged recording ids on the pending intent. `complete_public_contact` reads those ids, tags the new conversation, and passes that hash to the resolver. The complete call has no `tags:` argument. Calling it again returns the same conversation. If a tagged recording or the contact mount is missing or trashed when complete or verify runs, the gem reloads that row from the database and raises `RecordingStudioMessages::Error`. The check happens before identity confirmation. The intent stays open. No conversation is written. The visitor message is "We couldn't send that message. Start a new one."

`create_group` and `tag` do the same live reload. An unsaved recording raises `ArgumentError` with `tagged recording must be saved`. A missing or trashed recording raises `ArgumentError` with `tagged recording is missing`. Old tag rows stay. `tagged_group_recordings` still matches those rows by id.

The engine contact form has no visible tag field. Pass `tags:` to `public_contact_form` or `public_contact_modal` when the popup should carry them. Call `begin_public_contact` from the host when you already have the hash in Ruby.

Set `public_contact_recipient_resolver` to a callable. When the callable lists `tags:` or a keyrest parameter, `begin` and `complete` pass `tags:` as a hash. Keys are strings. Values are recordings. When there are no tags, that hash is `{}`. A callable that only lists `mount_recording:` and `actor:` is called with those two keywords. A value that does not respond to `call` is ignored.

On a `:members` mount the first recipient who is already an admin on the mount path is the actor for `create_group`. Admin on an ancestor counts. Every other recipient gets an `:edit` grant on the new conversation. The sender gets `:edit` too, unless they are that admin. A second grant would replace `:admin`. `create_group` does not notify. `send_message` notifies the other direct grants, which is why those grants exist.

On an `:inherited` mount there is no opener. `create_group` writes no staff grant. The sender gets a direct `:edit` grant. Resolver recipients are notified and are not granted. An empty resolver is fine.

There is no file field on this form.

```ruby
RecordingStudioMessages.configure do |config|
  config.public_contact_recipient_resolver = lambda { |mount_recording:, actor:, tags: {}|
    desk_for(mount_recording, tags)
  }
end
```

A resolver that does not need the hash stays on two keywords.

```ruby
RecordingStudioMessages.configure do |config|
  config.public_contact_recipient_resolver = lambda { |mount_recording:, actor:|
    [User.find_by(email: "admin@admin.com")].compact
  }
  config.public_contact_sent_icon = "rocket-launch"
  config.public_contact_sign_in_after_verification = false
  config.public_contact_success_redirect_url = nil
  config.public_contact_success_redirect_label = nil
end
```

### After the message is sent

`public_contact_sign_in_after_verification` (default `false`). When `true`, a
signed-out visitor who enters the right email code is signed in through the
host's Devise (`sign_in(scope, user)` with the scope Devise maps for that user;
plain Warden `set_user(user, scope: :user)` when Devise helpers are absent).
That covers both a brand-new OTP registration and an existing account that
verified with a login code. A wrong or expired code never signs anyone in, and
someone already signed in is left alone. Off, the visitor stays signed out
after sending.

The "Message sent" step, on the full page and in the dialog, shows one primary
button. It leaves the dialog (`turbo_frame: "_top"`).

With `public_contact_success_redirect_url` left `nil`, that button reads
"View conversation" and links to the new conversation. It appears when the
sender is signed in.

Set `public_contact_success_redirect_url` and that same button uses the
configured URL instead, for new and existing users, signed in or not. Give a
String, or a callable that receives `mount_recording:`, `group_recording:` (the
new conversation), `user:` (the sender), and `request:` and returns a URL. A
blank result hides the button.

`public_contact_success_redirect_label` sets that button's text. Leave it `nil`
for the translated "View conversation" (`contact.view_conversation`).

```ruby
RecordingStudioMessages.configure do |config|
  config.public_contact_sign_in_after_verification = true
  config.public_contact_success_redirect_url = lambda { |mount_recording:, group_recording:, user:, request:|
    Rails.application.routes.url_helpers.inbox_path
  }
  config.public_contact_success_redirect_label = "Go to your inbox"
end
```

On a `:members` mount, if nobody in that list is already an admin on the mount path, `begin` raises `RecordingStudioMessages::Error` with "Nobody can receive this message." and does not send a code. On an `:inherited` mount that check is skipped.

```text
form
└── pending intent, body stored for 24 hours
    └── email code
        └── verify_otp!
            └── confirmed user, profile written from the submitted name when none exists
                └── create_group (`:members` uses the admin recipient; `:inherited` uses the sender)
                    └── `:members` grants opener, sender, and other recipients; `:inherited` grants only the sender `:edit`
                        └── send_message
                            └── intent fulfilled, body cleared
```

The pending row expires 24 hours after `begin`. An expired row does not send. Once the conversation exists, the body is cleared and `message_group_id` is set in the same write as the group, the grants, and the message. A retry of that intent returns the conversation. It cannot send twice. The form does not accept attachments.

Header faces come from `recording_studio_accessible_avatars`. That helper shows **+ Access** only when the grant list is empty. On a `membership_locked` mount the header omits that control and Accessible refuses membership changes (see Enablement).

## Overridable helpers

A host helper with the same name replaces the engine helper. Support does this for `messages_inbox_href(group_recording)` so staff desk links stay on the messages mount.

The open conversation panel calls three hooks. Each takes the open conversation, the current actor, and the conversation's parent mount recording. All three return `nil` until a host overrides them. Return html-safe markup. These hooks add no strings of their own. They grant no access. The host must check Accessible before it renders anything that should stay private.

| Helper | When it shows |
|---|---|
| `messages_panel_right_header(group_recording, actor:, mount:)` | Flatpack `Chat::Panel` `right_header`. Alone, the part is `flex` at every width. When the mobile hook also returns content, this part is `hidden sm:flex` (shown at 640px and up). |
| `messages_panel_right_header_mobile(group_recording, actor:, mount:)` | Flatpack `Chat::Panel` `right_header_mobile`. Shown below `sm` (`flex sm:hidden`). |
| `messages_panel_after(group_recording, actor:, mount:)` | Once, after the panel, inside the `messages-desk-panel` turbo frame. Use a fixed modal. |
| `messages_list_toolbar(mount:, actor:)` | Beside the unread toggle in the conversation list header, after the toggle. `mount` is the desk's `MessageMount` recording, or nil on `/my_messages`. Desktop and stacked (mobile) list headers both render this slot. |
| `messages_list_header_title(mount:, actor:)` | `Chat::Header` `title` on the conversation list. Default is nil, so the header is controls only. Return a string to put a name back. `mount` is the desk's `MessageMount` recording, or nil on `/my_messages`. |

A nil or blank panel-hook return omits that piece, and the panel markup stays as it is without the hook. The list toolbar hook is the same. A blank toolbar return leaves only the unread toggle. A blank list title leaves `Chat::Header` with no name. The panel passes a right-header slot only when that hook returns content (`panel.right_header` and `panel.right_header_mobile`). Each filled slot wraps the host markup in `flex items-center gap-2 whitespace-nowrap p-4`, matching Flatpack's documented `Chat::Panel` actions and `Chat::Header`'s `p-4`. Flatpack 0.1.341's right-header parts have no padding of their own. On Flatpack 0.1.341, `right_header` is `hidden sm:flex` only when `right_header_mobile` is also supplied. A lone `right_header` stays `flex` at every width. When both return content, both slots are in the DOM and CSS hides one, so their ids, Stimulus targets, and `aria-controls` targets must differ. Pass only the mobile hook and the compact actions show below `sm`.

The same partial renders on the staff desk, `/my_messages`, and the `/my_messages/:id` Turbo stream that replaces the panel. A host header updates whenever that panel updates. Sending a line still replaces only the message list and composer.

`messages_panel_after` is a sibling after the panel, still inside the `h-full` turbo frame. That frame sits in `Chat::Layout`'s `overflow-hidden` panel column, so in-flow markup is clipped. Flatpack's modal backdrop is `fixed inset-0`, so a modal is not clipped and does not add height in the frame.

Branch on the mount when the host has more than one desk:

```ruby
def messages_panel_right_header(group_recording, actor:, mount:)
  return unless mount&.recordable&.key.to_s == "support"

  render "support/ticket_status", group_recording: group_recording, actor: actor
end

def messages_panel_right_header_mobile(group_recording, actor:, mount:)
  messages_panel_right_header(group_recording, actor: actor, mount: mount)
end

def messages_panel_after(group_recording, actor:, mount:)
  return unless mount&.recordable&.key.to_s == "support"

  render "support/ticket_status_modal", group_recording: group_recording, actor: actor
end
```

Compare `mount` itself when the host has several recordings that share a key, such as one press-center mount per site plus `:support`.

## Screens

The desk opens on `message_groups#index` as Flatpack `Chat::Layout` `:split`. A named `mount_id` must pass Accessible `:view` on the mount parent or the request 404s before the title reads that parent name. The list `Chat::Header` has no mount name unless the host overrides `messages_list_header_title`. `viewable_group_recordings` fills the sidebar with the kept conversations on that mount that the actor can view. `GET /my_messages` is the same desk without a mount. `my_group_recordings` fills that sidebar from kept direct grants across every mount. Each row names the mount parent. Opening a conversation keeps `/my_messages` in the sidebar and in the back link. Accessible `recordings_for` supplies those rows (`minimum_role: :view`), and the helper sorts them by latest message time, then title. A request with no mount shows an empty sidebar. There is no Participant list, Pundit, CanCan, or host `admin?` check. Sidebar rows are `Chat::InboxRow` only (name + latest line). The panel slot is the existing `Chat::Panel` in a `messages-desk-panel` turbo frame. Clicking a row keeps the split desk mounted: InboxRow sets `turbo_frame`, and Layout Stimulus `openPanel` / `showPanel` shows the panel under the split breakpoint (`sm` by default). Do not full-visit show from a row. Hollow empty-grant groups stay off the sidebar. Product pages use Recording Studio's default layout. `RecordingStudioMessages.configuration.layout` defaults to `nil`, which follows `RecordingStudio.configuration.layout` and then `recording_studio/default_layout`. Set a string layout name, `false` for no layout, or a keyword callable `->(controller:) { ... }` that returns a String, `nil`, or `false`. The layout sets `data-theme="rounded"` on `<html>`. Do not fork Chat::Panel CSS. Do not fork Chat::Layout split CSS. Flatpack `>= 0.1.347` supplies a fluid split from `sm`, rounded theme tokens for charcoal Send buttons, outgoing bubbles on the neutral surface, `InlineEdit` for the conversation name when the actor has Accessible `:edit`, and bubble times that stay in the DOM until hover, tap, or focus. Messages inserts `Chat::DateDivider` for a new day and for a gap longer than `time_break_after` (15 minutes by default). The last group's `status` slot is `Chat::SentAt` until `read_receipts` shows seen faces. A rename updates `messages-inbox-title-<id>` on that list row and leaves the v0.17 right-header hooks and padding alone. Page titles go in `content_for :title` (and `:subtitle`). Back and close use `flat_pack_page_nav`. Extra actions use `register_page_nav` or `content_for :page_nav_right`. Chat::Header has no back. On stacked widths, Chat::Layout's Back to conversations returns to the list; do not hide it. Do not put Sign out or Root Switchable in the page slot.

The desk fills the viewport under the host's page nav and page title. `Chat::Layout` is `h-full`, so height lives on the wrapper (`h-[calc(100dvh-15.5rem)]`, matching Recording Studio 6.1's top nav, page title, and layout padding). The same wrapper is `w-full min-w-0` so the split can shrink inside core `main`. Messages scroll inside the panel and the composer stays on the bottom edge instead of sitting under the browser chrome. A host with different chrome passes `desk_height_class` to the partial. Do not set the height on `Chat::Layout` itself; its own `h-full` wins.

Composer uploads go through Attachable. Send replaces the thread in place over Turbo (the message list and composer). There is no Action Cable in this version. Look at the live kit: [Chat::Layout](https://flatpack.bowerbird.io/demo/chat/layout), [Chat::InboxRow](https://flatpack.bowerbird.io/demo/chat/inbox_row), [Chat::Panel](https://flatpack.bowerbird.io/demo/chat/panel), and [Chat demo](https://flatpack.bowerbird.io/demo/chat/demo).

## Operations metrics

The engine registers four site-wide metrics on `:operations` (`blast_radius: :site`). `api_authorize` uses `RecordingStudioMessages::Api::Access.can_view?`. This gem does not call `RecordingStudioMetrics::Api.register!`. The host registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

RecordingStudio MCP `0.17.0` adds one read-only tool per exposed metric. The tool name is the identifier with its single dot replaced by a hyphen. `from`, `to`, and `interval` apply to timeseries only.

| Identifier | MCP tool | Window |
|---|---|---|
| `messages.sent_over_time` | `messages-sent_over_time` | `from`, `to`, `interval` |
| `message_groups.created_over_time` | `message_groups-created_over_time` | `from`, `to`, `interval` |
| `contact_intents.submitted_over_time` | `contact_intents-submitted_over_time` | `from`, `to`, `interval` |
| `contact_intents.converted` | `contact_intents-converted` | none |

See [How Recording Studio Messages works](docs/how-it-works.md#operations-metrics).

## Dummy host

`test/dummy/` is a host that proves the gem. It is not the product.

Dummy credentials (`test/dummy/config/credentials.yml.enc`) are encrypted with the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or put that key in `test/dummy/config/master.key` (gitignored). Keep the encrypted file; do not generate a per-repo dummy key.

Authenticated dummy pages use Recording Studio's default layout (`recording_studio/default_layout`) so back/close chrome and Flatpack alerts come from core. The dummy controller calls `recording_studio_layout` and returns `"application"` only for Devise. Messages screens follow `RecordingStudioMessages.configuration.layout` (`nil` by default). Do not put Sign out or Root Switchable in that slot. The Users gem owns `/users/sign_in` and renders its auth layout (`layouts/recording_studio_user/auth`), with Flatpack CSS/JS plus Turbo.

| Field    | Value              |
|----------|--------------------|
| Email    | admin@admin.com    |
| Password | Password           |
| Email    | casey@example.com  |
| Password | Password           |

The dummy switches English and French with Recording Studio Internationalization by `PATCH /recording_studio_internationalization/locale`. The top nav does not include a language selector. Conversation titles and seeded message bodies stay in the language they were written.

The dummy proves two mounts at once:

- `support` on Studio Workspace → Staff desk (`/staff/desk`) lands on the conversation list
- `inbox` on the Site mailbox → Inbox (`/inbox`) lands on the conversation list (one row)

Home also has a Contact button to that inbox's public form, and an Admin button. Admin is on `v2.6.2` and mounts Site Settings (`v0.5.1`) and Terms and Conditions (`v0.13.4`). Publishable is on `v0.11.0` and serves public `/terms/:uuid/:slug` and `/privacy/:uuid/:slug`. Root Switchable stays on `v0.10.0` because `v0.11.4` drops the blank layout the dummy switcher page uses. Users stays on `v0.26.3` because `v0.27.0` wraps sign-in in Default Layout. Both require Cache `v0.5.1`. Recording Studio is on `v6.3.0`. Accessible is on `v0.24.1`. Attachable is on `v0.21.1`. Notifications is on `v0.13.1`. Metrics is on `v0.6.1`. Logs is on `v0.7.0` because Admin loads it. Trashable is on `v0.11.3` with `require: false`. Internationalization is on `v0.1.7` and is dummy-only. Flatpack is on `v0.1.349`. `view_component` is `4.19.0`. The messages gemspec requires `recording_studio >= 6.1.0` and `flat_pack >= 0.1.349`. Accessible `v0.24.1` allows `recording_studio ~> 6.1`. Terms and Conditions `v0.13.4` and `v0.14.2` still require `recording_studio ~> 4.2`, so this dummy cannot drop the Bundler shim until that gem ships a 6.x tag. The Gemfiles load `test/support/widen_recording_studio_requirement.rb` so this dummy can boot. Delete that file when those tags allow `>= 6.1.0`. Site Settings 0.5.1 still includes `RecordingStudio::UsesDefaultLayout`, so the dummy defines an empty module until that gem stops.

Seeds add **Studio help** and **Launch notes** on support, **Site inbox** on the mailbox, Ada Staff, Casey Patron, the Relay agent, lines in each desk, and a hero-still attachment on the inbox. An empty conversation stays on the support mount so `+ Access` can be shown when opened by URL.

| Gem | Constraint | Tag | Locked `VERSION` |
|---|---|---|---|
| `recording_studio` | `>= 6.1.0` | `v6.3.0` | `6.3.0` |
| `recording_studio_accessible` | `~> 0.24` | `v0.24.1` | `0.24.1` |
| `recording_studio_attachable` | `~> 0.13` | `v0.21.1` | `0.21.1` |
| `recording_studio_notifications` | `>= 0.3.1, < 1` | `v0.13.1` | `0.13.1` |
| `recording_studio_metrics` | `>= 0.3.0, < 1.0` | `v0.6.1` | `0.6.1` |
| `flat_pack` (repo `bowerbird-app/flatpack`) | `>= 0.1.349` | `v0.1.349` | `0.1.349` |
| `view_component` | `4.19.0` | | `4.19.0` |
| `recording_studio_user` (dummy host only) | `~> 0.16` | `v0.26.3` | `0.26.3` |
| `recording_studio_cache` (host pin for Users / Root Switchable) | `~> 0.5` | `v0.5.1` | `0.5.0` |
| `recording_studio_admin` (dummy host only) | `~> 2.1` | `v2.6.2` | `2.6.2` |
| `recording_studio_logs` (Admin loads it) | `>= 0.4.1, < 1.0` | `v0.7.0` | `0.7.0` |

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
