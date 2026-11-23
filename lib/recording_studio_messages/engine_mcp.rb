# frozen_string_literal: true

module RecordingStudioMessages
  class Engine
    initializer "recording_studio_messages.mcp", after: :load_config_initializers do
      config.to_prepare do
        RecordingStudioMessages::McpCopy.register!
      end
    end
  end
end
