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

Mailbox  — also enables :messages, access: :inherited
└── MessageMount key: inbox
    └── Conversation
```

The dummy host proves that shape with a staff desk (`:members`) and an inbox (`:inherited`). Both declare `contacts:` so Ada can start a conversation and pick Casey.

## What belongs in the tree

| Object | Why it is a recording |
|---|---|
| Mount | A durable desk on a parent |
| Conversation | People manage it; access hangs here |
| Message | A line people wrote |
| Attachment | Attachable already owns this child |

Notifications are facts, not recordings. They live in the Notifications tables. Participants are not a type — people and agents are actors with Accessible grants on the conversation. Message group tags are also facts. They live in `recording_studio_message_group_tags` and join a conversation recording to a host recording by a host-chosen key. Per-person read cursors are facts too. They live in `recording_studio_message_reads` (one row per actor per conversation). They never grant access. Message references are facts as well. They live in `recording_studio_message_references` and join a message recording to another recording. They store the target recording, not its recordable. They never grant access.

## Writes

Use the public helpers:

- `ensure_message_mount` to hang or find a keyed mount
- `create_group` to open a conversation. On `:members` it grants `:admin` to `admin:` or the creating actor. On `:inherited` without `recipients:` it grants nobody. Pass `recipients:` and `body:` to start a conversation with people from a `contacts:` resolver. Each recipient gets `:edit`. On `:inherited` the creator also gets a direct `:edit` grant. Optional tags write in that same commit.
- `rename_group` to revise the conversation title (`MessageGroup#title`) and append an `updated` event
- `viewable_group_recordings` to list the kept conversations one actor can view under one mount
- `my_group_recordings` to list the kept conversations one actor was added to, across every mount
- `tagged_group_recordings` to list kept conversations on one mount without an actor
- `tag` / `untag` to join a conversation to a host recording by a host-chosen key
- `send_message` to write a line, attach files, optionally attach recording references, stamp `last_message_at`, upsert the sender's read cursor, and notify everyone else who has a grant
- `register_composer_action` / `register_message_embed` so another gem can add a + item and a typed card without this gem naming that gem
- `mark_read` / `unread?` / `unread_count` for that private cursor
- `seen_by` when the host opts into seen faces

`rename_group(group_recording:, title:, actor:)` strips the name, requires it, caps it at 120 characters, and calls `root.revise` on that conversation. The conversation must sit under a `MessageMount`. Accessible `:edit` (or stronger) is required. Tags are not part of the check. A no-op title does not write a second snapshot.

`viewable_group_recordings(actor:, mount_recording:, tags: nil, unread: false, after: nil, limit: nil)` calls Accessible `recordings_for` with `minimum_role: :view` and the `MessageGroup` type, then sorts by latest message time and title. Pass a mount. A blank actor or a blank mount returns `[]`. Optional `tags:` is a hash of key to tagged recording. Every pair must match a `recording_studio_message_group_tags` row. Tags shrink that Accessible list. They are not an ACL. Pass `unread: true` to keep conversations whose `last_message_at` is after that actor's `last_read_at`, or that have a `last_message_at` and no read row. The unread filter calls `MessageReads.unread_ids_among` on the Accessible ids (batched, no recursive SQL). `after:` / `limit:` still page that filtered list.

