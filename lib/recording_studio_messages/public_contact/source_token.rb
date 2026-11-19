# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContact
    # Signed signup context for one contact form. The hash is request data.
    # Users checks the shape when the code is sent. This gem does not.
    module SourceToken
      PARAM = :source_token
      PURPOSE = "recording_studio_messages.public_contact_source"
      LIFETIME = 24.hours
      SCALAR_TAGS = {
        String => "s",
        Symbol => "y",
        Integer => "i",
        TrueClass => "t",
        FalseClass => "f",
        NilClass => "n"
      }.freeze

      module_function

      def generate(mount:, source:)
        return if source.nil?

        verifier.generate(payload_for(mount, source), purpose: PURPOSE, expires_in: LIFETIME)
      end

      def source_for(mount:, token:)
        return if token.blank?

        read_source(mount, token)
      rescue ArgumentError, ActiveSupport::MessageVerifier::InvalidSignature, TypeError
        raise RecordingStudioMessages::Error, Copy.t("errors.contact_target_missing")
      end

      def read_source(mount, token)
        payload = verifier.verify(token.to_s, purpose: PURPOSE)
        unless matching_mount?(payload, mount)
          raise RecordingStudioMessages::Error, Copy.t("errors.contact_target_missing")
        end

        unpack(payload["source"])
      end

      def matching_mount?(payload, mount)
        payload.is_a?(Hash) && payload["mount_id"].to_s == mount.id.to_s
      end

      def payload_for(mount, source)
        { "mount_id" => mount.id.to_s, "source" => pack(source) }
      end

      def pack(source)
        raise ArgumentError, "source must be a Hash" unless source.is_a?(Hash)

        source.map { |key, value| [key.to_s, SCALAR_TAGS[value.class] || "j", store_value(value)] }
      end

      def store_value(value)
        value.is_a?(Symbol) ? value.to_s : value
      end

      def unpack(entries)
        raise ArgumentError, "source token is unreadable" unless entries.is_a?(Array)

        entries.to_h { |key, tag, stored| [key, restore(tag, stored)] }
      end

      def restore(tag, stored)
        case tag
        when "s" then stored.to_s
        when "y" then stored.to_s.to_sym
        when "i" then Integer(stored)
        when "t" then true
        when "f" then false
        when "n" then nil
        else stored
        end
      end

      def verifier
        Rails.application.message_verifier(PURPOSE)
      end
    end
  end
end
