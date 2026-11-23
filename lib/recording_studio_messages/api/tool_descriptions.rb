# frozen_string_literal: true

require_relative "tool_description_formats"

module RecordingStudioMessages
  module Api
    module ToolDescriptions
      LIST_REF = "the conversation list on this press center"
      START_REF = "start conversation"
      READ_REF = "read messages"

      LIST = LIST_FORMAT
      CREATE = CREATE_FORMAT
      READ = format(READ_FORMAT, list: LIST_REF).freeze
      SEND = format(SEND_FORMAT, list: LIST_REF, start: START_REF).freeze
      RENAME = format(RENAME_FORMAT, list: LIST_REF).freeze
      MARK_READ = format(MARK_READ_FORMAT, list: LIST_REF).freeze
      UNREAD_COUNT = format(UNREAD_COUNT_FORMAT, list: LIST_REF).freeze

      MESSAGE_MOUNT = MESSAGE_MOUNT_FORMAT
      MESSAGE_GROUP = format(MESSAGE_GROUP_FORMAT, list: LIST_REF, start: START_REF).freeze
      MESSAGE = format(MESSAGE_FORMAT, read: READ_REF).freeze
    end
  end
end
