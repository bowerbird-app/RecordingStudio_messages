# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    module TagToken
      PARAM = :tag_token
      PURPOSE = "recording_studio_messages.public_contact_tags"
      LIFETIME = 24.hours

      module_function

      def generate(mount:, tags:)
        checked = Services::MessageGroupTags.normalize_tags(tags)
        return if checked.empty?

        require_under_parent!(mount, checked)
        verifier.generate(
          { "mount_id" => mount.id.to_s, "tags" => checked.transform_values { |recording| recording.id.to_s } },
          purpose: PURPOSE,
          expires_in: LIFETIME
        )
      end

      def tags_for(mount:, token:)
        return {} if token.blank?

        payload = read!(token)
        unless payload["mount_id"].to_s == mount.id.to_s
          raise RecordingStudioMessages::Error, Copy.t("errors.contact_target_missing")
        end

        tags = Services::MessageGroupTags.tags_from_ids(payload["tags"])
        require_under_parent!(mount, tags)
        tags
      rescue ArgumentError, ActiveSupport::MessageVerifier::InvalidSignature
        raise RecordingStudioMessages::Error, Copy.t("errors.contact_target_missing")
      end

      def read!(token)
        verifier.verify(token.to_s, purpose: PURPOSE)
      end

      def require_under_parent!(mount, tags)
        ancestor = mount.parent_recording
        return if tags.blank?
        raise ArgumentError, "tagged recording is outside the contact tree" if ancestor.blank?
        return if Services::RecordingSubtree.under_parent?(tags.values, ancestor)

        raise ArgumentError, "tagged recording is outside the contact tree"
      end

      def verifier
        Rails.application.message_verifier(PURPOSE)
      end
    end
  end
end
