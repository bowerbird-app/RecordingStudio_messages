# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    module MessageReferenceFallback
      module_function

      def apply(body, references)
        text = body.to_s
        return text if text.strip.present?

        Array(references).filter_map { |item| title_for(item) }.join(", ")
      end

      def title_for(item)
        return hash_title(item) if item.is_a?(Hash)

        if item.respond_to?(:unavailable?)
          return Copy.t("composer.linked_item") if item.unavailable?

          return title_for(item.recording)
        end
        return recording_title(item) if item.respond_to?(:recordable)

        nil
      end

      def hash_title(item)
        (item[:title] || item["title"]).to_s.strip.presence
      end

      def recording_title(recording)
        recordable = recording.recordable
        return if recordable.blank?
        return recordable.title.to_s.strip.presence if recordable.respond_to?(:title)
        return recordable.name.to_s.strip.presence if recordable.respond_to?(:name)

        nil
      end
    end
  end
end
