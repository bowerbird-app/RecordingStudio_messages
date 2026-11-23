# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"

class ApiToolDescriptionsTest < Minitest::Test
  MAIN_PRESS_CENTER = {
    list_conversations:
      "List conversations on this press center's message center. Pass unread, " \
      "after_id, or limit. Needs view access. Returns records and after_id.",
    create_group:
      "Start a conversation on this press center's message center. Pass title. Pass body " \
      "when recipients are present. Needs edit access. Returns the new conversation.",
    read_thread:
      "Read the messages in one conversation on this press center. Pass the conversation id. " \
      "Needs view access. Returns records.",
    send_message:
      "Send a message in a conversation on this press center. Pass the conversation id and " \
      "body, or references. Needs edit access. Returns the new message.",
    rename_group:
      "Rename one conversation on this press center. Pass the conversation id and title. " \
      "Title is required and must be 120 characters or fewer. Needs edit access. " \
      "Returns the conversation.",
    mark_read:
      "Mark one conversation read on this press center. Pass the conversation id. " \
      "Needs view access. Returns the conversation.",
    unread_count:
      "Count unread conversations on this press center's message center. Uses the same " \
      "conversations as the list, including access inherited on that message center. " \
      "Needs view access. Returns unread_count."
  }.freeze

  CONSTANTS = {
    list_conversations: :LIST,
    create_group: :CREATE,
    read_thread: :READ,
    send_message: :SEND,
    rename_group: :RENAME,
    mark_read: :MARK_READ,
    unread_count: :UNREAD_COUNT
  }.freeze

  FORMATS = {
    list_conversations: :LIST_FORMAT,
    create_group: :CREATE_FORMAT,
    read_thread: :READ_FORMAT,
    send_message: :SEND_FORMAT,
    rename_group: :RENAME_FORMAT,
    mark_read: :MARK_READ_FORMAT,
    unread_count: :UNREAD_COUNT_FORMAT
  }.freeze

  def test_press_center_api_descriptions_match_main
    copy = RecordingStudioMessages::Api::ToolDescriptions

    MAIN_PRESS_CENTER.each do |action, expected|
      filled = format(copy.const_get(FORMATS.fetch(action)), **copy::API_FILL)
      constant = copy.const_get(CONSTANTS.fetch(action))

      assert_equal expected, filled, action
      assert_equal expected, constant, action
    end
  end

  def test_placed_press_center_endpoints_keep_main_openapi_descriptions
    at = unique_at
    RecordingStudioMessages::Api.place(
      api: :public,
      at:,
      mount: { recordable_type: "Mailbox", key: :inbox },
      preset: :press_center
    )

    MAIN_PRESS_CENTER.each do |action, expected|
      suffix = RecordingStudioMessages::Api::Presets::PRESS_CENTER.names.fetch(action)
      endpoint = RecordingStudioApi.registered_endpoint(:"#{at}_#{suffix}")

      assert_equal expected, endpoint.openapi.fetch(:description), action
    end
  end

  private

  def unique_at
    "t#{SecureRandom.hex(4)}"
  end
end
