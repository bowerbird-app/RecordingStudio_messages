# frozen_string_literal: true

module RecordingStudioMessages
  module InboxHelper
    include CopyHelper

    def messages_inbox_title(mount_recording)
      parent = mount_recording&.parent_recording&.recordable
      return parent.name if parent.respond_to?(:name) && parent.name.present?
      return parent.title if parent.respond_to?(:title) && parent.title.present?

      Copy.t("inbox.title")
    end

    def messages_inbox_rows(group_recordings, selected: nil, inbox: nil)
      page = my_messages_inbox_page(group_recordings, inbox)
      Array(group_recordings).filter_map do |group_recording|
        row = messages_inbox_row(group_recording, selected: selected, inbox: inbox, page: page)
        row if messages_inbox_row_complete?(row)
      end
    end

    def messages_inbox_row(group_recording, selected: nil, inbox: nil, page: nil)
      latest = inbox_latest_message(group_recording, page)
      messages_inbox_row_arguments(group_recording, latest, selected: selected, inbox: inbox, page: page)
    end

    def messages_inbox_row_complete?(row)
      row[:chat_group_name].present? && row[:latest_preview].present?
    end

    def messages_inbox_row_arguments(group_recording, latest, selected: nil, inbox: nil, page: nil)
      {
        chat_group_name: messages_inbox_group_name(group_recording),
        latest_sender: messages_inbox_row_sender(group_recording, latest, inbox: inbox),
        latest_preview: latest&.recordable&.body,
        latest_at: latest && message_timestamp(latest),
        unread_count: 0,
        avatar_items: messages_inbox_avatar_items(group_recording, page: page),
        active: selected_inbox_row?(group_recording, selected)
      }.merge(messages_inbox_row_link(group_recording, inbox: inbox))
    end

    def messages_inbox_row_sender(group_recording, latest, inbox: nil)
      return messages_inbox_mount_name(group_recording) if inbox == :my_messages

      messages_inbox_latest_sender(latest)
    end

    def messages_inbox_row_link(group_recording, inbox: nil)
      {
        href: messages_inbox_href(group_recording, inbox: inbox),
        turbo_frame: messages_desk_panel_id
      }
    end

    def selected_inbox_row?(group_recording, selected)
      selected.present? && selected.id.to_s == group_recording.id.to_s
    end

    def messages_inbox_group_name(group_recording)
      group_recording.recordable&.title.to_s.strip.presence
    end

    def messages_inbox_latest_sender(latest)
      sender = latest && message_sender_for(latest)
      sender && message_sender_name(sender)
    end

    def messages_inbox_href(group_recording, inbox: nil)
      return my_messages_href(group_recording) if inbox == :my_messages

      if respond_to?(:message_group_path)
        message_group_path(group_recording)
      else
        recording_studio_messages.message_group_path(group_recording)
      end
    end

    def my_messages_href(group_recording)
      if respond_to?(:my_message_path)
        my_message_path(group_recording)
      else
        recording_studio_messages.my_message_path(group_recording)
      end
    end

    def messages_inbox_mount_name(group_recording)
      messages_inbox_title(group_recording&.parent_recording)
    end

    def messages_inbox_avatar_items(group_recording, page: nil)
      inbox_granted_actors(group_recording, page).filter_map do |actor|
        { name: message_sender_name(actor) }
      end
    end

    def my_messages_inbox_page(group_recordings, inbox)
      return unless inbox == :my_messages
      return @inbox_page if defined?(@inbox_page) && @inbox_page

      RecordingStudioMessages::Services::InboxPage.new(group_recordings)
    end

    def inbox_latest_message(group_recording, page)
      return page.latest_for(group_recording) if page

      RecordingStudioMessages.message_recordings(group_recording).last
    end

    def inbox_granted_actors(group_recording, page)
      return page.actors_for(group_recording) if page

      RecordingStudioMessages.granted_actors(group_recording)
    end
  end
end
