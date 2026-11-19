# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    class MessageNotice
      def self.partition(recipients, root:)
        return [[], []] if recipients.empty?
        return [[], recipients] unless defined?(RecordingStudioAccessible)

        viewers = RecordingStudioAccessible.actors_with_access(
          recording: root,
          minimum_role: :view
        ).filter_map(&:actor)
        recipients.partition { |recipient| viewers.any? { |viewer| same?(viewer, recipient) } }
      end

      def self.workspace(recipients:, root_recording:, ticket_root:, **notice)
        return if recipients.empty? || root_recording.blank?

        on_ticket = same_root?(root_recording, ticket_root)
        fields = workspace_fields(notice, recipients, root_recording, on_ticket)
        RecordingStudioNotifications.notify_each(**deliverable(fields))
      end

      def self.personal(recipients:, **notice)
        return if recipients.empty?

        RecordingStudioNotifications.notify_each(**deliverable(personal_fields(notice, recipients)))
      end

      def self.same?(left, right)
        left.instance_of?(right.class) && left.id.to_s == right.id.to_s
      end

      def self.workspace_fields(notice, recipients, root_recording, on_ticket)
        notice.merge(
          recipients: recipients,
          type: :message_received,
          title: workspace_title(notice[:group_recording]),
          body: (notice[:body].to_s.truncate(120) if on_ticket),
          root_recording: root_recording,
          recording: on_ticket
        )
      end
      private_class_method :workspace_fields

      def self.personal_fields(notice, recipients)
        notice.merge(
          recipients: recipients,
          type: RecordingStudioMessages::MESSAGE_RECEIVED_PERSONAL_TYPE,
          title: personal_title(notice[:group_recording]),
          body: notice[:body].to_s.truncate(120),
          url: conversation_url(notice[:group_recording]),
          recording: true
        )
      end
      private_class_method :personal_fields

      def self.deliverable(notice)
        attributes = core(notice)
        attributes[:root_recording] = notice[:root_recording] if notice[:root_recording]
        attach_conversation!(attributes, notice)
        attributes[:thread_key] = notice[:group_recording].id.to_s if RecordingStudioMessages.thread_key_supported?
        attributes
      end
      private_class_method :deliverable

      def self.core(notice)
        {
          recipients: notice[:recipients],
          notification_type: notice[:type],
          actor: notice[:actor],
          title: notice[:title],
          body: notice[:body],
          url: notice[:url],
          metadata: metadata(notice[:group_recording], notice[:message_recording])
        }
      end
      private_class_method :core

      def self.attach_conversation!(attributes, notice)
        return unless notice[:recording]
        return unless RecordingStudioMessages.recording_supported?

        attributes[:recording] = notice[:group_recording]
      end
      private_class_method :attach_conversation!

      def self.metadata(group_recording, message_recording)
        { message_group_id: group_recording.id, message_id: message_recording.id }
      end
      private_class_method :metadata

      def self.same_root?(left, right)
        left.present? && right.present? && left.instance_of?(right.class) && left.id.to_s == right.id.to_s
      end
      private_class_method :same_root?

      def self.workspace_title(group_recording)
        title = conversation_title(group_recording)
        return "New message" if title.blank?

        "New message in #{title}"
      end
      private_class_method :workspace_title

      def self.personal_title(group_recording)
        title = conversation_title(group_recording)
        return Copy.t("notices.personal_title") if title.blank?

        Copy.t("notices.personal_title_named", conversation: title)
      end
      private_class_method :personal_title

      def self.conversation_title(group_recording)
        group_recording.recordable&.title.to_s.strip.presence
      end
      private_class_method :conversation_title

      def self.conversation_url(group_recording)
        RecordingStudioMessages::Engine.routes.url_helpers.my_message_path(group_recording)
      end
      private_class_method :conversation_url
    end
  end
end
