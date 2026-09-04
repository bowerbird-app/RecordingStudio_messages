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

Do not insert `Recording` rows by hand. Do not invent a second access list.

## Screens

A mount opens as Flatpack `Chat::Layout` `:split` (`GET /recording_studio_messages/message_groups`, optional `mount_id`). Index keeps the groups `RecordingStudioAccessible.authorized?` says the current actor can `:view`. That is Accessible on `MessageGroup`, not a second ACL. The sidebar is `Chat::InboxRow` only. The panel slot is the existing `Chat::Panel` inside a `messages-desk-panel` turbo frame. Clicking a row uses the kit path: InboxRow `turbo_frame` replaces that frame, and Layout Stimulus `openPanel` / `showPanel` hides the sidebar under `md`. It does not Turbo-visit show and remount the desk. Core PageNav owns page back and close. Chat::Header has no `back_href`. Layout's stacked Back to conversations stays visible so a half-width window can return to the list. Do not fork `md:grid-cols-[280px_1fr]`. The desk wrapper is `w-full min-w-0` plus the viewport height class. Faces in the header come from Accessible. Composer files go through Attachable.

Rounded is a named Flatpack theme. It has to live on the `html` element. Core often puts `data-theme` on `body` only, which is not enough. The dummy copies rounded onto `html` (a small host helper plus `_default_layout_head.html.erb`). Do not restyle Chat::Panel in this gem. Square PageNav back is Flatpack.

Flatpack `0.1.144` provides the named-theme aliases that keep rounded primary
buttons and mine bubbles charcoal.

Dummy staff desk and inbox land on that split layout. Support seeds two conversations so the sidebar is real. Inbox still shows one InboxRow plus its panel. An empty-grant conversation can still open by URL for + Access; it does not leak a bare title into the sidebar.

Sending does not wait on a cable. The composer posts as a Turbo stream. The response replaces the message list (and the composer, so the field is empty again). A full HTML visit still works and shows a flash. Do not add Action Cable here.

## Related docs

- Product install and API: `README.md`
- Dummy operator guide: `test/dummy/README.md`
- Engine internals: `docs/gem_template/`
- Cloud Agent boot: `docs/cursor-skills.md`
