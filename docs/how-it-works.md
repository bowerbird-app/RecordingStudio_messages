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

Rounded is a named Flatpack theme. It has to live on the `html` element. Core often puts `data-theme` on `body` only, which is not enough. The dummy copies rounded onto `html` (a small host helper plus `_default_layout_head.html.erb`). Do not restyle Chat::Panel in this gem. Square PageNav back is Flatpack.

Primary buttons and mine bubbles stay on `:root` aliases in older Flatpack. That is why the dummy pins Flatpack [PR #159](https://github.com/bowerbird-app/flatpack/pull/159) HEAD (`0.1.135`, `daceb04b76578b2d7adfa42a65e1f66f42d24f23`): named themes rebind those tokens so rounded CTAs are charcoal. There is no `v0.1.135` tag.

There is no group list in this version. Dummy staff and customer pages each open one seeded panel.

## Related docs

- Product install and API: `README.md`
- Dummy operator guide: `test/dummy/README.md`
- Engine internals: `docs/gem_template/`
