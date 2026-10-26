# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ConfigurableLayoutTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @previous_layout = RecordingStudioMessages.configuration.layout
    @previous_core_layout = RecordingStudio.configuration.layout
    sign_in @staff
  end

  teardown do
    RecordingStudioMessages.configuration.layout = @previous_layout
    RecordingStudio.configuration.layout = @previous_core_layout
  end

  test "nil uses the core layout and then the default shell" do
    assert_nil RecordingStudioMessages.configuration.layout
    assert_nil RecordingStudio.configuration.layout

    get recording_studio_messages.message_groups_path

    assert_response :success
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "h1", count: 1
  end

  test "a nil messages layout follows RecordingStudio.configuration.layout" do
    assert_nil RecordingStudioMessages.configuration.layout
    RecordingStudio.configuration.layout = "application"

    get recording_studio_messages.message_groups_path

    assert_response :success
    assert_includes response.body, 'content="Dummy"'
    assert_select "body[data-recording-studio-default-layout]", count: 0
  end

  test "a layout name wraps the conversation list" do
    RecordingStudioMessages.configuration.layout = "application"

    get recording_studio_messages.message_groups_path

    assert_response :success
    assert_includes response.body, 'content="Dummy"'
    assert_select "body[data-recording-studio-default-layout]", count: 0
  end

  test "a keyword callable receives the controller" do
    seen = nil
    RecordingStudioMessages.configuration.layout = lambda { |controller:|
      seen = controller
      "application"
    }

    get recording_studio_messages.message_groups_path

    assert_response :success
    assert_equal "RecordingStudioMessages::MessageGroupsController", seen.class.name
    assert_select "body[data-recording-studio-default-layout]", count: 0
  end

  test "false renders the list without a document layout" do
    RecordingStudioMessages.configuration.layout = false
    RecordingStudio.configuration.layout = "recording_studio/default_layout"

    get recording_studio_messages.message_groups_path

    assert_response :success
    assert_includes response.body, "flat-pack--chat-layout"
    refute_match(/<html/i, response.body)
    assert_select "body[data-recording-studio-default-layout]", count: 0
  end

  test "a callable that returns a non-layout raises" do
    RecordingStudioMessages.configuration.layout = ->(controller:) { 1 }

    error = assert_raises(ArgumentError) { get recording_studio_messages.message_groups_path }

    assert_match "layout callable must return", error.message
  end
end
