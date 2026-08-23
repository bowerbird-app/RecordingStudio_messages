# Dummy host

This Rails app exists to prove Recording Studio Messages in a real host. It is not the product.

## What It Covers

- Devise authentication with seeded staff and customer users
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder, page, and mailbox recordables
- Accessible enabled on Workspace; Messages enabled on Workspace and Mailbox
- Two keyed mounts at once: `support` on Studio Workspace, `inbox` on the Site mailbox
- Seeded conversations, people, an agent, lines, and one image attachment
- Staff desk (`/staff/desk`) and Inbox (`/inbox`) land on Flatpack `Chat::Layout` `:split` (`Chat::InboxRow` sidebar + `Chat::Panel`). Send replaces the thread over Turbo so the new line appears without Action Cable
- Recording Studio default layout (back/close chrome), Flatpack CSS/JS, Turbo, and Tailwind source scanning
- `html data-theme="rounded"` so Flatpack named theme tokens apply (charcoal Send / mine after Flatpack PR #159)
- No Sign out or Root Switchable in the default-layout slot. Core owns back and close.
- Mounted Messages, Accessible, Attachable, and Recording Studio engines

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Staff: `admin@admin.com` / `Password`
- Customer: `casey@example.com` / `Password`

## Layouts and assets

Authenticated pages include `RecordingStudio::UsesDefaultLayout` and render `recording_studio/default_layout`. That layout owns the back/close chrome and Flatpack flash alerts.

Devise sign-in keeps `layouts/application` so the login card can stay centered. That layout still loads:

- `flat_pack/variables`
- `flat_pack/application`
- `tailwind`
- Importmap JS, including `@hotwired/turbo-rails`

The host injects `flat_pack/application` through `app/views/recording_studio/_default_layout_head.html.erb`. That partial also sets `data-theme="rounded"` on `document.documentElement` because core default layout leaves `<html>` bare. The dummy also copies the attribute onto the `html` tag in the response so the named theme is present without JavaScript. Do not put a switcher or a Sign out button in that slot, the home view, or the chat panel. Do not fork Chat::Panel CSS here.

Flatpack is pinned to [PR #159](https://github.com/bowerbird-app/flatpack/pull/159) HEAD (`0.1.135`, `daceb04b76578b2d7adfa42a65e1f66f42d24f23`) so rounded rebinds primary-wired tokens. Rounded on the live kit is monochrome charcoal, not blue buttons.

Tailwind scans dummy views plus Flatpack and Recording Studio gem files. On boot, Root Switchable's source linker adds `vendor/flat_pack` and `vendor/recording_studio` so a local `bin/rails tailwindcss:build` sees those classes. Rebuild Tailwind after changing views.

Use the live Flatpack kit at [https://flatpack.bowerbird.io/](https://flatpack.bowerbird.io/).

## Useful Routes

- `/` - dummy host home page
- `/staff/desk` - support mount conversation list (Studio help and Launch notes)
- `/inbox` - inbox mount conversation list
- `/recording_studio_messages/message_groups?mount_id=` - engine list for a mount
- `/recording_studio_messages/message_groups/:id` - mounted panel for any conversation
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/up` - Rails health check

## Why This App Exists

Use this app to verify two mounts, Accessible membership, Attachable files, and the chat panel in a host. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Authenticated pages use Recording Studio's shared default layout. Devise sign-in keeps `layouts/application`.
