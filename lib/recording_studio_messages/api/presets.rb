# frozen_string_literal: true

require_relative "my_messages_preset"
require_relative "tool_descriptions"

module RecordingStudioMessages
  module Api
    module Presets
      Support = Data.define(:actions, :names, :titles, :descriptions, :tags, :tag_group)
      PressCenter = Data.define(:actions, :names, :titles, :descriptions, :tags, :tag_group)

      MESSAGE_CENTER = "Message Center"
      PRESS_CENTER_MESSAGES = "Press Center Messages"
      PRESS_CENTER_GROUP = "Press Center"

      SUPPORT = Support.new(
        actions: %i[create_group list_conversations read_thread send_message mark_read unread_count],
        names: {
          create_group: :open_request,
          list_conversations: :list_requests,
          read_thread: :read_messages,
          send_message: :reply,
          mark_read: :mark_read,
          unread_count: :unread_count
        },
        titles: {
          create_group: "Open request",
          list_conversations: "List my requests",
          read_thread: "Read messages",
          send_message: "Reply",
          mark_read: "Mark read",
          unread_count: "Unread count"
        },
        descriptions: {
          create_group: "Open a request on this support message center. Pass title. Pass recipients and body " \
                        "together when you add people. A body with no recipients is rejected. " \
                        "Needs edit access. Returns the new conversation.",
          list_conversations: "List your requests on this support message center. Pass unread to keep unread " \
                              "requests, after_id to continue, and limit for the page size. Needs view access. " \
                              "Returns records and after_id.",
          read_thread: "Read the messages in one request on this support message center. Pass the request id. " \
                       "Needs view access. Returns records.",
          send_message: "Reply in a request on this support message center. Pass the request id. Pass body, " \
                        "or references to attach a recording. Needs edit access. Returns the new message.",
          mark_read: "Mark one request read on this support message center. Pass the request id. " \
                     "Needs view access. Returns the request. The response has no read cursor.",
          unread_count: "Count unread requests on this support message center for this actor. Uses the same " \
                        "conversations as the request list, including access inherited on that message center. " \
                        "Needs view access. Returns unread_count."
        },
        tags: ["Support"],
        tag_group: nil
      )

      PRESS_CENTER = PressCenter.new(
        actions: %i[
          list_conversations create_group read_thread send_message rename_group mark_read unread_count
        ],
        names: {
          list_conversations: :list_conversations,
          create_group: :start_conversation,
          read_thread: :read_messages,
          send_message: :send_message,
          rename_group: :rename_conversation,
          mark_read: :mark_read,
          unread_count: :unread_count
        },
        titles: {
          list_conversations: "List conversations",
          create_group: "Start conversation",
          read_thread: "Read messages",
          send_message: "Send message",
          rename_group: "Rename conversation",
          mark_read: "Mark conversation read",
          unread_count: "Count unread conversations"
        },
        descriptions: {
          list_conversations: ToolDescriptions::LIST,
          create_group: ToolDescriptions::CREATE,
          read_thread: ToolDescriptions::READ,
          send_message: ToolDescriptions::SEND,
          rename_group: ToolDescriptions::RENAME,
          mark_read: ToolDescriptions::MARK_READ,
          unread_count: ToolDescriptions::UNREAD_COUNT
        },
        tags: [PRESS_CENTER_MESSAGES],
        tag_group: PRESS_CENTER_GROUP
      )

      ALL = { support: SUPPORT, press_center: PRESS_CENTER, my_messages: MY_MESSAGES }.freeze

      module_function

      def my_messages?(preset)
        preset.equal?(MY_MESSAGES)
      end

      def fetch(name)
        key = name&.to_sym
        preset = ALL[key]
        return preset if preset

        known = ALL.keys.join(", ")
        raise ::RecordingStudioApi::ConfigurationError, "Unknown messages API preset: #{name}. Use #{known}."
      end
    end
  end
end
