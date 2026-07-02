# frozen_string_literal: true

module RecordingStudioMessages
  class MessageCreator
    def initialize(message_group_recording:, actor:, body:, content: {}, metadata: {})
      @message_group_recording = message_group_recording
      @actor = actor
      @body = body.to_s
      @content = content || {}
      @metadata = metadata || {}
    end

    def create!
      raise ActiveRecord::RecordInvalid, RecordingStudioMessages::Message.new unless @body.strip.present?

      recording = @message_group_recording.record(RecordingStudioMessages::Message, actor: @actor) do |message|
        message.message_group = @message_group_recording.recordable
        message.sender_type = @actor.class.name
        message.sender_id = @actor.id
        message.body = @body
        message.content = @content
        message.metadata = @metadata
      end
      touch_group!
      recording
    end

    private

    def touch_group!
      @message_group_recording.recordable.update!(last_message_at: Time.current)
      @message_group_recording.touch
    end
  end
end
