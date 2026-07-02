# frozen_string_literal: true

module RecordingStudioMessages
  class MessagesController < ApplicationController
    def create
      message_group_recording = RecordingStudio::Recording.unscoped.find(params[:message_group_id])
      unless RecordingStudioAccessible.authorized?(actor: current_actor_record, recording: message_group_recording, role: :edit)
        return head :forbidden
      end

      MessageCreator.new(
        message_group_recording: message_group_recording,
        actor: current_actor_record,
        body: message_params[:body],
        content: message_params[:content] || {},
        metadata: message_params[:metadata] || {}
      ).create!
      redirect_to message_group_path(messages_config.key, message_group_recording, container_recording_id: container_recording.id)
    end

    private

    def message_params
      params.fetch(:message, {}).permit(:body, content: {}, metadata: {})
    end
  end
end
