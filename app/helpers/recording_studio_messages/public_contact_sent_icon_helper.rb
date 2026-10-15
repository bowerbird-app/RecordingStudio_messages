# frozen_string_literal: true

module RecordingStudioMessages
  # Heroicon name or image for the public contact "Message sent" slot.
  module PublicContactSentIconHelper
    IMAGE_EXTENSIONS = %w[png jpg jpeg gif webp svg avif ico].freeze

    def public_contact_sent_icon
      RecordingStudioMessages.configuration.public_contact_sent_icon.presence
    end

    # A path, URL, or image filename is an <img> src. Anything else is a heroicon.
    def public_contact_sent_image?(value = public_contact_sent_icon)
      source = value.to_s
      return false if source.blank?

      path = source.split(/[?#]/, 2).first
      extension = File.extname(path).delete_prefix(".").downcase
      source.include?("/") || IMAGE_EXTENSIONS.include?(extension)
    end
  end
end