`my_group_recordings(actor:, after: nil, limit: nil, unread: false)` is a relation, not a Ruby array. It joins kept `MessageGroup` recordings to kept `RecordingStudio::Access` children for that actor. Inherited access on a root or mount is ignored. A grant with `depends_on_recording_id` is included only when that manager Access recording is kept, on the same root, and at least as strong. The relation orders by `recording_studio_message_groups.last_message_at` (nulls last), then recording id. Pass `unread: true` to left-join `recording_studio_message_reads` for that actor and keep conversations whose `last_message_at` is newer than `last_read_at`, or that have a `last_message_at` and no read row. `after:` / `limit:` still keyset that list. `unread_count(actor:)` is that filtered relation counted in one query. `send_message` writes `last_message_at` and the sender's read row. The 0.15.0 install migration backfills existing membership as read. Tags are not part of this lookup. Read rows are never an ACL. `seen_by(group_recording:, viewer:)` is empty unless `read_receipts` is true. When it is on, it loads that conversation's cursors and kept ranked Accessible grants in one batched pass, drops the viewer, and keeps people whose cursor has reached the latest message (`last_read_message_recording_id` or `last_read_at >=` that line's time). The thread renders those people under the viewer's own latest line only, omitting the author of that line, with a Flatpack `Cluster` of `Avatar`s (max 3, then a `+N` avatar, no overlap) in the bubble column. Received lines omit `Sent` and seen faces. Author read rows stay in place so unread is unchanged. Faces refresh on the next render. Turbo streams from `#show` still only update that person's unread row and badge.

Message group tags live in `recording_studio_message_group_tags`. They are facts, not recordings. `MessageGroupTags` is the only writer of those rows. Unique `(message_group_recording_id, key)` keeps one tagged recording per key on a group. Hosts choose keys such as `press_center` and `press_kit`. This gem does not ship those names as constants.

`create_group(..., tags: nil, admin: nil, recipients: nil, body: nil)` writes those rows in the same transaction as the conversation. On `:members` it also writes the owner grant (`admin:` when passed, otherwise the creating actor). On `:inherited` without recipients it writes no grant. `recipients:` re-validates every person against `contacts:` (blank query). Create is rejected when the callable is missing, the actor lacks `:edit` on the mount, a recipient is outside the allowlist, or `body` is blank. The first message is sent in that same transaction. `nil` and `{}` tags write none. A failed owner grant on `:members` leaves no conversation and no tag rows. A second successful `create_group` with the same tags creates a second conversation. `tag` and `create_group` reload each tagged recording. They reject an unsaved recording and a missing or trashed one. They do not delete existing tag rows.

`tagged_group_recordings(mount_recording:, tags:)` is an unsorted relation of kept `MessageGroup` children of that mount. It does not call Accessible, so it is not an ACL. A blank mount raises `ArgumentError`. A recording that is not a message mount raises `RecordingStudioMessages::Error`. `tags: nil` and `tags: {}` leave the filter off and return every kept conversation on the mount. A non-empty hash requires every pair. `press_center` and `press_kit` are examples, not constants. Many conversations may share one key. The host counts, then creates, when one conversation is the goal. Two processes can both read zero and both create. That race stays in the host.

Public contact helpers can pass that same hash as `tags:`. They sign the ids into `tag_token` with Rails `MessageVerifier`, a purpose, and a 24-hour expiry. The public contact controller verifies the token, reloads each recording with `MessageGroupTags.tags_from_ids`, and requires each one to sit in the subtree of the mount's parent recording. That walk uses batched `parent_recording_id` lookups. It does not use recursive SQL. A bad token never creates a conversation. Tags never grant access. Direct `begin_public_contact(tags:)` still only live-checks, as in 0.12.0.

`NotifyGrantedActors` files `:message_received` under the conversation root unless the host sets `admin_notification_root`. That option is a recording or a callable that returns one. Recipients with Accessible `:view` on it (staff, the same check `Api::Access.can_view?` uses on the Admin root) get that recording as `root_recording`. Other recipients keep the ticket root. Conversation placement does not change. The notification type stays `scope: :root`. When the filing root is not the message's tree root, the notice omits `recording` so Notifications' root check still holds. URL and metadata stay.

`send_message(..., references:)` writes `recording_studio_message_references` in the same transaction as the line. Each target must be live, visible to the sender through Accessible `:view`, and inside the subtree of the mount's parent recording. That walk uses batched `parent_recording_id` lookups. It does not use recursive SQL. Tags are not part of the check. The stored body stays as sent. `preview_text` fills notice and inbox fallback copy from reference titles when that body is blank. Messages does not depend on Notifications and does not name other gems.

The thread calls `visible_message_references` once per page. That loads every reference row for the loaded lines, loads the target recordings, then asks Accessible `recordings_for` for each distinct parent (`minimum_role: :view`). Each row becomes a `MessageReferenceSlot`. Targets the viewer cannot see, and targets that are trashed or missing, keep a slot with no recording. The template renders Flatpack `Chat::LinkCard` in its own MessageGroup `messages` item below the bubble. A blank `href` paints the kit Unavailable card and never leaks the unseen title. `register_message_embed` still overrides that default for a recordable class.

`register_composer_action` fills the + dropdown next to upload. `if:` receives `(group, actor, mount)` and defaults to keep the item. Messages owns one Flatpack modal per item. Pass exactly one of `partial:` or `src:`. `src:` loads a lazy Turbo frame when the modal opens. Search and pickers belong on that URL, with Accessible checks on the gem's endpoint. The documented insert event is `messages:composer-insert`. It also closes the modal. Message bodies pass through `AutoLink`, which HTML-escapes first, then wraps `http` and `https` only.

Do not insert `Recording` rows by hand. Do not invent a second access list.

## Screens

A mount opens as Flatpack `Chat::Layout` `:split` (`GET /recording_studio_messages/message_groups`, optional `mount_id`). A named mount must pass Accessible `:view` on its parent recording or the action 404s, so the title cannot leak the parent name. `viewable_group_recordings` asks Accessible `recordings_for` for kept `MessageGroup` children of that mount that the current actor can view (`minimum_role: :view`). Ruby sorts those recordings by the latest message time, then by title. `params[:unread]` filters that list the same way `/my_messages` does. The list header is a `Chat::Header` with a blank title, a round icon New message control when `contacts:` is set and the actor has `:edit` on the mount, the round unread toggle, then optional host markup from `messages_list_toolbar(mount:, actor:)`. New message opens a Flatpack modal. Recipients are a Flatpack Select (`multiple: true`, `searchable: true`, `search_mode: :remote`) whose search hits `GET /message_groups/contacts?q=` and returns `{ items: [{ value, label }] }`. Chips live in the Select trigger. Create posts to `POST /message_groups` with `recipients[]` tokens, omits title, and lands on the new conversation. The stored title is the creator then the recipients in pick order. List rows, the panel header, and the page heading CSS-truncate it with the full name in a title tooltip. The header InlineEdit can still rename it. Hosts can restore a name with `messages_list_header_title(mount:, actor:)`. Both hooks default to nil. They grant no access. `/my_messages` calls it with `mount:` nil and still shows the unread badge before the toggle. A blank actor or a blank mount returns an empty list, so the index stays empty until the request names a mount. The check is Accessible on `MessageGroup`. Conversation `#show` still redirects when the actor cannot view that group. The sidebar is `Chat::InboxRow` only. The panel slot is the existing `Chat::Panel` inside a `messages-desk-panel` turbo frame. Clicking a row uses the kit path: InboxRow `turbo_frame` replaces that frame, and Layout Stimulus `openPanel` / `showPanel` hides the sidebar under the split breakpoint (`sm` by default). It does not Turbo-visit show and remount the desk. The engine controller sets `recording_studio_layout { RecordingStudioMessages.configuration.layout }`. `layout` defaults to `nil`, which falls through to `RecordingStudio.configuration.layout` and then `recording_studio/default_layout`. A string names a layout. `false` renders none. A callable must be keyword-only (`controller:`) and return a String, `nil`, or `false`. Views set `content_for :title` so the layout draws one page heading. Back and close use `flat_pack_page_nav`. Chat::Header has no `back_href`. Layout's stacked Back to conversations stays visible so a stacked window can return to the list. Do not fork Chat::Layout split CSS. The desk wrapper is `w-full min-w-0 h-[calc(100dvh-15.5rem)]`. Faces in the header come from Accessible unless the mount key is `membership_locked`. Actors with Accessible `:edit` get Flatpack `InlineEdit` on that header name. Everyone else still sees the plain title. Hosts must pin `flat_pack/copy` so that controller can load. A save hits `PATCH .../message_groups/:id/rename` and Turbo-updates `messages-inbox-title-<id>` on the matching list row. It does not replace the list. The v0.17 right-header hooks and their `p-4` wrap stay as they are. Composer files go through Attachable. Registered composer actions share that + menu. Their Stimulus insert event is `messages:composer-insert`.

Hosts can replace `messages_panel_right_header(group_recording, actor:, mount:)`, `messages_panel_right_header_mobile(group_recording, actor:, mount:)`, and `messages_panel_after(group_recording, actor:, mount:)`. The same override style as `messages_inbox_href`: a host helper with that name wins. Each receives the open conversation, the current actor, and the parent `MessageMount` recording. Defaults return `nil`. The panel passes the first two through to Flatpack `Chat::Panel` `right_header` and `right_header_mobile` only when the return is present, and renders the third once after the panel inside the desk turbo frame. Blank returns leave the panel markup unchanged. Each filled right-header slot wraps host markup in `p-4` plus `gap-2`, because Flatpack 0.1.346's right parts have no padding. The same partial is used on the mount desk, `/my_messages`, and the `/my_messages/:id` Turbo stream panel replace. On Flatpack 0.1.346, `right_header` is `hidden sm:flex` only when `right_header_mobile` is also set. A lone `right_header` is `flex` at every width. When both are present, both stay in the DOM, so their ids, Stimulus targets, and `aria-controls` targets must differ. The after hook sits in the `h-full` turbo frame, inside Chat::Layout's `overflow-hidden` panel column. In-flow markup is clipped. A Flatpack modal is `fixed` (`inset-0` on the backdrop), so it is not clipped. The hooks grant no access. Messages does not know about tickets. The host must check Accessible.

Rounded is a named Flatpack theme. Recording Studio 6.1's default layout sets `data-theme="rounded"` on `<html>`. The dummy head partial still sets it from JavaScript, and a host helper copies `lang` onto `<html>` when the tag omits it. Do not restyle Chat::Panel in this gem.

Flatpack `>= 0.1.349` (pinned tag `v0.1.349`) keeps rounded primary buttons charcoal, a fluid Chat::Layout split from `sm`, outgoing bubbles on the neutral surface, and `Chat::LinkCard`. Rounded bubbles use `--chat-message-radius` (18px), `--chat-message-padding-x` (14px), and `--chat-message-padding-y` (10px). Bubble times stay in the DOM (`reveal_timestamp: true`) and show on hover, tap, or focus through `flat-pack--chat-timestamp-reveal`. Messages places `Chat::DateDivider` on a new calendar day and when consecutive `created_at` values are more than `time_break_after` apart (15 minutes by default). That walk uses the loaded thread only. The last group's `status` slot is `Chat::SentAt` until `read_receipts` fills it with seen faces, and only on the viewer's own last line. Received lines keep the hover timestamp and omit that status. Modal closes itself on `turbo:before-cache`. Chat composer TextArea uses `variant: :chat`. Contact headings use `FlatPack::Heading::Component`. `v0.1.319` is not a published tag. This gem requires `recording_studio >= 6.1.0` and `flat_pack >= 0.1.349`. Development pins Recording Studio `v6.3.0`. `view_component` locks at `4.19.0`. `FlatPack::Card` does not take `style:`.

`GET /my_messages` is the same split desk with no `mount_id`. Rows come from `my_group_recordings`. Each InboxRow uses the mount parent name as `latest_sender` so a cross-mount list still names the desk. An unread row keeps InboxRow's count at zero and marks the first avatar with Flatpack status `:busy` (a small dot). The inbox header is one round `bell-alert` button: outline when showing all, solid and `current` when showing unread only. The header also shows `unread_count` in `messages-unread-badge`. Row links stay on `/my_messages/:id` and request a Turbo stream, so the sidebar does not switch to the mount desk. Back returns to `/my_messages`. Opening `#show` after Accessible `:view` marks that conversation read and clears that person's unread `:message_received` notices for it. The stream updates that row's unread avatar and the badge. It does not replace the list, so an unread-filtered row stays until the filter changes or the page reloads. Index auto-select does not mark read. Inherited-only conversations do not appear as rows.

Dummy screenshots of New message live at `docs/screenshots/new-message-modal-search-chips.png`, `docs/screenshots/new-conversation-after-create.png`, `docs/screenshots/recipient-my-messages.png`, and `docs/screenshots/own-message-sent-status.png`. Dummy screenshots of Casey's inbox (row dots, round unread filter, live badge after open), of seen faces, of a conversation at rest, of a hovered bubble time, of a 15-minute gap divider, of last-line `Sent …` vs seen faces, of a tapped mobile bubble, of the dummy support-only **Open** header badge, of the staff desk with a conversation open (`docs/screenshots/staff-desk-conversation.png`), of renaming a conversation (edit state plus the list row after save, desktop and mobile), of a mount inbox unfiltered and filtered to unread, of the list toolbar with the dummy **New** host button (desktop and mobile), of the list header without a mount name (`docs/screenshots/list-header-staff-desk-desktop.png`, `list-header-staff-desk-mobile.png`, `list-header-my-messages-desktop.png`, `list-header-my-messages-mobile.png`), and of the dummy **Attach a page** composer item (plus menu, picker with **Find a page**, pending chip, outgoing and incoming LinkCards, and the Unavailable card) live in `docs/screenshots/`. The dummy host sets `read_receipts`. It overrides the panel header hooks and `messages_list_toolbar` only on the `support` mount. Dummy-only `register_composer_action` adds **Attach a page** on that mount. The dummy theme is Flatpack `rounded`. Studio help seeds a 5-minute pair and a 25-minute gap so the time divider is visible.

Dummy staff desk and inbox land on that split layout. Support seeds two conversations so the sidebar is real. Inbox still shows one InboxRow plus its panel. Home also links to My messages, which lists Casey's direct grants on both desks. Ada can open the Site inbox desk through inherited workspace access and does not get that row on My messages. Screenshots of that split live in `docs/screenshots/inherited-contact-desk-team.png`, `docs/screenshots/inherited-contact-my-messages-sender.png`, and `docs/screenshots/inherited-contact-my-messages-team.png`. An empty-grant conversation can still open by URL for + Access; it does not leak a bare title into the sidebar.

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
