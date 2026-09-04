# Dummy host

This Rails app exists to prove Recording Studio Messages in a real host. It is not the product.

## What It Covers

- Recording Studio Users authentication with seeded staff and customer users
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder, page, and mailbox recordables
- Accessible enabled on Workspace; Messages enabled on Workspace and Mailbox
- Two keyed mounts at once: `support` on Studio Workspace, `inbox` on the Site mailbox
- Seeded conversations, people, an agent, lines, and one image attachment
- Staff desk (`/staff/desk`) and Inbox (`/inbox`) land on Flatpack `Chat::Layout` `:split` (`Chat::InboxRow` sidebar + `Chat::Panel`). A row click targets the `messages-desk-panel` turbo frame and Layout `showPanel` so a phone tap opens the conversation without remounting the list. Send replaces the thread over Turbo so the new line appears without Action Cable
- Recording Studio default layout (back/close chrome), Flatpack CSS/JS, Turbo, and Tailwind source scanning
- `html data-theme="rounded"` so Flatpack named theme tokens apply
- No Sign out or Root Switchable in the default-layout slot. Core owns back and close.
- Mounted Messages, Users, Accessible, Attachable, and Recording Studio engines

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

Recording Studio Users owns `/users/sign_in` through
`recording_studio_user_auth_for :users`. Users `0.8.2` renders those screens in
`layouts/recording_studio_user/auth` (one full-viewport centered chrome). The
host does not copy or override the gem login view, and it does not wrap auth
in `layouts/application`. Profile and sign-in-method screens are product pages, so
`RecordingStudioUser.config.layout` points at `recording_studio/default_layout`;
pointing it at `application` squeezes them into the leftover Devise shell. Root
Switchable renders in its own `recording_studio_root_switchable/blank` shell
because its screens draw their own PageNav, and the host layout would stack a
second back button. That layout still loads:

- `flat_pack/variables`
- `flat_pack/application`
- `tailwind`
- Importmap JS, including `@hotwired/turbo-rails`

The host injects `flat_pack/application` through `app/views/recording_studio/_default_layout_head.html.erb`. That partial also sets `data-theme="rounded"` on `document.documentElement` because core default layout leaves `<html>` bare. The dummy also copies the attribute onto the `html` tag in the response so the named theme is present without JavaScript. Do not put a switcher or a Sign out button in that slot, the home view, or the chat panel. Do not fork Chat::Panel CSS here.

Flatpack is pinned to `v0.1.148`. Rounded on the live kit is monochrome charcoal,
not blue buttons.

Tailwind scans dummy views plus Flatpack and Recording Studio gem files. On boot, Root Switchable's source linker adds `vendor/flat_pack` and `vendor/recording_studio` so a local `bin/rails tailwindcss:build` sees those classes. Rebuild Tailwind after changing views.

`@source` globs must cover wherever Bundler installed the gems, including
the repo-root `vendor/bundle` GitHub Actions uses, `/usr/local/lib/ruby/gems`
on the devcontainer and Cloud Agent images, and `test/dummy/vendor/bundle`.
A missing glob does not fail the build; it silently drops utilities that only
a mounted engine uses. Accessible's `pt-16` is also listed with `@source inline`
so that padding stays in the build.

Propshaft does not rewrite CSS `@import` statements itself. Flatpack
uses logical imports in `flat_pack/application.css`, so
`config/initializers/flatpack_css_imports.rb` resolves those imports to
fingerprinted asset URLs. Keep the compiler until Flatpack ships imports that
Propshaft can resolve without host help.

Use the live Flatpack kit at [https://flatpack.bowerbird.io/](https://flatpack.bowerbird.io/).

## Useful Routes

- `/` - dummy host home page
- `/staff/desk` - support mount conversation list (Studio help and Launch notes)
- `/inbox` - inbox mount conversation list
- `/recording_studio_messages/message_groups?mount_id=` - engine list for a mount
- `/recording_studio_messages/message_groups/:id` - mounted panel for any conversation
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Recording Studio Users sign-in page
- `/users/sign_up` - Recording Studio Users sign-up page
- `/up` - Rails health check

## Why This App Exists

Use this app to verify two mounts, Accessible membership, Attachable files, and the chat panel in a host. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Authenticated pages use Recording Studio's shared default layout. Users auth
screens use `layouts/recording_studio_user/auth`.
