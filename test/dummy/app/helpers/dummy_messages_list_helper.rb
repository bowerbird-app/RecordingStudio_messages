# frozen_string_literal: true

module DummyMessagesListHelper
  def messages_list_toolbar(mount:, actor:)
    return if actor.blank?
    return unless mount&.recordable&.key.to_s == DummyCatalog::SUPPORT_KEY
    return unless RecordingStudioAccessible.authorized?(
      actor: actor,
      recording: mount.parent_recording,
      role: :view
    )

    render FlatPack::Button::Component.new(
      text: "New",
      style: :secondary,
      size: :sm,
      href: main_app.staff_desk_path,
      id: "dummy-list-toolbar"
    )
  end
end
