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

        recipients.group_by { |recipient| notification_root_for(recipient) }.each do |root_recording, batch|
          RecordingStudioNotifications.notify_each(
            **notification_attributes(batch, root_recording: root_recording)
          )
        end
      end

      private

      def other_granted_actors
        RecordingStudioMessages.granted_actors(@group_recording).reject do |recipient|
          same_actor?(recipient, @actor)
        end
      end

      def notification_attributes(recipients, root_recording:)
        {
          recipients: recipients,
          notification_type: :message_received,
          actor: @actor,
          recording: @message_recording,
          root_recording: root_recording
        }.merge(notification_copy)
      end

      def notification_root_for(recipient)
        ticket_root = @group_recording.root_recording || @group_recording
        admin_root = RecordingStudioMessages.configuration.resolved_admin_notification_root
        return ticket_root if admin_root.blank?
        return ticket_root unless staff_recipient?(recipient, admin_root)

        admin_root
      end

      def staff_recipient?(recipient, admin_root)
        return false unless defined?(RecordingStudioAccessible)
        return false if recipient.blank?

        RecordingStudioAccessible.authorized?(
          actor: recipient,
          recording: admin_root,
          role: :view
        )
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
