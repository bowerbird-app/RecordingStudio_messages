# frozen_string_literal: true

module RecordingStudioMessages
  class CreateGroupAuthorizer
    def initialize(messages_config:, actor:, container_recording:, controller: nil)
      @messages_config = messages_config
      @actor = actor
      @container_recording = container_recording
      @controller = controller
    end

    def authorized?
      case authorization.fetch(:type, :container_access).to_sym
      when :container_access
        RecordingStudioAccessible.authorized?(actor: @actor, recording: @container_recording, role: role)
      when :action
        RecordingStudioAccessible.authorized_action?(
          actor: @actor,
          action: authorization.fetch(:action),
          recording: @container_recording,
          context: context,
          controller: @controller
        )
      else
        false
      end
    rescue KeyError, StandardError
      false
    end

    private

    def authorization
      @messages_config.effective_create_group_authorization
    end

    def role
      authorization.fetch(:role, :edit).to_sym
    end

    def context
      {
        messages_key: @messages_config.key,
        container_type: @messages_config.container_type,
        child_type: "RecordingStudioMessages::MessageGroup"
      }
    end
  end
end
