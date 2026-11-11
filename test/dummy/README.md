# Dummy host

This Rails app exists to prove Recording Studio Messages in a real host. It is not the product.

## What It Covers

- Recording Studio Users authentication with seeded staff and customer users
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder, page, and mailbox recordables
- Accessible enabled on Workspace; Messages enabled on Workspace and Mailbox
- Two keyed mounts at once: `support` on Studio Workspace, `inbox` on the Site mailbox
- Seeded conversations, people, an agent, lines, one image attachment, and seen cursors on Studio help (some people stop early, four catch up to the latest line)
- Staff desk (`/staff/desk`) and Inbox (`/inbox`) land on Flatpack `Chat::Layout` `:split` (`Chat::InboxRow` sidebar + `Chat::Panel`). A row click targets the `messages-desk-panel` turbo frame and Layout `showPanel` so a phone tap opens the conversation without remounting the list. Send replaces the thread over Turbo so the new line appears without Action Cable. People with Accessible edit access can click the open conversation name to rename it. The matching list row title updates in place. This dummy sets `read_receipts`, so Studio help shows seen faces in the last group's status slot, including `+N` overflow. Times stay in the DOM and show on hover, tap, or focus. A clock divider sits between lines more than 15 minutes apart. Launch notes has no extra readers, so its last line shows Flatpack `Sent …`. Dummy-only `messages_panel_right_header` / `_mobile` helpers put an **Open** badge in the Studio help header on the `support` mount. The conversation list header has no mount name. Dummy-only `messages_list_toolbar` puts a **New** button beside the unread toggle on that same mount. The Site inbox mount leaves those slots empty. The unread toggle filters that mount's list. Dummy-only `register_composer_action` adds **Attach a page** to the Studio help + menu. The picker loads lazily through `src:` with **Find a page**. Picking **Brand notes** adds a removable composer chip and a LinkCard under the line. The Site inbox + menu stays upload-only.
- My messages (`/recording_studio_messages/my_messages`) lists conversations the signed-in person was added to across both mounts. Opening a row keeps that inbox in the sidebar. Unread conversations show a small avatar status dot. A round bell-alert button filters unread. The header badge is `unread_count`. Opening a row clears that dot and updates the badge without dropping the row from an unread filter. Home shows the same badge next to My messages when the count is above zero.
- Home includes a Contact button that opens the Site mailbox public form in a modal. The full page remains `GET /recording_studio_messages/public_contact?mount_id=`. Hosts that pass `tags:` get a signed `tag_token` on that URL. This dummy does not pass tags.
- Recording Studio 6.1 default layout (back/close chrome), Flatpack CSS/JS, Turbo, and Tailwind source scanning
- `html data-theme="rounded"` so Flatpack named theme tokens apply
- Dummy-only Recording Studio Internationalization (`en` + `fr`). Locale switches with `PATCH /recording_studio_internationalization/locale`. The top nav does not include a language selector
- No Sign out or Root Switchable in the default-layout slot. Core owns back and close.
- Mounted Messages, Users, Accessible, Attachable, Admin, Site Settings, Terms and Conditions, Publishable, and Recording Studio engines
- Site settings live on the current Workspace. Admin is a separate root. Staff (`admin@admin.com`) can open Admin from home. Dummy leaves `admin_notification_root` unset, so staff `:message_received` notices stay on the ticket workspace unless a test opts in
- Terms and Conditions redirects signed-in people to Agree only after a live version exists. Seeds do not publish one

## Quick Start

Dummy credentials (`config/credentials.yml.enc`) use the shared RecordingStudio_* development master key. Set `RAILS_MASTER_KEY` or write that key to `config/master.key` (gitignored). Do not generate a per-repo dummy key.

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

Authenticated pages render `recording_studio/default_layout` through `recording_studio_layout`. Devise requests use `"application"`. Messages screens follow `RecordingStudioMessages.configuration.layout`, which defaults to `nil` and then the core layout. That layout owns the back/close chrome and Flatpack flash alerts. Site Settings 0.5.1 still includes `RecordingStudio::UsesDefaultLayout`, so `config/application.rb` defines an empty module until that gem stops.

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
- Importmap JS, including `@hotwired/turbo-rails`, Flatpack controllers, `flat_pack/heroicons`, and `flat_pack/copy` (InlineEdit needs the copy pin)

The host injects `flat_pack/application` through `app/views/recording_studio/_default_layout_head.html.erb`. That partial also sets `data-theme="rounded"` on `document.documentElement`. Core's layout already sets the same attribute on `<html>`. The dummy copies `lang` onto the `html` tag when the response omits it. Do not put a language switcher or a Sign out button in `:page_nav_right`, the home view, or the chat panel. Do not fork Chat::Panel CSS here.

Flatpack is pinned to `v0.1.349`. Rounded chat bubbles use `--chat-message-radius` (18px) and `--chat-message-padding-x` / `--chat-message-padding-y` (14px by 10px). The messages gemspec requires `flat_pack >= 0.1.349` and `recording_studio >= 6.1.0`. Rebuild Tailwind after this pin. Importmap `pin_all_from` loads `flat-pack--chat-timestamp-reveal`. Recording Studio is pinned to `v6.3.0`. `view_component` is `4.19.0`. Rounded on the live kit is monochrome charcoal, not blue buttons. Outgoing chat bubbles use Flatpack's light neutral surface. `FlatPack::Card` takes `background`, `shadow`, `border`, `hover`, `padding`, `inset`, and `radius` — not `style:`. Users `v0.26.3` and Admin `v2.6.2` pass no Card `style:`. Users calls `flat_pack_page_nav`. `app/helpers/dummy_layout_helper.rb` still turns leftover `recording_studio_page_nav` calls from Admin and Site Settings into `flat_pack_page_nav`. Terms and Conditions still requires Recording Studio below 5, so other sibling tags that also constrain below 5 stay on the Bundler shim. `test/support/widen_recording_studio_requirement.rb` widens those constraints at Bundler load so this app can boot.

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
- `/recording_studio_messages/my_messages` - cross-mount list of conversations the current person was added to
- `/admin` - Site settings section (name, logos, tab icon) for the current workspace
- `/admin/sections/terms` - Terms and Conditions
- `/recording_studio_site_settings` - site name and logos form
- `/recording_studio_terms_and_conditions` - Agree, once a live version exists
- `/recording_studio_messages/message_groups?mount_id=` - engine list for a mount
- `/recording_studio_messages/message_groups/:id` - mounted panel for any conversation
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/recording_studio_internationalization` - dummy language switch (en / fr)
- `/users/sign_in` - Recording Studio Users sign-in page
- `/users/sign_up` - Recording Studio Users sign-up page
- `/up` - Rails health check

## Why This App Exists

Use this app to verify two mounts, Accessible membership, Attachable files, and the chat panel in a host. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

Authenticated pages use Recording Studio's shared default layout. Users auth
screens use `layouts/recording_studio_user/auth`.
