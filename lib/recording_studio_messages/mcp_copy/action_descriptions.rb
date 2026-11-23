# frozen_string_literal: true

require_relative "../api/tool_descriptions"

module RecordingStudioMessages
  module McpCopy
    module ActionDescriptions
      FORMATS = {
        list_conversations: Api::ToolDescriptions::LIST_FORMAT,
        create_group: Api::ToolDescriptions::CREATE_FORMAT,
        read_thread: Api::ToolDescriptions::READ_FORMAT,
        send_message: Api::ToolDescriptions::SEND_FORMAT,
        rename_group: Api::ToolDescriptions::RENAME_FORMAT,
        mark_read: Api::ToolDescriptions::MARK_READ_FORMAT,
        unread_count: Api::ToolDescriptions::UNREAD_COUNT_FORMAT
      }.freeze

      module_function

      def copy_for(action, names)
        key = action.to_sym
        template = FORMATS.fetch(key)
        fillers = fill(names, template)
        {
          title: Api::Presets::PRESS_CENTER.titles.fetch(key),
          description: fillers.empty? ? template : format(template, **fillers)
        }
      end

      def fill(names, template)
        refs = {
          list: names[:list_conversations] || Api::ToolDescriptions::LIST_REF,
          start: names[:create_group] || Api::ToolDescriptions::START_REF,
          read: names[:read_thread] || Api::ToolDescriptions::READ_REF
        }
        refs.slice(*placeholders(template))
      end

      def placeholders(template)
        template.scan(/%<(\w+)>s/).flatten.map(&:to_sym)
      end
    end
  end
end
