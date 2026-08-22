# frozen_string_literal: true

module RecordingStudioMessages
  module PanelHelper
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
      return "Someone" if actor.blank?

      named_actor(actor) || emailed_actor(actor) || actor.class.name.demodulize
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
