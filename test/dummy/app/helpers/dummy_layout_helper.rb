# frozen_string_literal: true

module DummyLayoutHelper
  def dummy_language_selector
    return unless respond_to?(:recording_studio_language_selector)

    recording_studio_language_selector(
      class: [
        "dummy-language-selector flex shrink-0 items-center gap-1.5",
        "[&_label]:sr-only [&_button]:sr-only [&_.flat-pack-input-wrapper]:mb-0",
        "[&_.flat-pack-select]:min-h-8 [&_.flat-pack-select]:min-w-28",
        "[&_.flat-pack-select]:py-1 [&_.flat-pack-select]:text-sm"
      ].join(" "),
      data: {
        turbo: false,
        controller: "dummy-language-selector",
        action: "change->dummy-language-selector#submit"
      }
    )
  end

  def dummy_document_attributes
    attributes = { "data-theme" => "rounded", lang: I18n.locale.to_s }
    attributes.merge!(recording_studio_locale_attributes) if respond_to?(:recording_studio_locale_attributes)
    return attributes unless respond_to?(:flat_pack_copy_data)

    attributes[:data] = (attributes[:data] || {}).merge(flat_pack_copy_data)
    attributes
  end

  def recording_studio_page_nav(title: nil, **options)
    content_for(:title, title) if title.present?
    flat_pack_page_nav(
      round: true,
      style: :default,
      back_href: options[:page_nav_back_url],
      back_icon: options[:page_nav_back_icon],
      back_tooltip: options[:page_nav_back_label],
      back_style: options[:page_nav_back_style],
      back_size: options[:page_nav_back_size],
      anchor_href: options[:page_nav_anchor_url],
      anchor_icon: options[:page_nav_anchor_icon],
      anchor_tooltip: options[:page_nav_anchor_label]
    )
    nil
  end

  def content_for(name, content = nil, options = {}, &block)
    rendered = super
    return rendered unless page_nav_right_read?(name, content, block)
    return rendered if @_dummy_language_in_page_nav

    selector = dummy_language_selector
    return rendered if selector.blank?

    @_dummy_language_in_page_nav = true
    safe_join([selector, rendered].compact)
  end

  private

  def page_nav_right_read?(name, content, block)
    name.to_sym == :page_nav_right && content.nil? && block.nil?
  end
end
