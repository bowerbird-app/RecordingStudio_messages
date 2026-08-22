# frozen_string_literal: true

# Core default layout leaves <html> bare and puts data-theme on body.
# Flatpack named themes read [data-theme] from the document element.
module HtmlRoundedTheme
  extend ActiveSupport::Concern

  included do
    after_action :copy_rounded_theme_onto_html
  end

  private

  def copy_rounded_theme_onto_html
    return unless response.media_type.to_s.include?("html")

    body = response.body.to_s
    return if body.match?(/<html\b[^>]*\bdata-theme="rounded"/)

    updated = body.sub(/<html\b([^>]*)>/) do
      %(<html data-theme="rounded"#{Regexp.last_match(1)}>)
    end
    response.body = updated if updated != body
  end
end
