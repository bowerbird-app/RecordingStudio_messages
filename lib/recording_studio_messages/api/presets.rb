# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module Presets
      Support = Data.define(:actions, :names, :titles, :descriptions, :tags)
      PressCenter = Data.define(:actions, :names, :titles, :descriptions, :tags)

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
          create_group: "Open a request on this support message center. Pass title. Pass body when you add " \
                        "people in recipients. Needs edit access. Returns the new conversation.",
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
        tags: ["Support"]
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
          mark_read: "Mark read",
          unread_count: "Unread count"
        },
        descriptions: {
          list_conversations: "List conversations on this press center's message center. Pass unread, " \
                              "after_id, or limit. Needs view access. Returns records and after_id.",
          create_group: "Start a conversation on this press center's message center. Pass title. Pass body " \
                        "when recipients are present. Needs edit access. Returns the new conversation.",
          read_thread: "Read the messages in one conversation on this press center. Pass the conversation id. " \
                       "Needs view access. Returns records.",
          send_message: "Send a message in a conversation on this press center. Pass the conversation id and " \
                        "body, or references. Needs edit access. Returns the new message.",
          rename_group: "Rename one conversation on this press center. Pass the conversation id and title. " \
                        "Title is required and must be 120 characters or fewer. Needs edit access. " \
                        "Returns the conversation.",
          mark_read: "Mark one conversation read on this press center. Pass the conversation id. " \
                     "Needs view access. Returns the conversation.",
          unread_count: "Count unread conversations on this press center's message center. Uses the same " \
                        "conversations as the list, including access inherited on that message center. " \
                        "Needs view access. Returns unread_count."
        },
        tags: ["Press center"]
      )

      ALL = { support: SUPPORT, press_center: PRESS_CENTER }.freeze

      module_function

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
