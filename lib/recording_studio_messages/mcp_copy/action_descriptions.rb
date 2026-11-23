# frozen_string_literal: true

module RecordingStudioMessages
  module McpCopy
    module ActionDescriptions
      PRESS_CENTER = {
        list_conversations: {
          title: "List press center conversations",
          description:
            "Lists conversations on this press center's message center. " \
            "Pass the press center id. Create the press center first, then its inbox mount. " \
            "Pass unread to keep unread conversations, after_id to continue from a previous page, " \
            "and limit for the page size (1 through 50). Returns records and after_id."
        },
        create_group: {
          title: "Start press center conversation",
          description:
            "Starts a conversation on this press center's message center. " \
            "Pass the press center id. Pass title, or pass body when recipients are present. " \
            "Each recipient is a type and id from that message center's contact list. " \
            "Returns the new conversation."
        },
        read_thread: {
          title: "Read press center messages",
          description:
            "Reads the messages in one conversation on this press center. " \
            "Pass the press center id and conversation_id from a list or start result on this center. " \
            "A conversation from another message center is not found. Returns records."
        },
        send_message: {
          title: "Send press center message",
          description:
            "Sends a line in an existing conversation on this press center. " \
            "Pass the press center id and conversation_id. Pass body, or references to attach a recording. " \
            "This does not start a new conversation. Returns the new message."
        },
        rename_group: {
          title: "Rename press center conversation",
          description:
            "Renames one conversation on this press center. " \
            "Pass the press center id, conversation_id, and title. " \
            "Title is required and must be 120 characters or fewer. Returns the conversation."
        },
        mark_read: {
          title: "Mark press center conversation read",
          description:
            "Marks one conversation read on this press center for the current actor. " \
            "Pass the press center id and conversation_id. Returns the conversation."
        },
        unread_count: {
          title: "Count unread press center conversations",
          description:
            "Counts unread conversations on this press center's message center for the current actor. " \
            "Pass the press center id. Uses the same conversations as the list. Returns unread_count."
        }
      }.freeze

      MY_MESSAGES = {
        list_conversations: {
          title: "List my messages",
          description:
            "Lists conversations the current actor was added to, across every message center. " \
            "This is the My Messages inbox, not one press center. " \
            "Pass unread to keep unread conversations, after_id to continue, and limit for the page size " \
            "(1 through 50). Returns records and after_id."
        },
        read_thread: {
          title: "Read my messages",
          description:
            "Reads the messages in one conversation from My Messages. " \
            "Pass the conversation id from list_my_messages. " \
            "The conversation must already exist and the actor must be a member. Returns records."
        },
        send_message: {
          title: "Send my message",
          description:
            "Sends a reply in an existing My Messages conversation. " \
            "Pass the conversation id from list_my_messages. Pass body, or references to attach a recording. " \
            "This never starts a new conversation. Returns the new message."
        },
        mark_read: {
          title: "Mark my message read",
          description:
            "Marks one My Messages conversation read for the current actor. " \
            "Pass the conversation id from list_my_messages. Returns the conversation."
        },
        unread_count: {
          title: "Count unread my messages",
          description:
            "Counts unread conversations in My Messages for the current actor. " \
            "Uses the same conversations as list_my_messages. Returns unread_count."
        }
      }.freeze

      module_function

      def copy_for(kind, action)
        table = kind == :my_messages ? MY_MESSAGES : PRESS_CENTER
        table.fetch(action.to_sym)
      end
    end
  end
end
