# frozen_string_literal: true

require_relative "tool_descriptions"

module RecordingStudioMessages
  module Api
    module GroupCatalog
      SEND_MESSAGE = {
        handler: :SendMessage,
        required_role: :edit,
        http_verb: :post,
        title: "Send message",
        summary: "Send message",
        description: ToolDescriptions::SEND_MESSAGE,
        id_description: ToolDescriptions::CONVERSATION_ID,
        path: "conversations/:id/send_message",
        fields: {
          body: {
            type: :string, required: false, allow_blank: true,
            description: "Message text. Required unless references is present."
          },
          references: {
            type: :array, required: false,
            description: "Recordings to attach. Each item is a recording id, or an object with recording_id. " \
                         "The actor must be able to view it, under the message center's parent recordable."
          }
        }
      }.freeze

      READ_THREAD = {
        handler: :ReadThread,
        required_role: :view,
        http_verb: :get,
        title: "Read messages",
        summary: "Read messages",
        description: ToolDescriptions::READ_THREAD,
        id_description: ToolDescriptions::CONVERSATION_ID,
        path: "conversations/:id/messages",
        fields: {}
      }.freeze

      RENAME_GROUP = {
        handler: :RenameGroup,
        required_role: :edit,
        http_verb: :post,
        title: "Rename conversation",
        summary: "Rename conversation",
        description: ToolDescriptions::RENAME_GROUP,
        id_description: ToolDescriptions::CONVERSATION_ID,
        path: "conversations/:id/rename_group",
        fields: {
          title: {
            type: :string, required: true, allow_blank: false,
            description: "New conversation name. Required, at most 120 characters."
          }
        }
      }.freeze

      MARK_READ = {
        handler: :MarkRead,
        required_role: :view,
        http_verb: :post,
        title: "Mark conversation read",
        summary: "Mark conversation read",
        description: ToolDescriptions::MARK_READ,
        id_description: ToolDescriptions::CONVERSATION_ID,
        path: "conversations/:id/mark_read",
        fields: {}
      }.freeze

      ACTIONS = {
        messages_send_message: SEND_MESSAGE,
        messages_read_thread: READ_THREAD,
        messages_rename_group: RENAME_GROUP,
        messages_mark_read: MARK_READ
      }.freeze
    end
  end
end
