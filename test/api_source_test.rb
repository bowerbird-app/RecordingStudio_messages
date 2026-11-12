# frozen_string_literal: true

require "test_helper"

class ApiSourceTest < Minitest::Test
  def test_register_has_one_api_availability_check
    source = File.read(File.expand_path("../lib/recording_studio_messages/api.rb", __dir__))

    assert_equal 1, source.scan("defined?(::RecordingStudioApi)").size
    assert_includes source, "each_api"
    refute_includes source, "apis: [:public]"
    refute_includes source, "const_set"
    refute_includes source, "remove_const"
  end

  def test_engine_registers_the_api_after_reload
    source = File.read(File.expand_path("../lib/recording_studio_messages/engine.rb", __dir__))

    assert_includes source, "Api.register!"
  end

  def test_api_handlers_call_public_messages_methods
    actions = File.read(File.expand_path("../lib/recording_studio_messages/api/actions.rb", __dir__))
    registration = File.read(File.expand_path("../lib/recording_studio_messages/api/registration.rb", __dir__))
    catalog = [
      File.read(File.expand_path("../lib/recording_studio_messages/api/group_catalog.rb", __dir__)),
      File.read(File.expand_path("../lib/recording_studio_messages/api/mount_catalog.rb", __dir__))
    ].join

    assert_includes actions, "RecordingStudioMessages.send_message"
    assert_includes actions, "RecordingStudioMessages.viewable_group_recordings"
    assert_includes actions, "RecordingStudioMessages.message_recordings"
    assert_includes actions, "RecordingStudioMessages.create_group"
    assert_includes actions, "RecordingStudioMessages.rename_group"
    assert_includes actions, "RecordingStudioMessages.mark_read"
    assert_includes actions, "RecordingStudioMessages.my_group_recordings"
    assert_includes actions, "accessible_recordings"
    refute_includes actions, "Services::SendMessage"
    refute_includes actions, ".send("
    assert_includes registration, "reject_unknown: false"
    assert_includes registration, "already registered"
    refute_includes registration, "enable_capability(:messages"
    assert_includes catalog, "Message - Send"
    assert_includes catalog, "Group - Create"
    assert_includes catalog, "messages_send_message"
    assert_includes catalog, "CreateGroupPeople requires :admin"
    refute_includes catalog, "public_contact"
    refute_includes catalog, "ensure_mount"
    refute_includes catalog, "untag"
  end
end
