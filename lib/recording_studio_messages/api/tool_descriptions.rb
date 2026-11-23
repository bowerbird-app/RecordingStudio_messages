# frozen_string_literal: true

require_relative "tool_description_formats"

module RecordingStudioMessages
  module Api
    module ToolDescriptions
      LIST_REF = "the list"
      START_REF = "Start conversation"
      READ_REF = "Read messages"
      CONVERSATION_REF = "the conversation id"
      VIEW_ACCESS = "Needs view access. "
      EDIT_ACCESS = "Needs edit access. "
      INHERITED = ", including access inherited on that message center"
      MISSING_MOUNT =
        "Press-center tools return Message center not found when that press center has no message center yet. "

      API_FILL = {
        id: "",
        missing_mount: "",
        view_access: VIEW_ACCESS,
        edit_access: EDIT_ACCESS,
        list: LIST_REF,
        inherited: INHERITED,
        conversation: CONVERSATION_REF,
        start_args: "Pass title. ",
        body_when: "when recipients are present",
        send_pass: "the conversation id and body, or references",
        no_start: "",
        rename_pass: "the conversation id and title",
        start: START_REF,
        read: READ_REF
      }.freeze

      LIST = format(LIST_FORMAT, **API_FILL).freeze
      CREATE = format(CREATE_FORMAT, **API_FILL).freeze
      READ = format(READ_FORMAT, **API_FILL).freeze
      SEND = format(SEND_FORMAT, **API_FILL).freeze
      RENAME = format(RENAME_FORMAT, **API_FILL).freeze
      MARK_READ = format(MARK_READ_FORMAT, **API_FILL).freeze
      UNREAD_COUNT = format(UNREAD_COUNT_FORMAT, **API_FILL).freeze

      MESSAGE_MOUNT = MESSAGE_MOUNT_FORMAT
      MESSAGE_GROUP = format(MESSAGE_GROUP_FORMAT, **API_FILL).freeze
      MESSAGE = format(MESSAGE_FORMAT, **API_FILL).freeze
    end
  end
end
