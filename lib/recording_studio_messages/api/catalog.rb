# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module Catalog
      LIST_FIELDS = {
        unread: {
          type: :boolean, required: false,
          description: "When true, only conversations with unread lines for this actor."
        },
        after_id: {
          type: :string, required: false, allow_blank: true,
          description: "Conversation id to page after. Use a records id from an earlier page on this " \
                       "message center. An id from another message center is rejected."
        },
        limit: {
          type: :integer, required: false,
          description: "Page size. Defaults to 50, the HTML inbox page size, and is clamped from 1 through 50."
        }
      }.freeze

      CREATE_FIELDS = {
        title: {
          type: :string, required: false, allow_blank: true,
          description: "Conversation name, at most 120 characters. Required when recipients are omitted."
        },
        body: {
          type: :string, required: false, allow_blank: true,
          description: "First message text. Required when recipients are present."
        },
        recipients: {
          type: :array, required: false,
          description: "People to add. Each item is an object with type and id, or a type and id " \
                       "joined by a colon, from that message center's contact allowlist."
        }
      }.freeze

      SEND_FIELDS = {
        body: {
          type: :string, required: false, allow_blank: true,
          description: "Message text. Required unless references is present."
        },
        references: {
          type: :array, required: false,
          description: "Recordings to attach. Each item is a recording id, or an object with recording_id. " \
                       "The actor must be able to view it, under the message center's parent recordable."
        }
      }.freeze

      RENAME_FIELDS = {
        title: {
          type: :string, required: true, allow_blank: false,
          description: "New conversation name. Required, at most 120 characters."
        }
      }.freeze

      CONVERSATION_FIELD = {
        type: :string, required: true, allow_blank: false,
        description: "Conversation id from a list or create response on this message center."
      }.freeze

      ACTIONS = {
        list_conversations: {
          handler: :ListConversations, verb: :get, role: :view, scope: :mount,
          singleton_path: "conversations", parent_path: "conversations",
          title: "List conversations",
          description: "List the conversations on this message center. Returns records and after_id.",
          fields: LIST_FIELDS
        },
        create_group: {
          handler: :CreateGroup, verb: :post, role: :edit, scope: :mount,
          singleton_path: "conversations", parent_path: "conversations",
          title: "Start conversation",
          description: "Start a conversation on this message center. Returns the new conversation.",
          fields: CREATE_FIELDS
        },
        read_thread: {
          handler: :ReadThread, verb: :get, role: :view, scope: :conversation,
          singleton_path: "conversations/:id/messages", parent_path: "messages",
          title: "Read messages",
          description: "Read the messages in one conversation. Returns records.",
          fields: {}
        },
        send_message: {
          handler: :SendMessage, verb: :post, role: :edit, scope: :conversation,
          singleton_path: "conversations/:id/send_message", parent_path: "send_message",
          title: "Send message",
          description: "Send a message in a conversation on this message center. Returns the new message.",
          fields: SEND_FIELDS
        },
        rename_group: {
          handler: :RenameGroup, verb: :post, role: :edit, scope: :conversation,
          singleton_path: "conversations/:id/rename_group", parent_path: "rename_group",
          title: "Rename conversation",
          description: "Rename one conversation on this message center. Returns the conversation.",
          fields: RENAME_FIELDS
        },
        mark_read: {
          handler: :MarkRead, verb: :post, role: :view, scope: :conversation,
          singleton_path: "conversations/:id/mark_read", parent_path: "mark_read",
          title: "Mark conversation read",
          description: "Mark one conversation read for this actor. Returns the conversation.",
          fields: {}
        },
        unread_count: {
          handler: :UnreadCount, verb: :get, role: :view, scope: :mount,
          singleton_path: "unread_count", parent_path: "unread_count",
          title: "Count unread conversations",
          description: "Count unread conversations on this message center. Returns unread_count.",
          fields: {}
        }
      }.freeze

      module_function

      def fetch(action)
        ACTIONS.fetch(action.to_sym)
      end

      def conversation_fields(action, parent:)
        fields = fetch(action).fetch(:fields)
        return fields unless parent && fetch(action).fetch(:scope) == :conversation

        { conversation_id: CONVERSATION_FIELD }.merge(fields)
      end
    end
  end
end
