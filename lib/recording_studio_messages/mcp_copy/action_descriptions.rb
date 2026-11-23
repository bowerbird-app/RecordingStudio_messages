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

      MY_MESSAGES = {
        list_my_messages: "List your conversations across message centers. Pass unread to keep unread " \
                          "conversations, after_id to continue, and limit for the page size. " \
                          "Returns records and after_id.",
        read_my_messages: "Read the messages in one of your conversations. Pass the conversation id from " \
                          "list_my_messages. Returns records.",
        send_my_message: "Send a message in one of your conversations. Pass the conversation id from " \
                         "list_my_messages. Pass body, or references to attach a recording. " \
                         "Returns the new message.",
        mark_my_message_read: "Mark one of your conversations read. Pass the conversation id from " \
                              "list_my_messages. Returns the conversation. The response has no read cursor.",
        count_unread_my_messages: "Count your unread conversations across message centers. Uses the same " \
                                  "conversations as list_my_messages. Returns unread_count."
      }.freeze

      PRESS_CENTER_ID = "Pass the press center id. "
      START_ARGS = "Pass the press center id and title. "
      BODY_WHEN = "when you add people in recipients"

      module_function

      def copy_for(action, names, preset: Api::Presets::PRESS_CENTER)
        return my_messages_copy(action) if preset.equal?(Api::Presets::MY_MESSAGES)

        key = action.to_sym
        {
          title: Api::Presets::PRESS_CENTER.titles.fetch(key),
          description: format(FORMATS.fetch(key), **fill(names))
        }
      end

      def my_messages_copy(action)
        key = action.to_sym
        {
          title: Api::Presets::MY_MESSAGES.titles.fetch(key),
          description: MY_MESSAGES.fetch(key)
        }
      end

      def fill(names)
        list = names[:list_conversations] || Api::ToolDescriptions::LIST_REF
        start = names[:create_group] || Api::ToolDescriptions::START_REF
        blanks.merge(ids(list)).merge(verbs(list, start)).merge(
          read: names[:read_thread] || Api::ToolDescriptions::READ_REF
        )
      end

      def blanks
        { view_access: "", edit_access: "", inherited: "" }
      end

      def ids(list)
        {
          id: PRESS_CENTER_ID,
          missing_mount: Api::ToolDescriptions::MISSING_MOUNT,
          list:,
          conversation: "conversation_id from #{list}",
          start_args: START_ARGS
        }
      end

      def verbs(list, start)
        {
          body_when: BODY_WHEN,
          send_pass: "conversation_id from #{list}. Pass body, or references to attach a recording",
          no_start: "This does not start a new conversation. Use #{start} to start one. ",
          rename_pass: "conversation_id from #{list} and title"
        }
      end
    end
  end
end
