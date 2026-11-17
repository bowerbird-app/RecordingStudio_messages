# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module ToolDescriptions
      module_function

      def text(body)
        body.tr("\n", " ").squeeze(" ").strip
      end

      MESSAGE_CENTER_ID = text(<<~TEXT)
        The message center id. This is the recording id of the keyed messages mount, such as support or inbox, hung under a recordable. These tools do not list message centers. Find that mount recording under its parent recordable, and show it to read the key.
      TEXT

      CONVERSATION_ID = text(<<~TEXT)
        The conversation id. Take it from a messages_list_conversations record, or from the id messages_create_group returns.
      TEXT

      LIST_CONVERSATIONS = text(<<~TEXT)
        List the conversations on one message center.
        Use this to get conversation ids before you read a thread, send, rename, or mark read.
        Use messages_unread_count when you only need how many conversations are unread for this client.
        A message center is a keyed messages mount, such as support or inbox, hung under a recordable.
        The message center id is that mount's recording id.
        These tools do not list message centers.
        Find the mount recording under its parent recordable, and show that recording to read the key.
        Pass that recording id as id.
        Pass unread as true to keep conversations with unread lines.
        Pass after_id to continue after a conversation id from an earlier page.
        An after_id from another message center is rejected.
        Pass limit as the page size.
        It defaults to 50, the HTML inbox page size, and is clamped from 1 through 50.
        Needs view access to the message center.
        Returns records, an array of conversations.
        Each conversation has id, type MessageGroup, root_id, parent_id, created_at, and title.
        parent_id is the message center id.
        Also returns after_id, the last conversation id, when the page has at least 50 conversations.
        after_id is null on a shorter page.
        That includes a limit below 50 when more conversations remain.
        Continue that page by passing the last records id as after_id.
      TEXT

      CREATE_GROUP = text(<<~TEXT)
        Start a conversation on a message center.
        Use messages_send_message to add a line to a conversation that already exists.
        A message center is a keyed messages mount, such as support or inbox, hung under a recordable.
        The message center id is that mount's recording id.
        These tools do not list message centers.
        Find the mount recording under its parent recordable, and show that recording to read the key.
        Pass that recording id as id.
        Pass title as the conversation name, at most 120 characters.
        Title is required when you omit recipients.
        Pass body as the first message.
        Body is required when recipients are present.
        Pass recipients to add people.
        Each item is an object with type and id, or a type and id joined by a colon.
        Each person must already be on that message center's contact allowlist.
        This tool does not look people up.
        When you pass recipients and omit title, the name is built from those people.
        Omit recipients to create a named conversation with no other people.
        Needs edit access to the message center.
        On a members message center, this create writes an admin grant for the client.
        The client must already be an admin, including when you pass recipients.
        Returns the new conversation.
        It has id, type MessageGroup, root_id, parent_id, created_at, and title.
        parent_id is the message center id.
        The first message is absent from this response.
        Read it with messages_read_thread.
      TEXT

      UNREAD_COUNT = text(<<~TEXT)
        Count unread conversations for this client.
        Use messages_list_conversations with unread true when you want the conversations on one message center.
        This tool takes no id.
        It counts conversations the actor has a direct grant on that are unread.
        The count includes only conversations this client's access can reach.
        A conversation reached only by inherited access on a root or message center is left out.
        Needs view access on the access recording.
        Returns unread_count, an integer.
      TEXT

      SEND_MESSAGE = text(<<~TEXT)
        Send a message in a conversation that already exists.
        Use messages_create_group to start a conversation.
        Pass the conversation id from messages_list_conversations as id.
        Pass the text in body.
        Body is required unless references is present.
        Pass references to attach recordings.
        Each item is a recording id, or an object with recording_id.
        The actor must be able to view that recording.
        It must sit under the same parent recordable as the message center.
        Needs edit access to the conversation.
        Send with this tool.
        Generic message create is refused.
        Returns the new message.
        It has id, type Message, root_id, parent_id, created_at, and body.
        parent_id is the conversation id.
        Attached recordings are absent from this response.
      TEXT

      READ_THREAD = text(<<~TEXT)
        Read the messages in one conversation.
        Use messages_list_conversations to get the conversation id.
        Pass that id as id.
        There are no other inputs.
        Needs view access to the conversation.
        Returns records, an array of messages.
        Each message has id, type Message, root_id, parent_id, created_at, and body.
        parent_id is the conversation id.
        Attached recordings are absent from this response.
        Use messages_send_message to add a line.
      TEXT

      RENAME_GROUP = text(<<~TEXT)
        Rename one conversation.
        Use messages_create_group when you need a new conversation.
        Pass the conversation id from messages_list_conversations as id.
        Pass title as the new name.
        Title is required, and it must be 120 characters or fewer.
        A blank title is rejected.
        Needs edit access to the conversation.
        Returns the conversation.
        It has id, type MessageGroup, root_id, parent_id, created_at, and title.
        parent_id is the message center id.
      TEXT

      MARK_READ = text(<<~TEXT)
        Mark one conversation read for this actor.
        Use messages_unread_count when you want the number.
        Use messages_list_conversations with unread true to list them on one message center.
        Pass the conversation id from messages_list_conversations as id.
        There are no other inputs.
        Needs view access to the conversation.
        Returns the conversation.
        It has id, type MessageGroup, root_id, parent_id, created_at, and title.
        The response has no read cursor.
      TEXT
    end
  end
end
