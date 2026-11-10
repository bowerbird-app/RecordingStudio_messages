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
      page = inbox_page_for(group_recordings)
      Array(group_recordings).filter_map do |group_recording|
        row = messages_inbox_row(group_recording, selected: selected, inbox: inbox, page: page)
        row if messages_inbox_row_complete?(row)
      end
    end

    def messages_unread_count(actor = current_messages_actor)
      RecordingStudioMessages.unread_count(actor: actor)
    end

    def messages_unread_badge_id
      "messages-unread-badge"
    end

    def messages_inbox_unread_dot_id(group_recording)
      "messages-unread-dot-#{group_recording.id}"
    end

    def messages_inbox_title_id(group_recording)
      "messages-inbox-title-#{group_recording.id}"
    end

    def messages_inbox_row(group_recording, selected: nil, inbox: nil, page: nil)
      latest = inbox_latest_message(group_recording, page)
      messages_inbox_row_arguments(group_recording, latest, selected: selected, inbox: inbox, page: page)
    end

    def messages_inbox_row_complete?(row)
      row[:chat_group_name].present? && row[:latest_preview].present?
    end

    def messages_inbox_row_arguments(group_recording, latest, selected: nil, inbox: nil, page: nil)
      unread = inbox_unread?(group_recording, page) == true
      active = selected_inbox_row?(group_recording, selected)
      {
        chat_group_name: messages_inbox_group_name(group_recording),
        latest_sender: messages_inbox_row_sender(group_recording, latest, inbox: inbox),
        latest_preview: latest&.recordable&.body,
        latest_at: latest && message_timestamp(latest),
        avatar_items: messages_inbox_avatar_items(group_recording, page: page, unread: unread),
        leading: messages_inbox_unread_dot(group_recording, unread: unread, page: page),
        active: active,
        data: { unread: unread },
        title_frame_id: messages_inbox_title_id(group_recording)
      }.merge(messages_inbox_row_link(group_recording, inbox: inbox, active: active))
    end

    def messages_unread_filter_button(unread_filter:)
      on = ActiveModel::Type::Boolean.new.cast(unread_filter) == true
      label = messages_unread_filter_label(on)
      {
        icon: "bell-alert",
        icon_only: true,
        round: true,
        size: :sm,
        style: :ghost,
        href: messages_unread_filter_href(filtered: !on),
        current: on,
        icon_variant: on ? :solid : :outline,
        title: label,
        aria: { label: label }
      }
    end

    def messages_unread_filter_href(filtered:)
      query = request.query_parameters.stringify_keys.except("after_id", "unread", "id")
      query = query.merge("unread" => 1) if filtered
      if respond_to?(:my_messages_path)
        my_messages_path(query)
      else
        recording_studio_messages.my_messages_path(query)
      end
    end

    def messages_unread_filter_label(unread_filter)
      key = unread_filter ? "inbox.filter_show_all" : "inbox.filter_unread_only"
      messages_t(key)
    end

    def messages_inbox_row_sender(group_recording, latest, inbox: nil)
      return messages_inbox_mount_name(group_recording) if inbox == :my_messages

      messages_inbox_latest_sender(latest)
    end

    def messages_inbox_row_link(group_recording, inbox: nil, active: false)
      href = messages_inbox_href(group_recording, inbox: inbox)
      return { href: href, turbo_frame: messages_desk_panel_id } unless inbox == :my_messages

      {
        href: href,
        link_arguments: {
          data: { turbo_stream: true },
          aria: { current: (active ? "page" : nil) }
        }
      }
    end

    def messages_inbox_unread_dot(group_recording, unread:, page: nil)
      render(
        "recording_studio_messages/message_groups/inbox_unread_dot",
        group_recording: group_recording,
        unread: unread,
        page: page
      )
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

    def messages_inbox_avatar_items(group_recording, page: nil, unread: false)
      inbox_granted_actors(group_recording, page).filter_map.with_index do |actor, index|
        item = { name: message_sender_name(actor) }
        item[:status] = :busy if unread && index.zero?
        item
      end
    end

    def inbox_page_for(group_recordings)
      return @inbox_page if defined?(@inbox_page) && @inbox_page

      RecordingStudioMessages::Services::InboxPage.new(group_recordings, actor: inbox_actor)
    end

    def inbox_actor
      return current_messages_actor if respond_to?(:current_messages_actor, true)
      return Current.actor if defined?(Current) && Current.respond_to?(:actor)

      nil
    end

    def inbox_unread?(group_recording, page)
      page&.unread?(group_recording)
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
