# frozen_string_literal: true

module RecordingStudioMessages
  class MessageGroupFinder
    def initialize(messages_config:, actor:, container_recording:, limit: nil, offset: nil)
      @messages_config = messages_config
      @actor = actor
      @container_recording = container_recording
      @limit = limit
      @offset = offset
    end

    def groups
      candidate_scope.filter do |recording|
        RecordingStudioAccessible.authorized?(actor: @actor, recording: recording, role: :view)
      end
    end

    private

    def candidate_scope
      scope = RecordingStudio::Recording.unscoped.where(
        parent_recording_id: @container_recording.id,
        recordable_type: "RecordingStudioMessages::MessageGroup"
      ).order(updated_at: :desc)
      scope = scope.limit(@limit) if @limit
      scope = scope.offset(@offset) if @offset
      scope.includes(:recordable)
    end
  end
end
