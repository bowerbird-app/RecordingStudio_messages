# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContactSignIn
    private

    # Signs the verified visitor in through the host's Devise/Warden when
    # public_contact_sign_in_after_verification is on. No-op when someone is
    # already signed in or the intent never produced a user.
    def sign_in_verified_contact(intent)
      return unless RecordingStudioMessages.configuration.public_contact_sign_in_after_verification
      return if intent.blank? || public_contact_actor.present?

      intent.reload
      user = intent.user
      return if user.blank? || !intent.fulfilled?

      warden_sign_in(user)
    end

    def warden_sign_in(user)
      if respond_to?(:sign_in, true) && defined?(Devise::Mapping)
        sign_in(Devise::Mapping.find_scope!(user), user)
      elsif (warden = request.env["warden"])
        warden.set_user(user, scope: :user)
      end
    end
  end
end
