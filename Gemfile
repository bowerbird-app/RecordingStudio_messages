# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_messages.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
# Flatpack PR #159 (0.1.135). Named themes rebind primary-wired tokens so
# rounded CTAs are charcoal. Pin the verified PR HEAD, not a merge commit or tag.
gem "flat_pack", "~> 0.1.135", github: "bowerbird-app/flatpack",
                               ref: "daceb04b76578b2d7adfa42a65e1f66f42d24f23"
gem "recording_studio", "~> 4.2", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", "~> 0.7.0", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.7.0"
gem "recording_studio_attachable", "~> 0.4", github: "bowerbird-app/RecordingStudio_attachable", tag: "0.4.0"
gem "recording_studio_notifications", "~> 0.2.5", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.2.5"

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
