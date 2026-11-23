# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module ToolDescriptions
      LIST_FORMAT =
        "List conversations on this press center's message center. %<id>sPass unread, " \
        "after_id, or limit. %<missing_mount>s%<view_access>sReturns records and after_id."

      CREATE_FORMAT =
        "Start a conversation on this press center's message center. %<start_args>sPass body " \
        "%<body_when>s. %<missing_mount>s%<edit_access>sReturns the new conversation."

      READ_FORMAT =
        "Read the messages in one conversation on this press center. %<id>sPass %<conversation>s. " \
        "%<missing_mount>s%<view_access>sReturns records."

      SEND_FORMAT =
        "Send a message in a conversation on this press center. %<id>sPass %<send_pass>s. " \
        "%<no_start>s%<missing_mount>s%<edit_access>sReturns the new message."

      RENAME_FORMAT =
        "Rename one conversation on this press center. %<id>sPass %<rename_pass>s. " \
        "Title is required and must be 120 characters or fewer. " \
        "%<missing_mount>s%<edit_access>sReturns the conversation."

      MARK_READ_FORMAT =
        "Mark one conversation read on this press center. %<id>sPass %<conversation>s. " \
        "%<missing_mount>s%<view_access>sReturns the conversation."

      UNREAD_COUNT_FORMAT =
        "Count unread conversations on this press center's message center. %<id>sUses the same " \
        "conversations as %<list>s%<inherited>s. %<missing_mount>s%<view_access>sReturns unread_count."

      MESSAGE_MOUNT_FORMAT =
        "A MessageMount is one message center hanging off a parent recording. " \
        "The key names that inbox, for example support or inbox. Conversations sit under the mount. " \
        "MessageMount is show-only."

      MESSAGE_GROUP_FORMAT =
        "A MessageGroup is one conversation. People and agents join it as members. " \
        "Lines sit under the conversation. Use %<list>s to get a conversation id. " \
        "Send a reply into an existing conversation, or start one with %<start>s."

      MESSAGE_FORMAT =
        "A Message is one line in a conversation. It can carry text and attached recordings. " \
        "Read a thread with %<read>s to get message ids. Send a new line on the conversation, " \
        "not by creating a Message record."
    end
  end
end
