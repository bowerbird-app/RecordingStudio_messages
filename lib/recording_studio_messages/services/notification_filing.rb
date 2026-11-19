# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class NotificationFiling
      def self.root_for(group_recording:, recipient:)
        new(group_recording).root_for(recipient)
      end

      def self.include_line?(root_recording)
        admin_root = RecordingStudioMessages.configuration.resolved_admin_notification_root
        admin_root.blank? || !same_recording?(root_recording, admin_root)
      end

      def self.same_recording?(left, right)
        left.present? && right.present? && left.instance_of?(right.class) && left.id.to_s == right.id.to_s
      end

      def initialize(group_recording)
        @group_recording = group_recording
      end

      def root_for(recipient)
        chosen = preferred_root_for(recipient)
        return chosen if viewable?(recipient, chosen)
        return @group_recording if viewable?(recipient, @group_recording)

        chosen
      end

      private

      def preferred_root_for(recipient)
        admin_root = RecordingStudioMessages.configuration.resolved_admin_notification_root
        return ticket_root if admin_root.blank? || !staff?(recipient, admin_root)

        admin_root
      end

      def ticket_root
        @ticket_root ||= @group_recording.root_recording || @group_recording
      end

      def staff?(recipient, admin_root)
        return false unless defined?(RecordingStudioAccessible)
        return false if recipient.blank?

        RecordingStudioAccessible.authorized?(actor: recipient, recording: admin_root, role: :view)
      end

      def viewable?(recipient, recording)
        return false unless defined?(RecordingStudioAccessible)
        return false if recipient.blank? || recording.blank?

        RecordingStudioAccessible.authorized_action?(actor: recipient, action: :view, recording: recording)
      end
    end
  end
end
