# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContactFlow
    GROUP_SESSION_KEY = :recording_studio_messages_public_contact_group_id

    private

    def public_contact_layout
      modal_frame_request? ? false : "recording_studio_messages/public_contact"
    end

    def enabled_mount
      mount = find_mount
      mount if mount && RecordingStudioMessages.public_contact_enabled?(mount)
    end

    def start_contact
      RecordingStudioMessages.begin_public_contact(
        mount_recording: @mount,
        name: params[:name],
        email: params[:email],
        body: params[:body],
        current_actor: public_contact_actor,
        request: request,
        session: session
      )
    end

    def redirect_for(outcome)
      if outcome.group_recording
        remember_sent(outcome.group_recording)
        redirect_to_sent
      else
        redirect_to public_contact_verify_path(presentation_params)
      end
    end

    def redirect_to_sent
      redirect_to public_contact_sent_path(presentation_params)
    end

    def presentation_params
      return {} unless modal_presentation?

      { presentation: PublicContactHelper::MODAL }.merge(
        modal_display_params(params[:introduction], params[:submit_label])
      )
    end

    def resume_verification?
      return false unless modal_frame_request?
      return false if public_contact_actor.present?

      intent = open_contact_intent
      return false unless same_contact_mount?(intent)

      @intent = intent
      true
    end

    def same_contact_mount?(intent)
      intent.present? && intent.mount_recording_id.to_s == @mount.id.to_s
    end

    def open_contact_intent
      intent_id = session[PublicContact::SESSION_KEY]
      return if intent_id.blank?

      intent = PublicContactIntent.find_by(id: intent_id)
      intent if intent&.open?
    end

    def find_mount
      return if params[:mount_id].blank?

      recording = RecordingStudio::Recording.find_by(id: params[:mount_id])
      return unless recording&.recordable_type == MESSAGE_MOUNT_TYPE

      recording
    end

    def session_intent
      PublicContactIntent.find(session[PublicContact::SESSION_KEY])
    end

    def remember_sent(group)
      session[GROUP_SESSION_KEY] = group&.id
    end

    def sent_group
      recording = RecordingStudio::Recording.find_by(id: session[GROUP_SESSION_KEY])
      return unless recording&.recordable_type == MESSAGE_GROUP_TYPE

      recording
    end

    def expired_contact
      return missing_contact unless modal_frame_request?

      render :expired, status: :unprocessable_entity
    end

    def missing_contact(_error = nil)
      head :not_found
    end

    def contact_error(error)
      if modal_frame_request? && @intent&.expired?
        render :expired, status: :unprocessable_entity
      else
        flash.now[:alert] = error.message
        render error_template, status: :unprocessable_entity
      end
    end

    def error_template
      %w[verify submit_verification resend].include?(action_name) ? :verify : :show
    end
  end
end
