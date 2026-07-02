# frozen_string_literal: true

require_relative "lib/recording_studio_messages/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_messages"
  spec.version     = RecordingStudioMessages::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_messages"
  spec.summary     = "Reusable Recording Studio messaging addon"
  spec.description = "A Rails engine that adds configurable, RecordingStudio-backed message groups and messages with FlatPack UI."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 3.0"
  spec.add_dependency "recording_studio_accessible", ">= 0.4.1"
  spec.add_dependency "flat_pack"
end
