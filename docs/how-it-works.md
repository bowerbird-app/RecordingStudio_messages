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

Notifications are facts, not recordings. They live in the Notifications tables. Participants are not a type — people and agents are actors with Accessible grants on the conversation.

## Writes

Use the public helpers:

- `ensure_message_mount` to hang or find a keyed mount
- `create_group` to open a conversation and grant the first owner
- `viewable_group_recordings` to list conversations the current actor can view
- `send_message` to write a line, attach files, and notify everyone else who has a grant

`NotifyGrantedActors` files `:message_received` under the conversation root unless the host sets `admin_notification_root`. That option is a recording or a callable that returns one. Recipients with Accessible `:view` on it (staff, the same check `Api::Access.can_view?` uses on the Admin root) get that recording as `root_recording`. Other recipients keep the ticket root. Conversation placement does not change. The notification type stays `scope: :root`. When the filing root is not the message's tree root, the notice omits `recording` so Notifications' root check still holds. URL and metadata stay.

Do not insert `Recording` rows by hand. Do not invent a second access list.

## Screens

A mount opens as Flatpack `Chat::Layout` `:split` (`GET /recording_studio_messages/message_groups`, optional `mount_id`). Index keeps the groups `RecordingStudioAccessible.authorized?` says the current actor can `:view`. That is Accessible on `MessageGroup`, not a second ACL. The sidebar is `Chat::InboxRow` only. The panel slot is the existing `Chat::Panel` inside a `messages-desk-panel` turbo frame. Clicking a row uses the kit path: InboxRow `turbo_frame` replaces that frame, and Layout Stimulus `openPanel` / `showPanel` hides the sidebar under the split breakpoint (`sm` by default). It does not Turbo-visit show and remount the desk. The engine controller sets `recording_studio_layout { RecordingStudioMessages.configuration.layout }`. `layout` defaults to `nil`, which falls through to `RecordingStudio.configuration.layout` and then `recording_studio/default_layout`. A string names a layout. `false` renders none. A callable must be keyword-only (`controller:`) and return a String, `nil`, or `false`. Views set `content_for :title` so the layout draws one page heading. Back and close use `flat_pack_page_nav`. Chat::Header has no `back_href`. Layout's stacked Back to conversations stays visible so a stacked window can return to the list. Do not fork Chat::Layout split CSS. The desk wrapper is `w-full min-w-0` plus the viewport height class. Faces in the header come from Accessible unless the mount key is `membership_locked`. Composer files go through Attachable.

Rounded is a named Flatpack theme. Recording Studio 6.1's default layout sets `data-theme="rounded"` on `<html>`. The dummy head partial still sets it from JavaScript, and a host helper copies `lang` onto `<html>` when the tag omits it. Do not restyle Chat::Panel in this gem.

Flatpack `>= 0.1.315` (pinned tag `v0.1.315`) keeps rounded primary buttons charcoal, a fluid Chat::Layout split from `sm`, and outgoing bubbles on the neutral surface. `v0.1.319` is not a published tag. This gem requires `recording_studio >= 6.1.0` and `flat_pack >= 0.1.315`. `view_component` locks at `4.19.0`.

Dummy staff desk and inbox land on that split layout. Support seeds two conversations so the sidebar is real. Inbox still shows one InboxRow plus its panel. An empty-grant conversation can still open by URL for + Access; it does not leak a bare title into the sidebar.

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
