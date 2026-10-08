# frozen_string_literal: true

module RecordingStudioMessages
  module CopyHelper
    def messages_t(...)
      Copy.t(...)
    end

    def messages_copy(override, key, **)
      Copy.value(override, key, **)
    end

    def messages_document_attributes(extra = {})
      attributes = { lang: I18n.locale.to_s }.merge(extra)
      attributes.merge!(recording_studio_locale_attributes) if respond_to?(:recording_studio_locale_attributes)
      return attributes unless respond_to?(:flat_pack_copy_data)

      attributes[:data] = (attributes[:data] || {}).merge(flat_pack_copy_data)
      attributes
    end
  end
end
