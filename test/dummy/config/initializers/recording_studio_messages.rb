# frozen_string_literal: true

RecordingStudioMessages.configure do |config|
  config.read_receipts = true
  config.public_contact_recipient_resolver = lambda { |mount_recording:, actor:|
    next [] if mount_recording.blank? || actor.blank?

    [User.find_by(email: "admin@admin.com")].compact
  }
end

Rails.application.config.to_prepare do
  RecordingStudioMessages.register_composer_action(
    :attach_page,
    label: I18n.t("dummy.composer.attach_page"),
    icon: "document-text",
    partial: "dummy/page_picker",
    if: ->(_group, actor, mount) {
      mount&.recordable&.key.to_s == DummyCatalog::SUPPORT_KEY && actor.present?
    }
  )
  RecordingStudioMessages.register_message_embed("Page", partial: "dummy/page_embed")
end
