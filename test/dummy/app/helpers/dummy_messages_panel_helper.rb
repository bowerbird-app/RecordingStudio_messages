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

  def dummy_attachable_pages(actor:, mount:, query: nil)
    parent = mount&.parent_recording
    return [] if actor.blank? || parent.blank?

    pages = RecordingStudioAccessible.recordings_for(
      actor: actor,
      parent_recording: parent,
      minimum_role: :view,
      recordable_type: "Page"
    ).includes(:recordable)
    needle = query.to_s.strip.downcase
    return pages if needle.blank?

    pages.select { |recording| dummy_page_title(recording).downcase.include?(needle) }
  end

  def dummy_page_href(recording)
    return if recording.blank?

    "/pages/#{recording.id}"
  end

  def message_reference_href(recording)
    dummy_page_href(recording)
  end

  def dummy_page_title(recording)
    recordable = recording&.recordable
    return recordable.title if recordable.respond_to?(:title) && recordable.title.present?

    I18n.t("dummy.composer.untitled_page")
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
