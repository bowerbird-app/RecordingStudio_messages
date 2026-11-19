# frozen_string_literal: true

module RecordingStudioMessages
  module PublicContactSourceHelper
    def contact_source_token(mount, source)
      return PublicContact::SourceToken.generate(mount: mount, source: source) unless source.nil?

      params[PublicContact::SourceToken::PARAM].presence
    end

    def source_token_query(token = params[PublicContact::SourceToken::PARAM])
      value = token.presence
      value ? { PublicContact::SourceToken::PARAM => value } : {}
    end
  end
end
