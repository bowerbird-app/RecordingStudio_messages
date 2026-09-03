# frozen_string_literal: true

require_relative "lib/recording_studio_messages/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_messages"
  spec.version     = RecordingStudioMessages::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_messages"
  spec.summary     = "Threads and chat for Recording Studio hosts"
  spec.description = "Keyed message mounts, conversations, and a Flatpack chat panel " \
                     "for Recording Studio hosts."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "flat_pack", "~> 0.1.143"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
  spec.add_dependency "recording_studio_accessible", "~> 0.7.0"
  spec.add_dependency "recording_studio_attachable", "~> 0.5.0"
  spec.add_dependency "recording_studio_notifications", "~> 0.2.5"
  spec.add_dependency "recording_studio_user", "~> 0.7.0"
end
