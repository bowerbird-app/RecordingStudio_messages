# Recording Studio Messages

Threads and chat for Recording Studio hosts.

This slice is the renamed engine plus family pins. Message types, groups, and screens come later. GitHub hosting is not a reason to skip the gemspec pins.

## Install

Add the gem next to Recording Studio 4.2, Accessible, Attachable, Notifications, and Flatpack.

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.7.0"
gem "recording_studio_attachable", github: "bowerbird-app/RecordingStudio_attachable", tag: "0.4.0"
gem "recording_studio_notifications", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.2.5"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.133"
gem "recording_studio_messages", github: "bowerbird-app/RecordingStudio_messages"
```

```ruby
# gemspec / host Gemfile constraints
gem "recording_studio", "~> 4.2"
gem "recording_studio_accessible", "~> 0.7.0"
gem "recording_studio_attachable", "~> 0.4"
gem "recording_studio_notifications", "~> 0.2.5"
gem "flat_pack", "~> 0.1.133"
```

Then:

```bash
bundle install
bin/rails generate recording_studio_messages:install
bin/rails generate recording_studio_messages:migrations
bin/rails db:migrate
```

Notifications must not depend on this gem. This gem depends on Notifications.

## Dummy host

`test/dummy/` is a host that proves the gem. It is not the product.

Authenticated dummy pages use Recording Studio's shared default layout (`UsesDefaultLayout` / `recording_studio/default_layout`) so back/close chrome and Flatpack alerts come from core. Root Switchable sits in that chrome. Devise sign-in keeps `layouts/application` and still loads Flatpack CSS/JS plus Turbo.

| Field    | Value           |
|----------|-----------------|
| Email    | admin@admin.com |
| Password | Password        |

Dummy kit pins resolved on 2026-08-22 from each repo's latest GitHub tag and `version.rb` on the default branch:

| Gem | Constraint | Tag | Default-branch `VERSION` |
|---|---|---|---|
| `recording_studio` | `~> 4.2` | `v4.2.0` | `4.2.0` |
| `recording_studio_accessible` | `~> 0.7.0` | `v0.7.0` | `0.7.0` |
| `recording_studio_attachable` | `~> 0.4` | `0.4.0` | `0.4.0` |
| `recording_studio_notifications` | `~> 0.2.5` | `v0.2.5` | `0.2.5` |
| `flat_pack` (repo `bowerbird-app/flatpack`) | `~> 0.1.133` | `v0.1.133` | `0.1.134` (untagged) |

There is no `recording_studio_flatpack` gem. The UI kit is `flat_pack` from [github.com/bowerbird-app/flatpack](https://github.com/bowerbird-app/flatpack). Use the live kit at [https://flatpack.bowerbird.io/](https://flatpack.bowerbird.io/).

## Flatpack

All screens use Flatpack ViewComponents. See the [Flatpack README](https://github.com/bowerbird-app/flatpack) and the live kit at [https://flatpack.bowerbird.io/](https://flatpack.bowerbird.io/).

## Documentation

Engine internals stay in `docs/gem_template/` as architectural reference. The README and dummy app are the source of truth for this gem.
