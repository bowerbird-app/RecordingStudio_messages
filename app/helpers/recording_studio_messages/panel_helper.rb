# frozen_string_literal: true

module RecordingStudioMessages
  module PanelHelper
    include CopyHelper

    def messages_desk_panel_id
      "messages-desk-panel"
    end

    def messages_panel_form_url(group_recording)
      if respond_to?(:message_group_messages_path)
        message_group_messages_path(group_recording)
      else
        recording_studio_messages.message_group_messages_path(group_recording)
      end
    end

    def messages_panel_return_to
      request.fullpath
    end

    # HTML for Flatpack Chat::Panel's `right_header` slot. `group_recording` is
    # the open conversation. `current_messages_actor` is available while the
    # panel renders.
    #
    # A host overrides this the same way Support overrides `messages_inbox_href`:
    # define a helper with the same name. Return nil or blank to omit the slot.
    # Return html-safe markup.
    #
    # On Flatpack 0.1.329 a lone `right_header` is `flex` at every width. It is
    # `hidden sm:flex` (shown at 640px and up) only when `right_header_mobile`
    # is also set. Both slots stay in the DOM when both are present, so their
    # ids, Stimulus targets, and `aria-controls` targets must differ.
    def messages_panel_right_header(group_recording)
      panel_hook_default(group_recording)
    end

    # HTML for Flatpack Chat::Panel's `right_header_mobile` slot (shown below
    # `sm`). Same argument and override rules as `messages_panel_right_header`.
    # Pass only this hook and the compact actions show below `sm`.
    def messages_panel_right_header_mobile(group_recording)
      panel_hook_default(group_recording)
    end

    # HTML rendered once after the chat panel, inside the `messages-desk-panel`
    # turbo frame (`h-full`). That frame sits in Chat::Layout's `overflow-hidden`
    # panel column, so in-flow markup here is clipped. A Flatpack modal is
    # `fixed` (backdrop `inset-0`), so it is not clipped and does not add height.
    # Same argument and override rules as `messages_panel_right_header`.
    # Nil or blank renders nothing.
    def messages_panel_after(group_recording)
      panel_hook_default(group_recording)
    end

    def messages_panel_list_id(group_recording)
      "conversation-#{group_recording.id}-messages"
    end

    def messages_panel_composer_id(group_recording)
      "conversation-#{group_recording.id}-composer"
    end

    def message_sender_for(message_recording)
      created = message_recording.events.where(action: "created").order(:occurred_at, :created_at).first
      created&.actor
    end

    def message_sender_name(actor)
      return Copy.t("panel.someone") if actor.blank?

      named_actor(actor) || profile_actor_name(actor) || emailed_actor(actor) || actor.class.name.demodulize
    end

    def profile_actor_name(actor)
      return unless defined?(RecordingStudioUser)
      return unless RecordingStudioUser.respond_to?(:profile_for)

      profile = RecordingStudioUser.profile_for(actor)
      return if profile.blank?

      [profile.first_name, profile.last_name].compact_blank.join(" ").presence
    end

    def named_actor(actor)
      actor.name if actor.respond_to?(:name) && actor.name.present?
    end

    def emailed_actor(actor)
      return unless actor.respond_to?(:email) && actor.email.present?

      actor.email.to_s.split("@").first.to_s.titleize
    end

    def outgoing_message?(message_recording, actor:)
      sender = message_sender_for(message_recording)
      return false if sender.blank? || actor.blank?

      sender.instance_of?(actor.class) && sender.id.to_s == actor.id.to_s
    end

    def message_timestamp(message_recording)
      message_recording.created_at
    end

    def message_day_label(date)
      Copy.l(date, format: "%-d %b %Y")
    end

    def message_attachments_for(message_recording)
      return [] unless message_recording.respond_to?(:attachments)

      records = message_recording.attachments
      return records.to_a if records.respond_to?(:to_a)

      Array(records)
    rescue StandardError
      []
    end

    def message_attachment_href(attachment_recording)
      return unless attachment_recording

      if respond_to?(:recording_studio_attachable) &&
         recording_studio_attachable.respond_to?(:attachment_file_path)
        return recording_studio_attachable.attachment_file_path(attachment_recording)
      end

      blob = attachment_recording.recordable&.file
      return unless blob.respond_to?(:signed_id)

      rails_blob_path(blob, only_path: true)
    rescue StandardError
      nil
    end

    def message_attachment_thumbnail(attachment_recording)
      attachment = attachment_recording&.recordable
      return unless attachment.respond_to?(:attachment_kind)
      return unless attachment.attachment_kind.to_s == "image"

      message_attachment_href(attachment_recording)
    end

    private

    def panel_hook_default(_group_recording)
      nil
    end
  end
end
