# frozen_string_literal: true

require "recording_studio"
require "recording_studio_accessible"
require "flat_pack"
require "recording_studio_messages/version"
require "recording_studio_messages/dependency_check"
RecordingStudioMessages::DependencyCheck.verify!
require "recording_studio_messages/configuration"
require "recording_studio_messages/engine"
require "recording_studio_messages/services/create_group_authorizer"
require "recording_studio_messages/services/container_resolver"
require "recording_studio_messages/services/message_group_finder"
require "recording_studio_messages/services/message_group_paginator"
require "recording_studio_messages/services/message_history_paginator"
require "recording_studio_messages/services/recipient_resolver"
require "recording_studio_messages/services/recipient_search"
require "recording_studio_messages/services/participant_access"
require "recording_studio_messages/services/message_creator"
require "recording_studio_messages/services/message_group_creator"

module RecordingStudioMessages
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end
