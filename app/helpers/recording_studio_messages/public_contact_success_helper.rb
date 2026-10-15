# frozen_string_literal: true

module RecordingStudioMessages
  # The single primary button on the public contact "Message sent" step.
  module PublicContactSuccessHelper
    def public_contact_sent_button_href(group_recording)
      if public_contact_success_redirect_configured?
        public_contact_success_redirect_url(group_recording)
      elsif public_contact_actor && group_recording
        message_group_path(group_recording)
      end
    end

    def public_contact_sent_button_label
      return messages_t("contact.view_conversation") unless public_contact_success_redirect_configured?

      custom_success_redirect_label || messages_t("contact.view_conversation")
    end

    def public_contact_sent_button_data
      return { turbo_frame: "_top" } unless public_contact_success_redirect_configured?

      { turbo_frame: "_top", public_contact_success_redirect: true }
    end

    # String, or a callable taking mount_recording:, group_recording:, user:, request:.
    # Blank hides the button. A nil config keeps the default conversation link.
    def public_contact_success_redirect_url(group_recording)
      value = configured_success_redirect_value(group_recording)
      value.presence&.to_s
    end

    private

    def public_contact_success_redirect_configured?
      !RecordingStudioMessages.configuration.public_contact_success_redirect_url.nil?
    end

    def custom_success_redirect_label
      RecordingStudioMessages.configuration.public_contact_success_redirect_label.presence
    end

    def configured_success_redirect_value(group_recording)
      value = RecordingStudioMessages.configuration.public_contact_success_redirect_url
      return if value.nil?
      return value unless value.respond_to?(:call)

      value.call(
        mount_recording: group_recording&.parent_recording,
        group_recording: group_recording,
        user: public_contact_actor || public_contact_sent_user(group_recording),
        request: request
      )
    end

    def public_contact_sent_user(group_recording)
      return if group_recording.blank?

      PublicContactIntent.find_by(message_group_id: group_recording.id)&.user
    end
  end
end
