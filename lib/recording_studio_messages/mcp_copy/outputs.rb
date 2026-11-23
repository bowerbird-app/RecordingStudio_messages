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

      module_function

      def for(action)
        PRESS_CENTER.fetch(action.to_sym)
      end
    end
  end
end
