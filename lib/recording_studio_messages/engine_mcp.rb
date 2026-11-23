# frozen_string_literal: true

module RecordingStudioMessages
  module EngineMcp
    def self.included(engine)
      engine.initializer "recording_studio_messages.mcp", after: :load_config_initializers do
        engine.config.to_prepare do
          RecordingStudioMessages::Api::MyMessages.place!
          RecordingStudioMessages::McpCopy.register!
        end
      end
    end
  end
end
