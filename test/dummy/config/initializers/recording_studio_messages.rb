# frozen_string_literal: true

RecordingStudioMessages.configure do |config|
  config.read_receipts = true
  config.public_contact_recipient_resolver = lambda { |mount_recording:, actor:|
    next [] if mount_recording.blank? || actor.blank?

    [User.find_by(email: "admin@admin.com")].compact
  }
end

Rails.application.config.to_prepare do
  RecordingStudioMessages::Api.place(
    api: :public,
    at: :support,
    mount: -> { DummyCatalog.support_mount_recording },
    preset: :support
  )
  RecordingStudioMessages::Api.place(
    api: :public,
    at: :press_centers,
    mount: { recordable_type: "Mailbox", key: :inbox },
    preset: :press_center
  )
  RecordingStudioMessages::Api.place(
    api: :public,
    at: :my_messages,
    preset: :my_messages
  )

  RecordingStudioMessages.register_composer_action(
    :attach_page,
    label: "Attach a page",
    icon: "document-text",
    src: ->(_group, _actor, mount) {
      next if mount.blank?

      Rails.application.routes.url_helpers.dummy_page_picker_path(mount_id: mount.id)
    },
    if: ->(_group, actor, mount) {
      mount&.recordable&.key.to_s == DummyCatalog::SUPPORT_KEY && actor.present?
    }
  )
end
