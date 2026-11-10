# frozen_string_literal: true

module DummyMessagesPanelHelper
  def messages_panel_right_header(group_recording, actor:, mount:)
    dummy_thread_status_badge(
      group_recording,
      actor: actor,
      mount: mount,
      html_id: "dummy-thread-status"
    )
  end

  def messages_panel_right_header_mobile(group_recording, actor:, mount:)
    dummy_thread_status_badge(
      group_recording,
      actor: actor,
      mount: mount,
      html_id: "dummy-thread-status-mobile"
    )
  end

  private

  def dummy_thread_status_badge(group_recording, actor:, mount:, html_id:)
    return unless dummy_support_thread_header?(group_recording, actor: actor, mount: mount)

    render FlatPack::Badge::Component.new(
      text: "Open",
      style: :info,
      size: :sm,
      id: html_id
    )
  end

  def dummy_support_thread_header?(group_recording, actor:, mount:)
    return if actor.blank?
    return unless mount&.recordable&.key.to_s == DummyCatalog::SUPPORT_KEY
    return unless RecordingStudioAccessible.authorized?(
      actor: actor,
      recording: group_recording,
      role: :view
    )

    true
  end
end
