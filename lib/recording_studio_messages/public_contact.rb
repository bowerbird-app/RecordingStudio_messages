# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    SESSION_KEY = :recording_studio_messages_public_contact_intent_id
    TAKEN_EMAIL = "That email already has an account. Try signing in."
    RATE_LIMITED = "Give it a minute, then try again."
    USERS_REQUIRED = "Public contact needs Recording Studio Users email codes."
    NO_RECIPIENT = "Nobody can receive this message."

    Outcome = Struct.new(:intent, :group_recording, keyword_init: true) do
      def awaiting_verification?
        intent.present? && group_recording.blank?
      end
    end

    module_function

    def enabled?(mount_recording)
      return false unless contact_mount?(mount_recording)

      key = mount_recording.recordable&.key.to_s
      parent = mount_recording.parent_recording
      return false if key.blank? || parent.blank?

      public_contact_keys_for(parent.recordable_type).include?(key)
    end

    def begin(mount_recording:, name:, email:, body:, current_actor:, request:, session:)
      raise Error, Copy.t("errors.not_enabled") unless enabled?(mount_recording)

      text = normalize_body(body)
      return send_now(mount_recording, current_actor, text) if current_actor.present?

      queue_verification(
        mount: mount_recording, name: name, email: email, text: text, request: request, session: session
      )
    end

    def submit_code!(intent:, code:, session:)
      return finish(intent, session) if intent.fulfilled?

      user = accepted_user(intent, code, session)
      return finish(intent, session) unless user

      deliver_verified(intent, user, session)
    end

    def resend!(intent:, request:, session:)
      intent.with_lock { refresh_code!(intent, request, session) }
      intent
    end

    def complete(intent:, actor:)
      intent.with_lock { complete_locked(intent, actor) }
    end
  end
end

require_relative "public_contact/site_name"
require_relative "public_contact/accounts"
require_relative "public_contact/delivery"
require_relative "public_contact/verification"
require_relative "public_contact/intake"
