# frozen_string_literal: true

module RecordingStudioMessages
  module DependencyCheck
    MINIMUM_ACCESSIBLE_VERSION = Gem::Version.new("0.4.1")

    module_function

    def verify!
      verify_recording_studio_accessible!
    end

    def verify_recording_studio_accessible!
      unless defined?(RecordingStudioAccessible)
        raise LoadError, "recording_studio_messages requires recording_studio_accessible >= #{MINIMUM_ACCESSIBLE_VERSION}"
      end

      version = Gem::Version.new(RecordingStudioAccessible::VERSION.to_s)
      return if version >= MINIMUM_ACCESSIBLE_VERSION

      raise LoadError,
            "recording_studio_messages requires recording_studio_accessible >= #{MINIMUM_ACCESSIBLE_VERSION}; " \
            "found #{version}"
    end
  end
end
