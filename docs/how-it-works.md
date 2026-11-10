# How Recording Studio Messages works

This gem adds conversation desks to a Recording Studio host. It does not replace Accessible, Attachable, or Notifications. Those gems keep doing their jobs.

## One gem, many desks

A host enables `:messages` on a recordable type. That type may then hold keyed `MessageMount` children. Staff help and a site inbox are two keys, not two gems.

```text
Workspace  — enables :messages
└── MessageMount key: support
    └── Conversation
        ├── Access grants
        └── Messages (+ files)

Mailbox  — also enables :messages
└── MessageMount key: inbox
    └── Conversation
```

The dummy host proves that shape with a staff desk and an inbox.

## What belongs in the tree

| Object | Why it is a recording |
|---|---|
| Mount | A durable desk on a parent |
| Conversation | People manage it; access hangs here |
| Message | A line people wrote |
| Attachment | Attachable already owns this child |

Notifications are facts, not recordings. They live in the Notifications tables. Participants are not a type — people and agents are actors with Accessible grants on the conversation. Message group tags are also facts. They live in `recording_studio_message_group_tags` and join a conversation recording to a host recording by a host-chosen key. Per-person read cursors are facts too. They live in `recording_studio_message_reads` (one row per actor per conversation). They never grant access.

## Writes

Use the public helpers:

- `ensure_message_mount` to hang or find a keyed mount
- `create_group` to open a conversation, grant the first owner, and optionally write tags in that same commit
- `viewable_group_recordings` to list the kept conversations one actor can view under one mount
- `my_group_recordings` to list the kept conversations one actor was added to, across every mount
- `tagged_group_recordings` to list kept conversations on one mount without an actor
- `tag` / `untag` to join a conversation to a host recording by a host-chosen key
- `send_message` to write a line, attach files, stamp `last_message_at`, upsert the sender's read cursor, and notify everyone else who has a grant
- `mark_read` / `unread?` / `unread_count` for that private cursor
- `readers_by_message` when the host opts into seen faces

`viewable_group_recordings(actor:, mount_recording:, tags: nil)` calls Accessible `recordings_for` with `minimum_role: :view` and the `MessageGroup` type, then sorts by latest message time and title. Pass a mount. A blank actor or a blank mount returns `[]`. Optional `tags:` is a hash of key to tagged recording. Every pair must match a `recording_studio_message_group_tags` row. Tags shrink that Accessible list. They are not an ACL.

`my_group_recordings(actor:, after: nil, limit: nil, unread: false)` is a relation, not a Ruby array. It joins kept `MessageGroup` recordings to kept `RecordingStudio::Access` children for that actor. Inherited access on a root or mount is ignored. A grant with `depends_on_recording_id` is included only when that manager Access recording is kept, on the same root, and at least as strong. The relation orders by `recording_studio_message_groups.last_message_at` (nulls last), then recording id. Pass `unread: true` to left-join `recording_studio_message_reads` for that actor and keep conversations whose `last_message_at` is newer than `last_read_at`, or that have a `last_message_at` and no read row. `after:` / `limit:` still keyset that list. `unread_count(actor:)` is that filtered relation counted in one query. `send_message` writes `last_message_at` and the sender's read row. The 0.15.0 install migration backfills existing membership as read. Tags are not part of this lookup. Read rows are never an ACL. `readers_by_message(group_recording:, viewer:)` is empty unless `read_receipts` is true. When it is on, it loads that conversation's cursors and kept ranked Accessible grants in one batched pass, drops the viewer, and groups remaining people by `last_read_message_recording_id` (or the newest line at or before `last_read_at`). The thread renders those people with a Flatpack `Cluster` of `Avatar`s (max 3, then a `+N` avatar, no overlap) in the bubble column. Faces refresh on the next render. Turbo streams from `#show` still only update that person's unread row and badge.

Message group tags live in `recording_studio_message_group_tags`. They are facts, not recordings. `MessageGroupTags` is the only writer of those rows. Unique `(message_group_recording_id, key)` keeps one tagged recording per key on a group. Hosts choose keys such as `press_center` and `press_kit`. This gem does not ship those names as constants.

