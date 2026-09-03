# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_messages.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
gem "flat_pack", "~> 0.1.144", github: "bowerbird-app/flatpack", tag: "v0.1.144"
gem "recording_studio", "~> 4.2", github: "bowerbird-app/RecordingStudio", tag: "v4.2.1"
gem "recording_studio_accessible", "~> 0.9.1",
    github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.9.1"
gem "recording_studio_admin", "~> 2.0.2", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.0.2"
gem "recording_studio_attachable", "~> 0.5.1",
    github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.1"
gem "recording_studio_notifications", "~> 0.3.1",
    github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.3.1"
gem "recording_studio_user", "~> 0.8.0",
    github: "bowerbird-app/RecordingStudio_users",
    ref: "1adc7722ec58fcfeb43ff1e2e96849936a6e9411"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
