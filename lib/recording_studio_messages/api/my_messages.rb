# frozen_string_literal: true

require_relative "../mcp_copy/action_descriptions"

module RecordingStudioMessages
  module Api
    module MyMessages
      AT = :my_messages
      GROUP = "My Messages"
      ACTIONS = %i[list_conversations read_thread send_message mark_read unread_count].freeze
      NAMES = {
        list_conversations: :list_my_messages,
        read_thread: :read_my_messages,
        send_message: :send_my_message,
        mark_read: :mark_my_message_read,
        unread_count: :count_unread_my_messages
      }.freeze
      TITLES = {
        list_conversations: "List my messages",
        read_thread: "Read my messages",
        send_message: "Send my message",
        mark_read: "Mark my message read",
        unread_count: "Count unread my messages"
      }.freeze

      module_function

      def place!(api: :public)
        return unless defined?(::RecordingStudioApi) && named_api?(api)

        Placement.place(api:, descriptions: descriptions, **placement)
      end

      def placement
        {
          at: AT, mount: MountBinding::ACTOR_INBOX, actions: ACTIONS,
          names: NAMES, titles: TITLES, tags: [GROUP], tag_group: GROUP
        }
      end

      def descriptions
        McpCopy::ActionDescriptions::MY_MESSAGES.to_h do |action, copy|
          [action, copy.fetch(:description)]
        end
      end

      def named_api?(api)
        RecordingStudioApi.configuration.fetch_api(api)
        true
      rescue ::RecordingStudioApi::ConfigurationError
        false
      end
    end
  end
end
