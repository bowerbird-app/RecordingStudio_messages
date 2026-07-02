# frozen_string_literal: true

require "recording_studio_messages/version"
require "recording_studio_messages/engine"
require "recording_studio_messages/configuration"
require "recording_studio_messages/services/base_service"
require "recording_studio_messages/services/example_service"

module RecordingStudioMessages
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end
  end
end
