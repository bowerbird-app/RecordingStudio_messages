# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    class << self
      private

      def settle_identity!(actor, intent)
        RecordingStudioUser.complete_email_proof!(
          user: actor,
          challenge_id: intent.otp_challenge_id,
          profile_attributes: profile_attributes_for(intent)
        )
      rescue ArgumentError
        raise Error, Copy.t("errors.confirm_code")
      end

      def profile_attributes_for(intent)
        first_name, last_name = intent.submitted_name.to_s.strip.split(/\s+/, 2)
        { first_name: first_name, last_name: last_name }
      end

      def actor_matches?(intent, actor)
        return false if actor.blank? || !actor.respond_to?(:id) || !actor.respond_to?(:email)

        actor.id.to_s == intent.user_id.to_s && actor.email.to_s.strip.downcase == intent.email.to_s
      end

      def signed_in_title(actor)
        named = actor.name.to_s.strip if actor.respond_to?(:name)
        named = nil if named.blank?
        (named || email_local_title(actor).presence || "Message").truncate(120)
      end

      def email_local_title(actor)
        return unless actor.respond_to?(:email)

        actor.email.to_s.split("@").first.to_s.titleize.presence
      end

      def normalize_body(body)
        text = body.to_s.strip
        raise Error, Copy.t("errors.write_message") if text.blank?
        raise Error, Copy.t("errors.message_too_long") if text.length > 10_000

        text
      end

      def normalize_name(name)
        submitted = name.to_s.strip
        raise Error, Copy.t("errors.enter_name") if submitted.blank?
        raise Error, Copy.t("errors.name_too_long") if submitted.length > 120

        submitted
      end

      def normalize_email(email)
        normalized = email.to_s.strip.downcase
        raise Error, Copy.t("errors.enter_email") unless email_shaped?(normalized)

        normalized
      end

      def email_shaped?(normalized)
        local, domain = normalized.split("@", 2)
        normalized.present? && normalized.count("@") == 1 && local.present? && domain.present? && domain.include?(".")
      end

      def contact_mount?(mount_recording)
        mount_recording.present? && mount_recording.recordable_type == MESSAGE_MOUNT_TYPE
      end

      def public_contact_keys_for(parent_type)
        flag = contact_flag_for(parent_type)
        return [] if flag.blank?
        return configured_message_keys(parent_type) if flag == true

        Array(flag).map(&:to_s)
      end

      def contact_flag_for(parent_type)
        message_options(parent_type)[:public_contact]
      end

      def configured_message_keys(parent_type)
        options = message_options(parent_type)
        Array(options[:keys] || options[:key]).map(&:to_s)
      end

      def message_options(parent_type)
        RecordingStudio.capability_options(:messages, for: parent_type) || {}
      end
    end
  end
end
