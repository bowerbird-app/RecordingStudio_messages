# frozen_string_literal: true

module RecordingStudioMessages
  module InboxHelper
    def messages_inbox_title(mount_recording)
      parent = mount_recording&.parent_recording&.recordable
      return parent.name if parent.respond_to?(:name) && parent.name.present?
      return parent.title if parent.respond_to?(:title) && parent.title.present?

      "Conversations"
    end

    def messages_inbox_rows(group_recordings)
      Array(group_recordings).filter_map do |group_recording|
        row = messages_inbox_row(group_recording)
        row if messages_inbox_row_complete?(row)
      end
    end

    def messages_inbox_row(group_recording)
      latest = RecordingStudioMessages.message_recordings(group_recording).last
      messages_inbox_row_arguments(group_recording, latest)
    end

    def messages_inbox_row_complete?(row)
      row[:chat_group_name].present? && row[:latest_preview].present?
    end

    def messages_inbox_row_arguments(group_recording, latest)
      {
        chat_group_name: messages_inbox_group_name(group_recording),
        latest_sender: messages_inbox_latest_sender(latest),
        latest_preview: latest&.recordable&.body,
        latest_at: latest && message_timestamp(latest),
        unread_count: 0,
        avatar_items: messages_inbox_avatar_items(group_recording),
        href: messages_inbox_href(group_recording),
        active: false
      }
    end

    def messages_inbox_group_name(group_recording)
      group_recording.recordable&.title.to_s.strip.presence
    end

    def messages_inbox_latest_sender(latest)
      sender = latest && message_sender_for(latest)
      sender && message_sender_name(sender)
    end

    def messages_inbox_href(group_recording)
      if respond_to?(:message_group_path)
        message_group_path(group_recording)
      else
        recording_studio_messages.message_group_path(group_recording)
      end
    end

    def messages_inbox_avatar_items(group_recording)
      RecordingStudioMessages.granted_actors(group_recording).filter_map do |actor|
        { name: message_sender_name(actor) }
      end
    end
  end
end
