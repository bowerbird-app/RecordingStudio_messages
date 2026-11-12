# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module GroupCatalog
      SEND_MESSAGE = {
        handler: :SendMessage,
        required_role: :edit,
        http_verb: :post,
        title: "Message - Send",
        summary: "Send a message in this conversation.",
        description: "Calls RecordingStudioMessages.send_message. " \
                     "Needs Accessible edit on the conversation. " \
                     "Do not create a Message record through the generic API.",
        path: "conversations/:id/send_message",
        fields: {
          body: {
            type: :string, required: false, allow_blank: true,
            description: "Message text. Required unless a reference is present."
          },
          references: {
            type: :array, required: false,
            description: "Recordings to attach to the line."
          }
        }
      }.freeze

      READ_THREAD = {
        handler: :ReadThread,
        required_role: :view,
        http_verb: :get,
        title: "Message - Read thread",
        summary: "Read the messages in this conversation.",
        description: "Calls RecordingStudioMessages.message_recordings. " \
                     "Needs Accessible view on the conversation.",
        path: "conversations/:id/messages",
        fields: {}
      }.freeze

      RENAME_GROUP = {
        handler: :RenameGroup,
        required_role: :edit,
        http_verb: :post,
        title: "Group - Rename",
        summary: "Rename this conversation.",
        description: "Calls RecordingStudioMessages.rename_group. " \
                     "Needs Accessible edit on the conversation.",
        path: "conversations/:id/rename_group",
        fields: {
          title: {
            type: :string, required: true, allow_blank: false,
            description: "New conversation name."
          }
        }
      }.freeze

      MARK_READ = {
        handler: :MarkRead,
        required_role: :view,
        http_verb: :post,
        title: "Group - Mark read",
        summary: "Mark this conversation as read.",
        description: "Calls RecordingStudioMessages.mark_read. " \
                     "Needs Accessible view on the conversation.",
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
