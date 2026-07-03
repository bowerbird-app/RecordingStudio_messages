# frozen_string_literal: true

module RecordingStudioMessages
  class ApplicationController < ActionController::Base
    layout -> { RecordingStudioMessages.configuration.layout }

    before_action :set_messages_config
    before_action :set_current_actor
    before_action :set_container_recording, except: []

    private

    attr_reader :messages_config, :current_actor_record, :container_recording
    helper_method :messages_config, :current_actor_record, :container_recording

    def set_messages_config
      @messages_config = RecordingStudioMessages.configuration.message_config!(params[:messages_key])
    end

    def set_current_actor
      resolver = RecordingStudioMessages.configuration.current_actor
      @current_actor_record = if resolver.respond_to?(:call)
                                instance_exec(&resolver)
                              elsif respond_to?(:current_user, true)
                                current_user
                              end
      raise ActionController::RoutingError, "RecordingStudioMessages current actor is not configured" unless @current_actor_record
    end

    def set_container_recording
      result = ContainerResolver.new(messages_config: @messages_config, params: params).resolve
      return @container_recording = result.recording if result.success?

      raise ActionController::RoutingError, result.error
    end

    def create_group_authorized?
      CreateGroupAuthorizer.new(
        messages_config: @messages_config,
        actor: @current_actor_record,
        container_recording: @container_recording,
        controller: self
      ).authorized?
    end

    def require_create_group_authorization!
      head :forbidden unless create_group_authorized?
    end

    def find_message_group_recording!(id, role:)
      recording = RecordingStudio::Recording.unscoped.find(id)
      return recording if recording.recordable_type == "RecordingStudioMessages::MessageGroup" &&
                          recording.parent_recording_id == container_recording.id &&
                          RecordingStudioAccessible.authorized?(actor: current_actor_record, recording: recording, role: role)

      raise ActionController::RoutingError, "Message group was not found or is not visible"
    end
  end
end
