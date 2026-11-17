# frozen_string_literal: true

require_relative "tool_descriptions"

module RecordingStudioMessages
  module Api
    module MountCatalog
      LIST_CONVERSATIONS = {
        handler: :ListConversations,
        required_role: :view,
        http_verb: :get,
        title: "Group - List",
        summary: "List conversations on this message center.",
        description: ToolDescriptions::LIST_CONVERSATIONS,
        id_description: ToolDescriptions::MESSAGE_CENTER_ID,
        path: "message_centers/:id/conversations",
        fields: {
          unread: {
            type: :boolean, required: false,
            description: "When true, only conversations with unread lines for this actor."
          },
          after_id: {
            type: :string, required: false, allow_blank: true,
            description: "Conversation id to page after. Use a records id from an earlier " \
                         "messages_list_conversations page. An id from another message center is rejected."
          },
          limit: {
            type: :integer, required: false,
            description: "Page size. Defaults to 50, the HTML inbox page size, and is clamped from 1 through 50."
          }
        }
      }.freeze

      CREATE_GROUP = {
        handler: :CreateGroup,
        required_role: :edit,
        http_verb: :post,
        title: "Group - Create",
        summary: "Start a conversation on this message center.",
        description: ToolDescriptions::CREATE_GROUP,
        id_description: ToolDescriptions::MESSAGE_CENTER_ID,
        path: "message_centers/:id/create_group",
        fields: {
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
        }
      }.freeze

      UNREAD_COUNT = {
        handler: :UnreadCount,
        required_role: :view,
        http_verb: :get,
        title: "Group - Unread count",
        summary: "Count unread conversations for this actor.",
        description: ToolDescriptions::UNREAD_COUNT,
        path: "unread_count",
        fields: {}
      }.freeze

      ENDPOINTS = {
        messages_list_conversations: LIST_CONVERSATIONS,
        messages_create_group: CREATE_GROUP,
        messages_unread_count: UNREAD_COUNT
      }.freeze
    end
  end
end
