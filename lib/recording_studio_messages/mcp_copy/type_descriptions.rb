# frozen_string_literal: true

require_relative "../api/tool_descriptions"

module RecordingStudioMessages
  module McpCopy
    module TypeDescriptions
      MESSAGE_MOUNT = Api::ToolDescriptions::MESSAGE_MOUNT
      MESSAGE_GROUP = Api::ToolDescriptions::MESSAGE_GROUP
      MESSAGE = Api::ToolDescriptions::MESSAGE

      BY_TYPE = {
        RecordingStudioMessages::MESSAGE_MOUNT_TYPE => MESSAGE_MOUNT,
        RecordingStudioMessages::MESSAGE_GROUP_TYPE => MESSAGE_GROUP,
        RecordingStudioMessages::MESSAGE_TYPE => MESSAGE
      }.freeze
    end
  end
end
