# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

module RenderedHeroiconAssertions
  def assert_rendered_heroicon(name, variant: "outline", selector: "svg")
    inner = FlatPack::Heroicons.fetch(variant, name)
    flunk "missing #{variant} heroicon #{name}" if inner.blank?

    matches = css_select(selector).select { |node| heroicon_markup_includes?(node.inner_html, inner) }
    assert_predicate matches, :any?, "expected rendered #{variant} #{name} inside #{selector}"
  end

  private

  def heroicon_markup_includes?(html, inner)
    normalize_heroicon_markup(html).include?(normalize_heroicon_markup(inner))
  end

  def normalize_heroicon_markup(markup)
    markup.to_s.gsub(%r{<([a-zA-Z0-9:-]+)([^>]*?)/>}, '<\1\2></\1>')
  end
end

ActiveSupport::TestCase.include RenderedHeroiconAssertions
