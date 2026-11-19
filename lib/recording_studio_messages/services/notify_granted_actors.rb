# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class NotifyGrantedActors
      def self.call(...)
        new(...).call
      end

      def initialize(group_recording:, message_recording:, actor:, body:, url:, recipients: nil)
        @group_recording = group_recording
        @message_recording = message_recording
        @actor = actor
        @body = body
        @url = url
        @recipients = recipients
      end

      def call
        recipients = other_granted_actors
        return if recipients.empty?
        return file_by_root(recipients) unless RecordingStudioMessages.personal_notices_supported?

        staff, others = divide_staff(recipients)
        file_workspace(staff, admin_root) if staff.any?
        members, guests = MessageNotice.partition(others, root: ticket_root)
        file_workspace(members, ticket_root) if members.any?
        file_personal(guests) if guests.any?
      end

      private

      def other_granted_actors
        notify_candidates.reject { |recipient| MessageNotice.same?(recipient, @actor) }
      end

      def notify_candidates
        return Array(@recipients).compact if @recipients
        return actors_with_effective_access if inherited_group?

        RecordingStudioMessages.granted_actors(@group_recording)
      end

      def inherited_group?
        MountAccess.inherited?(@group_recording&.parent_recording)
      end

      def actors_with_effective_access
        return [] unless defined?(RecordingStudioAccessible)
        return [] if @group_recording.blank?

        RecordingStudioAccessible.actors_with_access(
          recording: @group_recording,
          minimum_role: :view
        ).filter_map(&:actor).uniq
      end

      def file_by_root(recipients)
        recipients.group_by { |recipient| notification_root_for(recipient) }.each do |root_recording, batch|
          file_workspace(batch, root_recording)
        end
      end

      def divide_staff(recipients)
        return [[], recipients] if admin_root.blank?

        recipients.partition { |recipient| staff_recipient?(recipient, admin_root) }
      end

      def file_workspace(recipients, root_recording)
        MessageNotice.workspace(
          **notice_context,
          url: @url,
          recipients: recipients,
          root_recording: root_recording,
          ticket_root: ticket_root
        )
      end

      def file_personal(recipients)
        MessageNotice.personal(**notice_context, recipients: recipients)
      end

      def notice_context
        {
          group_recording: @group_recording,
          message_recording: @message_recording,
          actor: @actor,
          body: @body
        }
      end

      def ticket_root
        @ticket_root ||= @group_recording.root_recording || @group_recording
      end

      def admin_root
        return @admin_root if defined?(@admin_root)

        @admin_root = RecordingStudioMessages.configuration.resolved_admin_notification_root
      end

      def notification_root_for(recipient)
        return ticket_root if admin_root.blank?
        return ticket_root unless staff_recipient?(recipient, admin_root)

        admin_root
      end

      def staff_recipient?(recipient, root)
        return false unless defined?(RecordingStudioAccessible)
        return false if recipient.blank?

        RecordingStudioAccessible.authorized?(
          actor: recipient,
          recording: root,
          role: :view
        )
      end
    end
  end
end
