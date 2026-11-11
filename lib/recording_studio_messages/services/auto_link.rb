# frozen_string_literal: true

require "erb"

module RecordingStudioMessages
  module Services
    module AutoLink
      URL = %r{https?://[^\s<]+}i
      TRAILING = /[.,;:!?]+$/
      LINK_ATTRIBUTES = 'rel="noopener noreferrer nofollow" target="_blank"'

      module_function

      def call(text)
        escaped = ERB::Util.html_escape(text.to_s)
        escaped.gsub(URL) { |match| wrap(match) }
      end

      def wrap(match)
        href, trailing = split_trailing(match)
        return match unless http?(href)

        %(<a href="#{href}" #{LINK_ATTRIBUTES}>#{href}</a>#{trailing})
      end

      def split_trailing(match)
        stripped = match.sub(TRAILING, "")
        [stripped, match.delete_prefix(stripped)]
      end

      def http?(href)
        href.match?(%r{\Ahttps?://}i)
      end
    end
  end
end
