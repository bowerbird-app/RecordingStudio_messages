# frozen_string_literal: true

require "active_record"
require "recording_studio"
require "recording_studio_accessible"
require "recording_studio_attachable"
require "recording_studio_notifications"
require "flat_pack"
require "recording_studio_messages/version"
require "recording_studio_messages/engine"
require "recording_studio_messages/configuration"

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
