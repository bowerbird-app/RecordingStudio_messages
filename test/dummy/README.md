# Dummy host

This Rails app exists to prove Recording Studio Messages in a real host. It is not the product.

## What It Covers

- Devise authentication with a seeded admin user
- `Current.actor` wiring for Recording Studio events
- Root workspace plus seeded folder and page recordables
- Accessible enabled on Workspace
- Recording Studio default layout (back/close chrome), Flatpack CSS/JS, Turbo, and Tailwind source scanning
- Root Switchable in the default-layout chrome, not a host-only shell
- Mounted `RecordingStudio::Engine` route behavior inside a host app

## Quick Start

```bash
cd test/dummy
bundle install
bin/rails db:setup
bin/dev
```

Run the commands above from the dummy app directory, not the repository root.

Then open the app and sign in with:

- Email: `admin@admin.com`
- Password: `Password`

## Layouts and assets

Authenticated pages include `RecordingStudio::UsesDefaultLayout` and render `recording_studio/default_layout`. That layout owns the back/close chrome and Flatpack flash alerts.

Devise sign-in keeps `layouts/application` so the login card can stay centered. That layout still loads:

- `flat_pack/variables`
- `flat_pack/application`
- `tailwind`
- Importmap JS, including `@hotwired/turbo-rails`

The host injects `flat_pack/application` and the Root Switchable control through `app/views/recording_studio/_default_layout_head.html.erb`. Do not put the switcher or a Sign out button in the home view body.

Tailwind scans dummy views plus Flatpack and Recording Studio gem files. On boot, Root Switchable's source linker adds `vendor/flat_pack` and `vendor/recording_studio` so a local `bin/rails tailwindcss:build` sees those classes. Rebuild Tailwind after changing views.

Use the live Flatpack kit at [https://flatpack.bowerbird.io/](https://flatpack.bowerbird.io/).

## Useful Routes

- `/` - dummy host home page
- `/recording_studio` - redirects to `/` while the mounted Recording Studio engine stays available under that prefix for non-root routes
- `/users/sign_in` - Devise sign-in page
- `/up` - Rails health check

## Why This App Exists

Use this app to verify the renamed messages engine boots in a host. If a layout, route, asset source, or Recording Studio initializer change breaks here, the gem likely needs adjustment before reuse.

This slice does not add message types or screens.

Authenticated pages use Recording Studio's shared default layout. Devise sign-in keeps `layouts/application`.
