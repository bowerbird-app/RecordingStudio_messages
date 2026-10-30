# frozen_string_literal: true

source "https://rubygems.org"

require_relative "test/support/widen_recording_studio_requirement"

# Specify your gem's dependencies in recording_studio_messages.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", ">= 0.1.331", github: "bowerbird-app/flatpack", tag: "v0.1.331"
gem "recording_studio", ">= 6.1.0", github: "bowerbird-app/RecordingStudio", tag: "v6.1.0"
gem "recording_studio_accessible", "~> 0.24",
    github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.24.0"
gem "recording_studio_admin", "~> 2.1", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.6.2"
gem "recording_studio_attachable", "~> 0.13",
    github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.21.1"
# Required by recording_studio_user (git-only; not on RubyGems).
gem "recording_studio_cache", "~> 0.5", github: "bowerbird-app/RecordingStudio_cache", tag: "v0.5.1"
gem "recording_studio_logs", ">= 0.4.1", "< 1.0",
    github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.0"
gem "recording_studio_metrics", ">= 0.3.0", "< 1.0",
    github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.6.1"
gem "recording_studio_notifications", ">= 0.3.1", "< 1",
    github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.13.1"
# Admin and Accessible load Trashable query helpers only; pin for Bundler.
gem "recording_studio_trashable",
    github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.11.3",
    require: false
gem "recording_studio_user", "~> 0.16", github: "bowerbird-app/RecordingStudio_users", tag: "v0.26.3"
gem "view_component", "4.19.0"

gem "devise"
gem "puma"
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
