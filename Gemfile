# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_messages.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"
gem "recording_studio_accessible", "~> 0.58",
    github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.58.0"
gem "recording_studio_admin", "~> 2.20", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.20.0"
gem "recording_studio_attachable", "~> 0.34",
    github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.34.0"
# Required by recording_studio_user (git-only; not on RubyGems).
gem "recording_studio_cache", "~> 0.8", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.8.0"
gem "recording_studio_logs", "~> 0.9",
    github: "bowerbird-app/RecordingStudio_logs", tag: "v0.9.0"
gem "recording_studio_metrics", "~> 0.10",
    github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.10.0"
gem "recording_studio_notifications", "~> 0.21",
    github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.21.1"
# Trashable registers the kept filter.
gem "recording_studio_trashable", "~> 1.3",
    github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.3.0"
gem "recording_studio_user", ">= 0.39.0", github: "bowerbird-app/RecordingStudio_users", tag: "v0.39.0"
gem "view_component", "4.19.0"

# Attachable depends on Recording Studio API, which depends on Moveable, Icons, and Redis.
gem "recording_studio_api", "~> 1.21", github: "bowerbird-app/RecordingStudio_api", tag: "v1.21.2"
gem "recording_studio_icons", "~> 0.5", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.5.0"
gem "recording_studio_moveable", "~> 6.1", github: "bowerbird-app/RecordingStudio_moveable", tag: "v6.1.0"
gem "redis", "~> 5.3"

gem "devise"
gem "puma", "8.1.0"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock", "~> 5.27"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
