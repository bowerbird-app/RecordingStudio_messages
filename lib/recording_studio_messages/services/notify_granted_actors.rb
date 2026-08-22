# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class NotifyGrantedActors
      def self.call(...)
        new(...).call
      end

      def initialize(group_recording:, message_recording:, actor:, body:, url:)
        @group_recording = group_recording
        @message_recording = message_recording
        @actor = actor
        @body = body
        @url = url
      end

      def call
        recipients = other_granted_actors
        return if recipients.empty?

        RecordingStudioNotifications.notify_each(**notification_attributes(recipients))
      end

      private

      def other_granted_actors
        RecordingStudioMessages.granted_actors(@group_recording).reject do |recipient|
          same_actor?(recipient, @actor)
        end
      end

      def notification_attributes(recipients)
        {
          recipients: recipients,
          notification_type: :message_received,
          actor: @actor,
          recording: @message_recording,
          root_recording: @group_recording.root_recording
        }.merge(notification_copy)
      end

      def notification_copy
        {
          title: notification_title,
          body: @body.to_s.truncate(120),
          url: @url,
          metadata: {
            message_group_id: @group_recording.id,
            message_id: @message_recording.id
          }
        }
      end

      def notification_title
        title = @group_recording.recordable&.title
        return "New message" if title.blank?

        "New message in #{title}"
      end

      def same_actor?(left, right)
        left.instance_of?(right.class) && left.id.to_s == right.id.to_s
      end
    end
  end
end
