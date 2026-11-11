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

    def messages_group_rename_url(group_recording, inbox: nil)
      path = if respond_to?(:rename_message_group_path)
               rename_message_group_path(group_recording)
             else
               recording_studio_messages.rename_message_group_path(group_recording)
             end
      return path unless inbox == :my_messages

      "#{path}?inbox=my_messages"
    end

    def messages_can_rename_group?(group_recording, actor: nil)
      actor ||= current_messages_actor if respond_to?(:current_messages_actor, true)
      return false if group_recording.blank? || actor.blank?

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: group_recording,
        role: :edit
      )
    end

    def messages_panel_header_title(group_recording, actor:, inbox: nil)
      title = group_recording.recordable.title
      return messages_truncated_title(title) unless messages_can_rename_group?(group_recording, actor: actor)

      render FlatPack::InlineEdit::Component.new(
        **inline_edit_title_arguments(group_recording, title, inbox: inbox)
      )
    end

    def messages_truncated_title(text)
      text = text.to_s
      tag.span(text, class: "block min-w-0 truncate", title: text)
    end

    def inline_edit_title_arguments(group_recording, title, inbox: nil)
      {
        name: "message_group[title]", value: title, tag: :span,
        update_url: messages_group_rename_url(group_recording, inbox: inbox),
        method: :patch, maxlength: RecordingStudioMessages::MessageGroup::TITLE_MAX,
        required: true, save_on_blur: true,
        label: Copy.t("panel.title_label"),
        placeholder: Copy.t("panel.title_placeholder"),
        class: "min-w-0 max-w-full truncate",
        title: title
      }
    end

    def messages_panel_return_to
      request.fullpath
    end

    def messages_panel_right_header(group_recording, actor:, mount:)
      return unless group_recording && actor && mount

      nil
    end

    def messages_panel_right_header_mobile(group_recording, actor:, mount:)
      return unless group_recording && actor && mount

      nil
    end

    def messages_panel_after(group_recording, actor:, mount:)
      return unless group_recording && actor && mount

      nil
    end

    def messages_panel_list_id(group_recording)
      "conversation-#{group_recording.id}-messages"
    end

    def messages_panel_composer_id(group_recording)
      "conversation-#{group_recording.id}-composer"
    end

    def messages_composer_actions(group_recording, actor:, mount:)
      RecordingStudioMessages.composer_actions_for(group_recording, actor, mount)
    end

    def messages_composer_action_modal_id(action)
      "messages-composer-action-#{action.key}"
    end

    def messages_composer_action_frame_id(action)
      "#{messages_composer_action_modal_id(action)}-frame"
    end

    def linked_message_body(text)
      RecordingStudioMessages.auto_link(text).html_safe
    end

    def message_references_visible(message_recordings, actor:)
      RecordingStudioMessages.visible_message_references(message_recordings, actor: actor)
    end

    def message_reference_title(recording)
      recordable = recording&.recordable
      return Copy.t("composer.linked_item") if recordable.blank?
      return recordable.title if recordable.respond_to?(:title) && recordable.title.present?
      return recordable.name if recordable.respond_to?(:name) && recordable.name.present?

      Copy.t("composer.linked_item")
    end

    def message_reference_href(_recording)
      nil
    end

    def message_embed_partial_for(recording)
      RecordingStudioMessages.message_embed_partial(recording.recordable_type)
    end

    def message_sender_for(message_recording)
      created_event_for(message_recording)&.actor
    end

    def created_event_for(message_recording)
      association = message_recording.association(:events)
      unless association.loaded?
        return association.scope.where(action: "created").order(:occurred_at, :created_at).first
      end

      created = association.target.select { |event| event.action == "created" }
      created.min_by { |event| [event.occurred_at || event.created_at, event.created_at] }
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

    def message_clock(message_recording)
      format_message_clock(message_timestamp(message_recording))
    end

    def format_message_clock(time)
      return time.to_s unless time.respond_to?(:strftime)

      time.strftime("%l:%M %p").strip
    end

    def message_day_break?(previous, current)
      previous.blank? || message_timestamp(previous).to_date != message_timestamp(current).to_date
    end

    def message_time_break?(previous, current)
      return false if previous.blank? || message_day_break?(previous, current)

      previous_at = message_timestamp(previous)
      current_at = message_timestamp(current)
      return false if previous_at.blank? || current_at.blank?

      (current_at - previous_at) > RecordingStudioMessages.configuration.time_break_after
    end

    def message_seen_by(group_recording, viewer:, latest_message: nil)
      RecordingStudioMessages.seen_by(
        group_recording: group_recording,
        viewer: viewer,
        latest_message: latest_message
      )
    end

    def message_seen_label(actors)
      names = Array(actors).map { |actor| message_sender_name(actor) }.join(", ")
      Copy.t("panel.seen_by", names: names)
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
  end
end
