# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"

class McpCopyTest < Minitest::Test
  def test_register_is_a_no_op_when_mcp_is_not_loaded
    hide_mcp_constant

    refute defined?(::RecordingStudioMcp)
    assert_nil RecordingStudioMessages::McpCopy.register!
  ensure
    restore_mcp_constant
  end

  def test_register_is_a_no_op_when_register_tool_is_missing
    hide_mcp_constant
    Object.const_set(:RecordingStudioMcp, Module.new)

    refute_respond_to RecordingStudioMcp, :register_tool
    assert_nil RecordingStudioMessages::McpCopy.register!
  ensure
    restore_mcp_constant
  end

  def test_press_center_tools_use_live_endpoint_names_and_the_press_center_messages_group
    hide_mcp_constant
    tools = {}
    types = []
    stub_mcp(tools: tools, types: types)
    at = unique_at
    place_press_center(at)
    place_support("#{at}s")

    RecordingStudioMessages::McpCopy.register!

    names = RecordingStudioMessages::McpCopy.press_center_tool_names(api: :public).select { |name| name.start_with?("#{at}_") }
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
    names.each { |name| assert tools.key?(name), "missing registered tool #{name}" }

    listed = RecordingStudioApi.registered_endpoint(:"#{at}_list_conversations")
    assert_equal ["Press Center Messages"], listed.openapi_tags
    assert_equal({ group: "Press Center" }, listed.openapi[:tag])
    tool = tools.fetch("#{at}_list_conversations")
    assert_equal :"#{at}_list_conversations", tool[:endpoint]
    assert_equal "Mailbox", tool[:type]
    assert_equal "List press center conversations", tool[:title]
    refute_includes tool[:description], "Accessible"
    refute_includes tool[:description], "Needs view"
    refute_includes tool[:description], ":edit"
    refute_includes RecordingStudioMessages::McpCopy.tool_names(api: :public), "#{at}s_reply"
    refute tools.key?("#{at}s_list_requests")
    refute tools.key?("#{at}s_open_request")
    refute_includes RecordingStudioMessages::McpCopy.tool_names, "support_reply"

    type_names = types.map { |entry| entry[:type] }
    assert_includes type_names, RecordingStudioMessages::MESSAGE_TYPE
    assert_includes type_names, RecordingStudioMessages::MESSAGE_GROUP_TYPE
    assert_includes type_names, RecordingStudioMessages::MESSAGE_MOUNT_TYPE
    types.each do |entry|
      refute_includes entry[:description], "Accessible"
      refute_includes entry[:description], "Access "
    end
  ensure
    restore_mcp_constant
  end

  def test_my_message_tools_wrap_catalog_actions_and_do_not_start_conversations
    hide_mcp_constant
    tools = {}
    stub_mcp(tools: tools)
    RecordingStudioMessages::Api::MyMessages.place!

    RecordingStudioMessages::McpCopy.register!

    names = %w[
      list_my_messages
      read_my_messages
      send_my_message
      mark_my_message_read
      count_unread_my_messages
    ]
    assert_equal names, RecordingStudioMessages::McpCopy.my_message_tool_names(api: :public)
    names.each { |name| assert tools.key?(name), "missing registered tool #{name}" }

    send = tools.fetch("send_my_message")
    assert_equal :send_my_message, send[:endpoint]
    assert_equal RecordingStudioMessages::MESSAGE_GROUP_TYPE, send[:type]
    assert_includes send[:description], "never starts a new conversation"
    refute tools.key?("create_my_messages")
    refute tools.key?("start_my_messages")
    assert_nil RecordingStudioApi.registered_endpoint(:create_my_messages)

    listed = RecordingStudioApi.registered_endpoint(:list_my_messages)
    assert_equal ["My Messages"], listed.openapi_tags
    assert_equal({ group: "My Messages" }, listed.openapi[:tag])
    assert_equal "my_messages/conversations", listed.path
    assert_equal :list_conversations, listed.handler.action
    assert listed.handler.placement.actor_inbox?
    refute_includes send[:description], "Accessible"
  ensure
    restore_mcp_constant
  end

  def test_tool_names_follow_the_api_the_host_placed
    hide_mcp_constant
    tools = {}
    stub_mcp(tools: tools)
    skip "operations API is not configured" unless RecordingStudioMessages::Api::MyMessages.named_api?(:operations)

    at = unique_at
    place_press_center(at, api: :operations)
    RecordingStudioMessages::McpCopy.register!

    name = "#{at}_list_conversations"
    assert_includes RecordingStudioMessages::McpCopy.press_center_tool_names(api: :operations), name
    refute_includes RecordingStudioMessages::McpCopy.press_center_tool_names(api: :public), name
    assert_includes RecordingStudioMessages::McpCopy.my_message_tool_names(api: :public), "list_my_messages"
    refute_includes RecordingStudioMessages::McpCopy.my_message_tool_names(api: :operations), "list_my_messages"
    assert tools.key?(name)
  ensure
    restore_mcp_constant
  end

  def test_gemspec_does_not_depend_on_recording_studio_mcp
    gemspec = File.read(File.expand_path("../recording_studio_messages.gemspec", __dir__))
    entry = File.read(File.expand_path("../lib/recording_studio_messages.rb", __dir__))
    engine = File.read(File.expand_path("../lib/recording_studio_messages/engine.rb", __dir__))

    refute_includes gemspec, "recording_studio_mcp"
    refute_includes entry, 'require "recording_studio_mcp"'
    assert_includes entry, 'require "recording_studio_messages/mcp_copy"'
    boot = File.read(File.expand_path("../lib/recording_studio_messages/engine_mcp.rb", __dir__))
    assert_includes engine, "include EngineMcp"
    assert_includes boot, 'initializer "recording_studio_messages.mcp", after: :load_config_initializers'
    assert_includes boot, "RecordingStudioMessages::McpCopy.register!"
    assert_includes boot, "RecordingStudioMessages::Api::MyMessages.place!"
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

  private

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

  def stub_mcp(tools:, types: [])
    mcp = Module.new
    mcp.define_singleton_method(:register_type) { |**registration| types << registration }
    mcp.define_singleton_method(:register_tool) do |**registration|
      tools[registration.fetch(:name)] = registration
    end
    Object.const_set(:RecordingStudioMcp, mcp)
    mcp
  end

  def hide_mcp_constant
    @saved_mcp = defined?(::RecordingStudioMcp) ? ::RecordingStudioMcp : :absent
    Object.send(:remove_const, :RecordingStudioMcp) if defined?(::RecordingStudioMcp)
  end

  def restore_mcp_constant
    Object.send(:remove_const, :RecordingStudioMcp) if defined?(::RecordingStudioMcp)
    return if @saved_mcp == :absent || @saved_mcp.nil?

    Object.const_set(:RecordingStudioMcp, @saved_mcp)
  end
end
