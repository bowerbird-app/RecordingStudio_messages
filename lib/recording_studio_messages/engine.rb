# frozen_string_literal: true

module RecordingStudioMessages
  class Engine < ::Rails::Engine
    isolate_namespace RecordingStudioMessages

    initializer "recording_studio_messages.register_action" do
      RecordingStudioAccessible.register_action(
        :"recording_studio_messages.create_group",
        label: "Create message group",
        description: "Allows an actor to start a new message group under a messages container.",
        source: "recording_studio_messages",
        recording_required: true
      )
    end

    initializer "recording_studio_messages.configure_recordables", after: :load_config_initializers do
      config.to_prepare do
        RecordingStudioMessages.configuration.messages.each_value(&:validate!)
        RecordingStudioMessages::MessageGroup.declare_recording_studio_recordable! if defined?(RecordingStudioMessages::MessageGroup)
        RecordingStudioMessages::Message.declare_recording_studio_recordable! if defined?(RecordingStudioMessages::Message)
      end
    end
  end
end