`create_group(..., tags: nil)` writes those rows in the same transaction as the conversation and the owner grant. `nil` and `{}` write none. A failed owner grant leaves no conversation and no tag rows. A second successful `create_group` with the same tags creates a second conversation. `tag` and `create_group` reload each tagged recording. They reject an unsaved recording and a missing or trashed one. They do not delete existing tag rows.

`tagged_group_recordings(mount_recording:, tags:)` is an unsorted relation of kept `MessageGroup` children of that mount. It does not call Accessible, so it is not an ACL. A blank mount raises `ArgumentError`. A recording that is not a message mount raises `RecordingStudioMessages::Error`. `tags: nil` and `tags: {}` leave the filter off and return every kept conversation on the mount. A non-empty hash requires every pair. `press_center` and `press_kit` are examples, not constants. Many conversations may share one key. The host counts, then creates, when one conversation is the goal. Two processes can both read zero and both create. That race stays in the host.

Public contact helpers can pass that same hash as `tags:`. They sign the ids into `tag_token` with Rails `MessageVerifier`, a purpose, and a 24-hour expiry. The public contact controller verifies the token, reloads each recording with `MessageGroupTags.tags_from_ids`, and requires each one to sit in the subtree of the mount's parent recording. That walk uses batched `parent_recording_id` lookups. It does not use recursive SQL. A bad token never creates a conversation. Tags never grant access. Direct `begin_public_contact(tags:)` still only live-checks, as in 0.12.0.

`NotifyGrantedActors` files `:message_received` under the conversation root unless the host sets `admin_notification_root`. That option is a recording or a callable that returns one. Recipients with Accessible `:view` on it (staff, the same check `Api::Access.can_view?` uses on the Admin root) get that recording as `root_recording`. Other recipients keep the ticket root. Conversation placement does not change. The notification type stays `scope: :root`. When the filing root is not the message's tree root, the notice omits `recording` so Notifications' root check still holds. URL and metadata stay.

Do not insert `Recording` rows by hand. Do not invent a second access list.

## Screens

A mount opens as Flatpack `Chat::Layout` `:split` (`GET /recording_studio_messages/message_groups`, optional `mount_id`). A named mount must pass Accessible `:view` on its parent recording or the action 404s, so the title cannot leak the parent name. `viewable_group_recordings` asks Accessible `recordings_for` for kept `MessageGroup` children of that mount that the current actor can view (`minimum_role: :view`). Ruby sorts those recordings by the latest message time, then by title. A blank actor or a blank mount returns an empty list, so the index stays empty until the request names a mount. The check is Accessible on `MessageGroup`. Conversation `#show` still redirects when the actor cannot view that group. The sidebar is `Chat::InboxRow` only. The panel slot is the existing `Chat::Panel` inside a `messages-desk-panel` turbo frame. Clicking a row uses the kit path: InboxRow `turbo_frame` replaces that frame, and Layout Stimulus `openPanel` / `showPanel` hides the sidebar under the split breakpoint (`sm` by default). It does not Turbo-visit show and remount the desk. The engine controller sets `recording_studio_layout { RecordingStudioMessages.configuration.layout }`. `layout` defaults to `nil`, which falls through to `RecordingStudio.configuration.layout` and then `recording_studio/default_layout`. A string names a layout. `false` renders none. A callable must be keyword-only (`controller:`) and return a String, `nil`, or `false`. Views set `content_for :title` so the layout draws one page heading. Back and close use `flat_pack_page_nav`. Chat::Header has no `back_href`. Layout's stacked Back to conversations stays visible so a stacked window can return to the list. Do not fork Chat::Layout split CSS. The desk wrapper is `w-full min-w-0 h-[calc(100dvh-15.5rem)]`. Faces in the header come from Accessible unless the mount key is `membership_locked`. Composer files go through Attachable.

