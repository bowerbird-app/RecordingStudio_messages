# frozen_string_literal: true

module RecordingStudioMessages
  module Api
    module MountCatalog
      LIST_CONVERSATIONS = {
        handler: :ListConversations,
        required_role: :view,
        http_verb: :get,
        title: "Group - List",
        summary: "List conversations on this desk.",
        description: "Calls RecordingStudioMessages.viewable_group_recordings. " \
                     "Needs Accessible view on the desk.",
        path: "desks/:id/conversations",
        fields: {
          unread: {
            type: :boolean, required: false,
            description: "When true, only conversations with unread lines."
          },
          after_id: {
            type: :string, required: false, allow_blank: true,
            description: "Conversation id to page after."
          },
          limit: {
            type: :integer, required: false,
            description: "Page size. Defaults to the HTML inbox size and never returns more."
          },
          tags: {
            type: :hash, required: false,
            description: "Tag filter passed to viewable_group_recordings."
          }
        }
      }.freeze

      CREATE_GROUP = {
        handler: :CreateGroup,
        required_role: :edit,
        http_verb: :post,
        title: "Group - Create",
        summary: "Start a conversation on this desk.",
        description: "Calls RecordingStudioMessages.create_group. " \
                     "Needs Accessible edit on the desk. " \
                     "On a :members desk, CreateGroupPeople requires :admin, " \
                     "so the API client must be an admin client.",
        path: "desks/:id/create_group",
        fields: {
          title: {
            type: :string, required: false, allow_blank: true,
            description: "Conversation name. Required when recipients are omitted."
          },
          body: {
            type: :string, required: false, allow_blank: true,
            description: "First message. Required when recipients are present."
          },
          recipients: {
            type: :array, required: false,
            description: "People to add. Each item is a type and id, or a token."
          },
          tags: {
            type: :hash, required: false,
            description: "Optional tags written with the conversation."
          }
        }
      }.freeze

      UNREAD_COUNT = {
        handler: :UnreadCount,
        required_role: :view,
        http_verb: :get,
        title: "Group - Unread count",
        summary: "Count unread conversations for this actor.",
        description: "Counts unread conversations in my_group_recordings that " \
                     "this AccessGrant can reach. Needs Accessible view on the access recording.",
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
