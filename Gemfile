# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_messages.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", ">= 0.1.349", github: "bowerbird-app/flatpack", tag: "v0.1.376"
gem "recording_studio", ">= 7.0", "< 8.0", github: "bowerbird-app/RecordingStudio", tag: "v7.0.0"
gem "recording_studio_accessible", ">= 0.44.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.44.0"
gem "recording_studio_admin", "~> 2.1", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.16.0"
gem "recording_studio_attachable", ">= 0.28.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.28.0"
# Required by recording_studio_user (git-only; not on RubyGems).
gem "recording_studio_cache", "~> 0.5", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.6.3"
gem "recording_studio_logs", ">= 0.4.1", "< 1.0",
    github: "bowerbird-app/RecordingStudio_logs", tag: "v0.8.0"
gem "recording_studio_metrics", ">= 0.9.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.9.0"
gem "recording_studio_notifications", ">= 0.18.0", "< 1",
    github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.18.0"
# Accessible 0.44 needs Trashable >= 0.17. Trashable registers the kept filter.
gem "recording_studio_trashable",
    github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.17.0"
gem "recording_studio_user", ">= 0.30.0", github: "bowerbird-app/RecordingStudio_users", tag: "v0.30.0"
gem "view_component", "4.19.0"

# Attachable 0.28 depends on Recording Studio API, which depends on Moveable, Icons, and Redis.
gem "recording_studio_api", github: "bowerbird-app/RecordingStudio_api", tag: "v0.24.0"
gem "recording_studio_icons", github: "bowerbird-app/RecordingStudio_icons", tag: "v0.2.1"
gem "recording_studio_moveable", github: "bowerbird-app/RecordingStudio_moveable", tag: "v5.0.0"
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
