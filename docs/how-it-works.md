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
- `send_message` to write a line, attach files, and notify everyone else who has a grant

Do not insert `Recording` rows by hand. Do not invent a second access list.

## Screens

v1 is a single Flatpack chat panel: header, messages, composer. Core default layout owns back and close. Faces in the header come from Accessible. Composer files go through Attachable.

There is no group list in this version. Dummy staff and customer pages each open one seeded panel.

## Related docs

- Product install and API: `README.md`
- Dummy operator guide: `test/dummy/README.md`
- Engine internals: `docs/gem_template/`
