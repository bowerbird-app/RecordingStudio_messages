# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"

class McpCopyTest < Minitest::Test
  ACCESS_PHRASES = [
    "Accessible",
    "Needs view",
    "Needs edit",
    "including access inherited",
    ":edit",
    "Access "
  ].freeze

  class FakeMcp
    attr_reader :tools, :types

    def initialize
      @tools = {}
      @types = []
    end

    def register_tool(**registration)
      @tools[registration.fetch(:name)] = registration
    end

    def register_type(**registration)
      @types << registration
    end
  end

  def test_register_is_a_no_op_when_mcp_is_not_loaded
    RecordingStudioMessages::McpCopy.stub(:mcp, nil) do
      refute RecordingStudioMessages::McpCopy.mcp_available?
      assert_nil RecordingStudioMessages::McpCopy.register!
    end
  end

  def test_register_is_a_no_op_when_register_tool_is_missing
    RecordingStudioMessages::McpCopy.stub(:mcp, Object.new) do
      refute RecordingStudioMessages::McpCopy.mcp_available?
      assert_nil RecordingStudioMessages::McpCopy.register!
    end
  end

  def test_press_center_tools_use_live_endpoint_names_and_the_press_center_messages_group
    fake = FakeMcp.new
    at = unique_at
    place_press_center(at)
    place_support("#{at}s")

    RecordingStudioMessages::McpCopy.stub(:mcp, fake) do
      RecordingStudioMessages::McpCopy.register!
    end

    names = RecordingStudioMessages::McpCopy.tool_names(api: :public).select { |name| name.start_with?("#{at}_") }
    expected = %W[
      #{at}_list_conversations
      #{at}_start_conversation
      #{at}_read_messages
      #{at}_send_message
      #{at}_rename_conversation
      #{at}_mark_read
      #{at}_unread_count
    ]
    assert_equal expected, names
    names.each { |name| assert fake.tools.key?(name), "missing registered tool #{name}" }

    assert_list_tool fake.tools.fetch("#{at}_list_conversations"), at
    fake.tools.each_value { |tool| refute_access_wording tool[:description] }
    refute_includes RecordingStudioMessages::McpCopy.tool_names(api: :public), "#{at}s_reply"
    refute fake.tools.key?("#{at}s_list_requests")
    refute fake.tools.key?("#{at}s_open_request")
    refute_includes RecordingStudioMessages::McpCopy.tool_names, "support_reply"
    assert_registered_types fake.types
  end

  def test_tool_names_follow_the_api_the_host_placed
    skip "operations API is not configured" unless named_api?("operations")

    fake = FakeMcp.new
    at = unique_at
    place_press_center(at, api: :operations)
    RecordingStudioMessages::McpCopy.stub(:mcp, fake) do
      RecordingStudioMessages::McpCopy.register!
    end

    name = "#{at}_list_conversations"
    assert_includes RecordingStudioMessages::McpCopy.tool_names(api: :operations), name
    refute_includes RecordingStudioMessages::McpCopy.tool_names(api: :public), name
    assert fake.tools.key?(name)
  end

  def test_mcp_fills_add_missing_mount_and_leave_api_access_wording_off
    at = unique_at
    place_press_center(at)
    names = {
      list_conversations: "#{at}_list_conversations",
      create_group: "#{at}_start_conversation",
      read_thread: "#{at}_read_messages"
    }
    listed = RecordingStudioApi.registered_endpoint(:"#{at}_list_conversations")
    sent = RecordingStudioApi.registered_endpoint(:"#{at}_send_message")
    copy = RecordingStudioMessages::McpCopy::ActionDescriptions.copy_for(:list_conversations, names)
    send_copy = RecordingStudioMessages::McpCopy::ActionDescriptions.copy_for(:send_message, names)

    assert_equal RecordingStudioMessages::Api::ToolDescriptions::LIST, listed.openapi.fetch(:description)
    refute_equal copy.fetch(:description), listed.openapi.fetch(:description)
    assert_equal RecordingStudioMessages::Api::ToolDescriptions::SEND, sent.openapi.fetch(:description)
    assert_includes send_copy.fetch(:description), "#{at}_list_conversations"
    assert_includes send_copy.fetch(:description), "#{at}_start_conversation"
    refute_access_wording copy.fetch(:description)
    refute_access_wording send_copy.fetch(:description)
  end

  def test_register_does_not_place_support_tools
    fake = FakeMcp.new
    at = unique_at
    place_support(at)
    RecordingStudioMessages::McpCopy.stub(:mcp, fake) do
      RecordingStudioMessages::McpCopy.register!
    end

    refute fake.tools.key?("#{at}_reply")
    refute fake.tools.key?("#{at}_list_requests")
    refute fake.tools.key?("support_reply")
  end

  def test_my_messages_tools_use_fixed_names
    fake = FakeMcp.new
    place_my_messages
    RecordingStudioMessages::McpCopy.stub(:mcp, fake) do
      RecordingStudioMessages::McpCopy.register!
    end

    expected = %w[
      list_my_messages
      read_my_messages
      send_my_message
      mark_my_message_read
      count_unread_my_messages
    ]
    names = RecordingStudioMessages::McpCopy.tool_names(api: :public)
    expected.each do |name|
      assert_includes names, name
      assert fake.tools.key?(name), "missing registered tool #{name}"
      refute_access_wording fake.tools.fetch(name).fetch(:description)
    end

    listed = fake.tools.fetch("list_my_messages")
    assert_equal :list_my_messages, listed[:endpoint]
    assert_equal "List my messages", listed[:title]
    assert_equal RecordingStudioMessages::MESSAGE_GROUP_TYPE, listed[:type]
    assert_includes listed[:description], "after_id"
    assert_equal "Count unread messages", fake.tools.fetch("count_unread_my_messages").fetch(:title)
    refute_includes names, "my_messages_list_my_messages"
  end

  private

  def assert_list_tool(tool, at)
    missing_mount = RecordingStudioMessages::Api::ToolDescriptions::MISSING_MOUNT.strip

    assert_equal :"#{at}_list_conversations", tool[:endpoint]
    assert_equal "Mailbox", tool[:type]
    assert_equal "List conversations", tool[:title]
    assert_includes tool[:description], missing_mount
    refute_includes tool[:description], "Create the press center first"
    refute_access_wording tool[:description]
  end

  def assert_registered_types(types)
    type_names = types.map { |entry| entry[:type] }
    assert_includes type_names, RecordingStudioMessages::MESSAGE_TYPE
    assert_includes type_names, RecordingStudioMessages::MESSAGE_GROUP_TYPE
    assert_includes type_names, RecordingStudioMessages::MESSAGE_MOUNT_TYPE
    types.each do |entry|
      refute_access_wording entry[:description]
      refute_includes entry[:description], "Create the parent first"
      refute_includes entry[:description], "Message center not found"
    end
    mount = types.find { |entry| entry[:type] == RecordingStudioMessages::MESSAGE_MOUNT_TYPE }
    assert_includes mount[:description], "show-only"
  end

  def refute_access_wording(text)
    ACCESS_PHRASES.each { |phrase| refute_includes text, phrase }
  end

  def named_api?(name)
    RecordingStudioApi.configuration.api_names.map(&:to_s).include?(name.to_s)
  end

  def place_press_center(at, api: :public)
    RecordingStudioMessages::Api.place(
      api:,
      at:,
      mount: { recordable_type: "Mailbox", key: :inbox },
      preset: :press_center
    )
  end

  def place_support(at)
    RecordingStudioMessages::Api.place(api: :public, at:, mount: -> {}, preset: :support)
  end

  def place_my_messages
    RecordingStudioMessages::Api.place(api: :public, at: :my_messages, preset: :my_messages)
  end

  def unique_at
    "t#{SecureRandom.hex(4)}"
  end
end
