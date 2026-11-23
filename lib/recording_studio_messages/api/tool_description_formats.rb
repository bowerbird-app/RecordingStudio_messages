# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module ToolDescriptions
      MISSING_MOUNT =
        "If this press center has no message center yet, this returns Message center not found."

      LIST_FORMAT =
        "List conversations on this press center's message center. Pass the press center id. " \
        "#{MISSING_MOUNT} Pass unread to keep unread conversations, after_id to continue from a " \
        "previous page, and limit for the page size (1 through 50). Returns records and after_id.".freeze

      CREATE_FORMAT =
        "Start a conversation on this press center's message center. Pass the press center id and title. " \
        "Pass body when you add people in recipients. #{MISSING_MOUNT} Returns the new conversation.".freeze

      READ_FORMAT =
        "Read the messages in one conversation on this press center. Pass the press center id. " \
        "Pass conversation_id from %<list>s. #{MISSING_MOUNT} A conversation from another message " \
        "center is not found. Returns records.".freeze

      SEND_FORMAT =
        "Send a message in a conversation on this press center. Pass the press center id. " \
        "Pass conversation_id from %<list>s. Pass body, or references to attach a recording. " \
        "This does not start a new conversation. Use %<start>s to start one. #{MISSING_MOUNT} " \
        "Returns the new message.".freeze

      RENAME_FORMAT =
        "Rename one conversation on this press center. Pass the press center id. " \
        "Pass conversation_id from %<list>s and title. Title is required and must be 120 characters " \
        "or fewer. #{MISSING_MOUNT} Returns the conversation.".freeze

      MARK_READ_FORMAT =
        "Mark one conversation read on this press center. Pass the press center id. " \
        "Pass conversation_id from %<list>s. #{MISSING_MOUNT} Returns the conversation.".freeze

      UNREAD_COUNT_FORMAT =
        "Count unread conversations on this press center's message center. Pass the press center id. " \
        "Uses the same conversations as %<list>s. #{MISSING_MOUNT} Returns unread_count.".freeze

      MESSAGE_MOUNT_FORMAT =
        "A MessageMount is one message center hanging off a parent recording. " \
        "The key names that inbox, for example support or inbox. Conversations sit under the mount. " \
        "MessageMount is show-only. #{MISSING_MOUNT}".freeze

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
