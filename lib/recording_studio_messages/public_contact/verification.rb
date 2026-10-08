# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    class << self
      private

      def queue_verification(mount:, name:, email:, text:, request:, session:)
        raise Error, Copy.t("errors.users_required") unless users_otp_ready?

        normalized_email = normalize_email(email)
        user, purpose = account_for(normalized_email)
        ensure_recipient!(mount, user)
        intent = store_intent(
          mount: mount, user: user, purpose: purpose, name: name, email: normalized_email, text: text,
          request: request, session: session
        )
        session[SESSION_KEY] = intent.id
        Outcome.new(intent: intent)
      end

      def ensure_recipient!(mount, user)
        raise Error, Copy.t("errors.no_recipient") if opener_among(mount, recipients_for(mount, user)).nil?
      end

      def store_intent(mount:, user:, purpose:, name:, email:, text:, request:, session:)
        issued = issue_otp!(user: user, purpose: purpose, request: request, session: session, rate_limit_scope: :issue)
        PublicContactIntent.create!(
          mount_recording_id: mount.id,
          user_id: user.id,
          otp_challenge_id: issued.challenge_id,
          email: email,
          submitted_name: normalize_name(name),
          body: text,
          expires_at: PublicContactIntent::LIFETIME.from_now
        )
      end

      def accepted_user(intent, code, session)
        result = verify_submitted_code(intent, code, session)
        return result.user if result.success?

        intent.reload
        raise Error, Copy.t("errors.code_mismatch") unless intent.fulfilled?
      end

      def verify_submitted_code(intent, code, session)
        proof = RecordingStudioUser.otp_proof(intent.otp_challenge_id)
        raise Error, Copy.t("errors.code_mismatch") if proof.nil?

        RecordingStudioUser.verify_otp!(
          challenge_id: intent.otp_challenge_id, code: code, purpose: proof.purpose, session: session
        )
      end

      def deliver_verified(intent, user, session)
        group = complete(intent: intent, actor: user)
        session.delete(SESSION_KEY)
        group
      end

      def refresh_code!(intent, request, session)
        raise Error, Copy.t("errors.already_sent") if intent.fulfilled?
        raise Error, Copy.t("errors.expired") if intent.expired?

        issued = resend_live_code(intent, request, session)
        intent.update!(otp_challenge_id: issued.challenge_id)
      end

      def resend_live_code(intent, request, session)
        user = RecordingStudioUser.config.user_class.find(intent.user_id)
        proof = RecordingStudioUser.otp_proof(intent.otp_challenge_id)
        raise Error, Copy.t("errors.confirm_code") if proof.nil?

        call_users_otp do
          RecordingStudioUser.resend_otp!(user: user, purpose: proof.purpose, request: request, session: session)
        end
      end

      def complete_locked(intent, actor)
        raise NotAuthorized, Copy.t("errors.cannot_send") unless actor_matches?(intent, actor)
        return intent.group_recording if intent.fulfilled?
        raise Error, Copy.t("errors.expired") unless intent_open?(intent)

        settle_identity!(actor, intent)
        publish_intent!(intent, actor)
      end

      def intent_open?(intent)
        !intent.expired? && intent.open?
      end

      def publish_intent!(intent, actor)
        mount = RecordingStudio::Recording.find(intent.mount_recording_id)
        group = fulfill!(
          mount: mount, contact: actor, title: intent.submitted_name, body: intent.body,
          recipients: recipients_for(mount, actor)
        )
        intent.update!(message_group_id: group.id, body: nil)
        group
      end

      def finish(intent, session)
        session.delete(SESSION_KEY)
        intent.group_recording
      end
    end
  end
end
