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
        session: session,
        tags: contact_tags
      )
    end

    def contact_tags
      PublicContact::TagToken.tags_for(mount: @mount, token: params[PublicContact::TagToken::PARAM])
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
      intent = stored_contact_intent
      intent if intent&.open?
    end

    def expired_modal_intent?
      return false unless modal_frame_request?

      intent = stored_contact_intent
      return false unless intent&.expired? && same_contact_mount?(intent)

      @intent = intent
      true
    end

    def stored_contact_intent
      intent_id = session[PublicContact::SESSION_KEY]
      return if intent_id.blank?

      PublicContactIntent.find_by(id: intent_id)
    end

    def find_mount
      return if params[:mount_id].blank?

      recording = RecordingStudio::Recording.find_by(id: params[:mount_id])
      return unless recording&.recordable_type == MESSAGE_MOUNT_TYPE

      recording
    end

    def remember_sent(group)
      session[GROUP_SESSION_KEY] = group&.id
    end

    def sent_group
      recording = RecordingStudio::Recording.find_by(id: session[GROUP_SESSION_KEY])
      return unless recording&.recordable_type == MESSAGE_GROUP_TYPE

      recording
    end

    def missing_contact(_error = nil)
      head :not_found
    end
  end
end
