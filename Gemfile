# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_messages.gemspec
gemspec

# These gems are not published to RubyGems; resolve the gemspec pins from GitHub.
# Flatpack v0.1.143 matches Recording Studio Users 0.7.0.
gem "flat_pack", "~> 0.1.143", github: "bowerbird-app/flatpack", tag: "v0.1.143"
gem "recording_studio", "~> 4.2", github: "bowerbird-app/RecordingStudio", tag: "v4.2.0"
gem "recording_studio_accessible", "~> 0.7.0", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.7.0"
gem "recording_studio_admin", "~> 2.0", github: "bowerbird-app/RecordingStudio_admin", tag: "v2.0.2"
gem "recording_studio_attachable", "~> 0.5.0", github: "bowerbird-app/RecordingStudio_attachable", tag: "v0.5.0"
gem "recording_studio_notifications", "~> 0.2.5", github: "bowerbird-app/RecordingStudio_notifications", tag: "v0.2.5"
gem "recording_studio_user", "~> 0.7.0", github: "bowerbird-app/RecordingStudio_users", tag: "v0.7.0"

# Host Devise actor — Recording Studio Users identifies people on top of this.
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
