# frozen_string_literal: true

module HtmlRoundedTheme
  extend ActiveSupport::Concern

  included do
    after_action :copy_document_attributes_onto_html
  end

  private

  def copy_document_attributes_onto_html
    return unless response.media_type.to_s.include?("html")

    body = response.body.to_s
    updated = body.sub(/<html\b([^>]*)>/) do
      attrs = Regexp.last_match(1).to_s
      attrs = %( data-theme="rounded"#{attrs}) unless attrs.match?(/\bdata-theme=/)
      attrs = %( lang="#{ERB::Util.html_escape(I18n.locale)}"#{attrs}) unless attrs.match?(/\blang=/)
      "<html#{attrs}>"
    end
    response.body = updated if updated != body
  end
end
