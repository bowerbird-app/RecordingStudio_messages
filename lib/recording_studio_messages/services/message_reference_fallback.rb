# frozen_string_literal: true

module RecordingStudioMessages
  module Services
    module MessageReferenceFallback
      module_function

      def apply(body, references)
        Array(references).reduce(body.to_s) { |text, item| append(text, item_hash(item)) }
      end

      def item_hash(item)
        return keys(item) if item.is_a?(Hash)
        return { title: title_for(item) } if item.respond_to?(:recordable)

        {}
      end

      def keys(item)
        {
          title: item[:title] || item["title"],
          url: item[:url] || item["url"],
          recording_id: item[:recording_id] || item["recording_id"]
        }
      end

      def title_for(recording)
        recordable = recording.recordable
        return if recordable.blank?
        return unless recordable.respond_to?(:title)

        recordable.title
      end

      def append(body, item)
        title = item[:title].to_s.strip.presence
        url = item[:url].to_s.strip.presence
        return body if title.blank? && url.blank?

        line = [title, url].compact.join("\n")
        return body if duplicate?(body, title, url)
        return line if body.blank?

        "#{body.rstrip}\n\n#{line}"
      end

      def duplicate?(body, title, url)
        (url.present? && body.include?(url)) || (url.blank? && title.present? && body.include?(title))
      end
    end
  end
end
