# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"

class McpCopyTest < Minitest::Test
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

    listed = RecordingStudioApi.registered_endpoint(:"#{at}_list_conversations")
    assert_equal ["Press Center Messages"], listed.openapi_tags
    assert_equal({ group: "Press Center" }, listed.openapi[:tag])
    tool = fake.tools.fetch("#{at}_list_conversations")
    assert_equal :"#{at}_list_conversations", tool[:endpoint]
    assert_equal "Mailbox", tool[:type]
    assert_equal "List conversations", tool[:title]
    assert_includes tool[:description], "Message center not found"
    refute_includes tool[:description], "Create the press center first"
    refute_includes tool[:description], "Accessible"
    refute_includes tool[:description], "Needs view"
    refute_includes tool[:description], ":edit"
    refute_includes RecordingStudioMessages::McpCopy.tool_names(api: :public), "#{at}s_reply"
    refute fake.tools.key?("#{at}s_list_requests")
    refute fake.tools.key?("#{at}s_open_request")
    refute_includes RecordingStudioMessages::McpCopy.tool_names, "support_reply"
    refute_includes RecordingStudioMessages::McpCopy.tool_names, "list_my_messages"

    type_names = fake.types.map { |entry| entry[:type] }
    assert_includes type_names, RecordingStudioMessages::MESSAGE_TYPE
    assert_includes type_names, RecordingStudioMessages::MESSAGE_GROUP_TYPE
    assert_includes type_names, RecordingStudioMessages::MESSAGE_MOUNT_TYPE
    fake.types.each do |entry|
      refute_includes entry[:description], "Accessible"
      refute_includes entry[:description], "Access "
      refute_includes entry[:description], "Create the parent first"
    end
    mount = fake.types.find { |entry| entry[:type] == RecordingStudioMessages::MESSAGE_MOUNT_TYPE }
    assert_includes mount[:description], "show-only"
    assert_includes mount[:description], "Message center not found"
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

  def test_mcp_and_api_fill_the_same_press_center_formats
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
    assert_equal copy.fetch(:description), listed.openapi.fetch(:description)
    assert_equal RecordingStudioMessages::Api::ToolDescriptions::SEND, sent.openapi.fetch(:description)
    assert_includes send_copy.fetch(:description), "#{at}_list_conversations"
    assert_includes send_copy.fetch(:description), "#{at}_start_conversation"
    refute_includes send_copy.fetch(:description), "Accessible"
  end

  def test_gemspec_does_not_depend_on_recording_studio_mcp
    gemspec = File.read(File.expand_path("../recording_studio_messages.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_messages.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_messages/engine.rb", __dir__))
    boot = File.read(File.expand_path("../lib/recording_studio_messages/engine_mcp.rb", __dir__))

    refute_includes gemspec, "recording_studio_mcp"
    refute_includes entry, 'require "recording_studio_mcp"'
    assert_includes entry, 'require "recording_studio_messages/mcp_copy"'
    assert_includes engine, 'require_relative "engine_mcp"'
    refute_includes engine, "module EngineExtensions"
    assert_includes boot, 'initializer "recording_studio_messages.mcp", after: :load_config_initializers'
    assert_includes boot, "RecordingStudioMessages::McpCopy.register!"
    refute_includes boot, "MyMessages"
    refute_includes boot, "place!"
  end

  def test_mcp_copy_has_no_production_const_set_or_rubocop_disable
    files = Dir[
      File.expand_path("../lib/recording_studio_messages/mcp_copy.rb", __dir__),
      File.expand_path("../lib/recording_studio_messages/mcp_copy/**/*.rb", __dir__)
    ]
    files.each do |path|
      source = File.read(path)
      refute_includes source, "const_set", path
      refute_includes source, "rubocop:disable", path
    end
  end

  def test_engine_does_not_place_endpoints
    engine = File.read(File.expand_path("../lib/recording_studio_messages/engine.rb", __dir__))
    boot = File.read(File.expand_path("../lib/recording_studio_messages/engine_mcp.rb", __dir__))

    refute_includes engine, "Api.register!"
    refute_includes engine, "MyMessages"
    refute_includes boot, "MyMessages"
    refute RecordingStudioApi.registered_endpoint(:messages_send_message)
    refute RecordingStudioApi.registered_endpoint(:list_my_messages)
  end

  private

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

  def unique_at
    "t#{SecureRandom.hex(4)}"
  end
end
