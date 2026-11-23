# frozen_string_literal: true

module RecordingStudioMessages
  module McpCopy
    module Outputs
      PRESS_CENTER = {
        list_conversations: "Conversation records on this press center, plus after_id when another page exists.",
        create_group: "The new conversation record.",
        read_thread: "Message records in that conversation.",
        send_message: "The new message record.",
        rename_group: "The renamed conversation record.",
        mark_read: "The conversation record after it is marked read.",
        unread_count: "unread_count for this press center."
      }.freeze

      MY_MESSAGES = {
        list_my_messages: "Conversation records in My Messages, plus after_id when another page exists.",
        read_my_messages: "Message records in that conversation.",
        send_my_message: "The new message record.",
        mark_my_message_read: "The conversation record after it is marked read.",
        count_unread_my_messages: "unread_count for My Messages."
      }.freeze

      module_function

      def for(action)
        key = action.to_sym
        return MY_MESSAGES.fetch(key) if MY_MESSAGES.key?(key)

        PRESS_CENTER.fetch(key)
      end
    end
  end
end
