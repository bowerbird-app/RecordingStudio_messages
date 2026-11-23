# frozen_string_literal: true

module RecordingStudioMessages
  module McpCopy
    module TypeDescriptions
      MESSAGE_MOUNT =
        "A MessageMount is one message center hanging off a parent recording. " \
        "The key names that inbox, for example support or inbox. " \
        "Conversations sit under the mount. Create the parent first, then the mount, " \
        "then start or reply in a conversation."

      MESSAGE_GROUP =
        "A MessageGroup is one conversation. People and agents join it as members. " \
        "Lines sit under the conversation. Use list_my_messages or a press-center list " \
        "to get a conversation id. Send only replies into an existing conversation. " \
        "Do not start a new one from My Messages."

      MESSAGE =
        "A Message is one line in a conversation. It can carry text and attached recordings. " \
        "Read a thread to get message ids. Send a new line on the conversation, not by creating " \
        "a Message record."

      BY_TYPE = {
        RecordingStudioMessages::MESSAGE_MOUNT_TYPE => MESSAGE_MOUNT,
        RecordingStudioMessages::MESSAGE_GROUP_TYPE => MESSAGE_GROUP,
        RecordingStudioMessages::MESSAGE_TYPE => MESSAGE
      }.freeze
    end
  end
end
