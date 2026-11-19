# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    class << self
      private

      def queue_verification(mount:, name:, email:, text:, request:, session:, tags:, source:)
        require_otp_request!(request)
        checked_email = normalize_email(email)
        user = account_for(checked_email)
        ensure_recipient!(mount, user, tags: tags)
        details = contact_details(checked_email, name, text, tags)
        signed_source = challenge_source(user, source)
        Outcome.new(intent: remember_intent(mount, user, request, session, details, source: signed_source))
      end

      def require_otp_request!(request)
        raise Error, Copy.t("errors.users_required") unless users_otp_ready?
        raise ArgumentError, "request is required" if request.nil?
      end

      def contact_details(email, name, text, tags)
        {
          email: email, submitted_name: normalize_name(name), body: text,
          tags: Services::MessageGroupTags.tag_ids(tags),
          expires_at: PublicContactIntent::LIFETIME.from_now
        }
      end

      def remember_intent(mount, user, request, session, details, source:)
        issued = send_challenge!(details.fetch(:email), request, source: source)
        intent = PublicContactIntent.create!(
          details.merge(
            mount_recording_id: mount.id, user_id: user.id, otp_challenge_id: issued.challenge_id
          )
        )
        session[SESSION_KEY] = intent.id
        intent
      end

      def challenge_source(user, source)
        return if source.nil? || user.confirmed?

        source
      end

      def ensure_recipient!(mount, user, tags:)
        return if MountAccess.inherited?(mount)

        raise Error, Copy.t("errors.no_recipient") if opener_among(mount, recipients_for(mount, user, tags: tags)).nil?
      end

      def complete_locked(intent, actor, session)
        raise NotAuthorized, Copy.t("errors.cannot_send") unless actor_matches?(intent, actor)
        return intent.group_recording if intent.fulfilled?
        raise Error, Copy.t("errors.expired") unless intent_open?(intent)

        mount = live_contact_mount_id!(intent.mount_recording_id)
        tags = tags_for_intent(intent)
        settle_identity!(actor, intent, session)
        publish_intent!(intent, actor, mount: mount, tags: tags)
      end

      def tags_for_intent(intent)
        Services::MessageGroupTags.tags_from_ids(intent.tags)
      rescue ArgumentError
        raise Error, Copy.t("errors.contact_target_missing")
      end

      def intent_open?(intent)
        !intent.expired? && intent.open?
      end

      def live_contact_mount_id!(id)
        mount = Services::LiveRecording.find(id)
        return mount if mount&.recordable_type == MESSAGE_MOUNT_TYPE

        raise Error, Copy.t("errors.contact_target_missing")
      end

      def publish_intent!(intent, actor, mount:, tags:)
        group = fulfill!(
          mount: mount, contact: actor, title: intent.submitted_name, body: intent.body,
          recipients: recipients_for(mount, actor, tags: tags), tags: tags
        )
        intent.update!(message_group_id: group.id, body: nil)
        group
      end
    end
  end
end
