# frozen_string_literal: true

module DummyLayoutHelper
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
end