Rounded is a named Flatpack theme. Recording Studio 6.1's default layout sets `data-theme="rounded"` on `<html>`. The dummy head partial still sets it from JavaScript, and a host helper copies `lang` onto `<html>` when the tag omits it. Do not restyle Chat::Panel in this gem.

Flatpack `>= 0.1.331` (pinned tag `v0.1.341`) keeps rounded primary buttons charcoal, a fluid Chat::Layout split from `sm`, and outgoing bubbles on the neutral surface. Modal closes itself on `turbo:before-cache`. Chat composer TextArea uses `variant: :chat`. Contact headings use `FlatPack::Heading::Component`. `v0.1.319` is not a published tag. This gem requires `recording_studio >= 6.1.0` and `flat_pack >= 0.1.331`. Development pins Recording Studio `v6.3.0`. `view_component` locks at `4.19.0`. `FlatPack::Card` does not take `style:`.

`GET /my_messages` is the same split desk with no `mount_id`. Rows come from `my_group_recordings`. Each InboxRow uses the mount parent name as `latest_sender` so a cross-mount list still names the desk. An unread row keeps InboxRow's count at zero and marks the first avatar with Flatpack status `:busy` (a small dot). The inbox header is one round `bell-alert` button: outline when showing all, solid and `current` when showing unread only. The header also shows `unread_count` in `messages-unread-badge`. Row links stay on `/my_messages/:id` and request a Turbo stream, so the sidebar does not switch to the mount desk. Back returns to `/my_messages`. Opening `#show` after Accessible `:view` marks that conversation read and clears that person's unread `:message_received` notices for it. The stream updates that row's unread avatar and the badge. It does not replace the list, so an unread-filtered row stays until the filter changes or the page reloads. Index auto-select does not mark read. Inherited-only conversations do not appear as rows.

Dummy screenshots of Casey's inbox (row dots, round unread filter, live badge after open) and of seen faces live in `docs/screenshots/`. The dummy host sets `read_receipts`.

Dummy staff desk and inbox land on that split layout. Support seeds two conversations so the sidebar is real. Inbox still shows one InboxRow plus its panel. Home also links to My messages, which lists Casey's direct grants on both desks. An empty-grant conversation can still open by URL for + Access; it does not leak a bare title into the sidebar.

Customer-facing chrome (contact form, composer, empty states, flashes, validation) lives under `recording_studio.messages.*` in `config/locales/en.yml`. The engine ships English only. Hosts translate by copying those keys. Conversation titles and message bodies are stored data and are not translated here.

Sending does not wait on a cable. The composer posts as a Turbo stream. The response replaces the message list (and the composer, so the field is empty again). A full HTML visit still works and shows a flash. Do not add Action Cable here.

## Operations metrics

The engine registers site-wide operations metrics at boot (`config.to_prepare` calls `RecordingStudioMessages::Metrics.register!`). Definitions go through `RecordingStudioMetrics.register` with `api_authorize` set to `RecordingStudioMessages::Api::Access.can_view?` (AdminRoot Accessible `:view`). This gem does not call `RecordingStudioMetrics::Api.register!`. The host registers Metrics endpoints once:

```ruby
RecordingStudioMetrics::Api.register!(api: :operations)
```

| Identifier | MCP tool (RecordingStudio MCP 0.17.0) | Window |
|---|---|---|
| `messages.sent_over_time` | `messages-sent_over_time` | `from`, `to`, `interval` |
| `message_groups.created_over_time` | `message_groups-created_over_time` | `from`, `to`, `interval` |
| `contact_intents.submitted_over_time` | `contact_intents-submitted_over_time` | `from`, `to`, `interval` |
| `contact_intents.converted` | `contact_intents-converted` | none (breakdown) |

MCP replaces the identifier's single dot with a hyphen. It does not register a second surface. A grant that fails `can_view?` is denied and the metric stays off `tools/list`.

## Related docs

- Product install and API: `README.md`
- Dummy operator guide: `test/dummy/README.md`
- Engine internals: `docs/gem_template/`
- Cloud Agent boot: `docs/cursor-skills.md`
