module ApplicationHelper
  include RecordingStudioMessages::CopyHelper
  include RecordingStudioMessages::PanelHelper
  include RecordingStudioMessages::InboxHelper
  include RecordingStudioAccessible::AvatarsHelper if defined?(RecordingStudioAccessible::AvatarsHelper)

  def dummy_language_selector
    return unless respond_to?(:recording_studio_language_selector)

    recording_studio_language_selector(
      class: "dummy-language-selector flex shrink-0 items-center gap-1.5 [&_label]:sr-only [&_button]:sr-only [&_.flat-pack-input-wrapper]:mb-0 [&_.flat-pack-select]:min-h-8 [&_.flat-pack-select]:min-w-28 [&_.flat-pack-select]:py-1 [&_.flat-pack-select]:text-sm",
      data: {
        turbo: false,
        controller: "dummy-language-selector",
        action: "change->dummy-language-selector#submit"
      }
    )
  end

  def dummy_document_attributes
    attributes = { "data-theme" => "rounded" }
    attributes.merge!(recording_studio_locale_attributes) if respond_to?(:recording_studio_locale_attributes)
    if respond_to?(:flat_pack_copy_data)
      attributes[:data] = (attributes[:data] || {}).merge(flat_pack_copy_data)
    end
    attributes
  end

  def dummy_page_nav_back_label
    I18n.exists?("flatpack.page_nav.back") ? I18n.t("flatpack.page_nav.back") : "Go back"
  end

  def dummy_page_nav_close_label
    I18n.exists?("flatpack.page_nav.close") ? I18n.t("flatpack.page_nav.close") : "Close"
  end
end

