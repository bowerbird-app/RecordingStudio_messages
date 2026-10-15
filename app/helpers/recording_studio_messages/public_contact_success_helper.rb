# frozen_string_literal: true

module RecordingStudioMessages
  # Optional call-to-action on the public contact "Message sent" step.
  module PublicContactSuccessHelper
    # URL for the optional button on the "Message sent" step. The configured
    # value may be a String or a callable taking mount_recording:, user:, request:.
    def public_contact_success_redirect_url(group_recording)
      value = RecordingStudioMessages.configuration.public_contact_success_redirect_url
      if value.respond_to?(:call)
        value = value.call(
          mount_recording: group_recording&.parent_recording,
          user: public_contact_actor || public_contact_sent_user(group_recording),
          request: request
        )
      end
      value.presence&.to_s
    end

    def public_contact_success_redirect_label
      RecordingStudioMessages.configuration.public_contact_success_redirect_label.presence ||
        messages_t("contact.success_redirect")
    end

    def public_contact_sent_user(group_recording)
      return if group_recording.blank?

      PublicContactIntent.find_by(message_group_id: group_recording.id)&.user
    end
  end
end
