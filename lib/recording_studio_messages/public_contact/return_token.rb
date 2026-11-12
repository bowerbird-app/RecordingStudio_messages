# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    # A short-lived, purpose-scoped pointer to one pending contact.
    # Users sends the person back to this path. It does not call us.
    module ReturnToken
      PARAM = :contact_token
      PURPOSE = "recording_studio_messages.public_contact_return"
      LIFETIME = 15.minutes

      module_function

      def generate(intent)
        verifier.generate(
          { "intent_id" => intent.id.to_s },
          purpose: PURPOSE,
          expires_in: LIFETIME
        )
      end

      def intent_for(token)
        payload = verifier.verified(token.to_s, purpose: PURPOSE)
        return if payload.blank?

        PublicContactIntent.find_by(id: payload["intent_id"])
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        nil
      end

      def verifier
        Rails.application.message_verifier(PURPOSE)
      end
    end
  end
end
