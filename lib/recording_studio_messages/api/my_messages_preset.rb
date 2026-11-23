# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module Presets
      MyMessages = Data.define(:actions, :names, :titles, :descriptions, :tags, :tag_group, :exact_names)

      MY_MESSAGES = MyMessages.new(
        actions: %i[
          list_my_messages read_my_messages send_my_message mark_my_message_read count_unread_my_messages
        ],
        names: {
          list_my_messages: :list_my_messages,
          read_my_messages: :read_my_messages,
          send_my_message: :send_my_message,
          mark_my_message_read: :mark_my_message_read,
          count_unread_my_messages: :count_unread_my_messages
        },
        titles: {
          list_my_messages: "List my messages",
          read_my_messages: "Read my messages",
          send_my_message: "Send my message",
          mark_my_message_read: "Mark my message read",
          count_unread_my_messages: "Count unread messages"
        },
        descriptions: {
          list_my_messages: "List your conversations across message centers. Pass unread to keep unread " \
                            "conversations, after_id to continue, and limit for the page size. " \
                            "Needs view access. Returns records and after_id.",
          read_my_messages: "Read the messages in one of your conversations. Pass the conversation id from " \
                            "list_my_messages. Needs view access. Returns records.",
          send_my_message: "Send a message in one of your conversations. Pass the conversation id from " \
                           "list_my_messages. Pass body, or references to attach a recording. " \
                           "Needs edit access. Returns the new message.",
          mark_my_message_read: "Mark one of your conversations read. Pass the conversation id from " \
                                "list_my_messages. Needs view access. Returns the conversation. " \
                                "The response has no read cursor.",
          count_unread_my_messages: "Count your unread conversations across message centers. Uses the same " \
                                    "conversations as list_my_messages. Needs view access. Returns unread_count."
        },
        tags: ["My Messages"],
        tag_group: "My Messages",
        exact_names: true
      )
    end
  end
end
