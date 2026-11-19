# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class InboundReply
      def self.call(...)
        new(...).call
      end

      def initialize(notification:, recipient:, body:, attachments:)
        @notification = notification
        @recipient = recipient
        @body = body
        @attachments = Array(attachments)
      end

      def call
        group = conversation
        return rejected(:group_missing) unless group
        return rejected(:empty) if blank?

        post(group)
      rescue RecordingStudioMessages::NotAuthorized
        rejected(:not_authorized)
      end

      private

      def post(group)
        RecordingStudioMessages.send_message(
          group_recording: group,
          body: @body.to_s,
          actor: @recipient,
          files: @attachments,
          url: conversation_url(group)
        )
        RecordingStudioNotifications::ReplyResult.ok
      end

      def conversation
        recording = LiveRecording.find(group_id)
        return unless recording&.recordable_type == RecordingStudioMessages::MESSAGE_GROUP_TYPE

        recording
      end

      def group_id
        metadata = @notification.metadata
        return if metadata.blank?

        metadata["message_group_id"]
      end

      def blank?
        @body.to_s.strip.empty? && @attachments.empty?
      end

      def conversation_url(group)
        RecordingStudioMessages::Engine.routes.url_helpers.message_group_path(group)
      end

      def rejected(reason)
        RecordingStudioNotifications::ReplyResult.rejected(reason)
      end
    end
  end
end
