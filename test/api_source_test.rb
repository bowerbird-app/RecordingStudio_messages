# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"

class ApiSourceTest < Minitest::Test
  def setup
    RecordingStudioMessages::Api.register!
  end

  def test_register_is_idempotent_across_reload
    RecordingStudioMessages::Api.register!

    mount = RecordingStudioApi.recordable_registration_for(
      RecordingStudioMessages::MESSAGE_MOUNT_TYPE
    )
    group = RecordingStudioApi.recordable_registration_for(
      RecordingStudioMessages::MESSAGE_GROUP_TYPE
    )

    assert mount
    assert group
    assert_equal [], mount.capability_actions
    assert_equal [], group.capability_actions
    assert_equal false, mount.auto_capability_actions
    assert_equal false, group.auto_capability_actions
    assert RecordingStudioApi.registered_endpoint(:messages_send_message)
    assert RecordingStudioApi.registered_endpoint(:messages_list_conversations)
    refute RecordingStudioApi.capability_action(:messages_send_message)
    refute RecordingStudioApi.capability_action(:messages_list_conversations)
  end

  def test_engine_to_prepare_registers_the_api
    assert RecordingStudioApi.registered_endpoint(:messages_unread_count)
  end

  def test_handlers_call_public_messages_methods
    send_message = RecordingStudioApi.registered_endpoint(:messages_send_message)
    list = RecordingStudioApi.registered_endpoint(:messages_list_conversations)
    create_group = RecordingStudioApi.registered_endpoint(:messages_create_group)

    assert_equal RecordingStudioMessages::Api::Actions::SendMessage, send_message.handler
    assert_equal RecordingStudioMessages::Api::Actions::ListConversations, list.handler
    assert_equal RecordingStudioMessages::Api::Actions::CreateGroup, create_group.handler
    assert_equal "Message - Send", send_message.openapi.fetch(:title)
    assert_equal "Group - Create", create_group.openapi.fetch(:title)
    refute send_message.input_contract.as_json.fetch(:reject_unknown)
  end

  def test_wrap_maps_facade_input_errors_and_leaves_other_argument_errors
    not_authorized = assert_raises(RecordingStudioApi::AuthorizationError) do
      RecordingStudioMessages::Api::Errors.wrap do
        raise RecordingStudioMessages::NotAuthorized, "closed"
      end
    end
    assert_equal "closed", not_authorized.message

    domain = assert_raises(RecordingStudioApi::InvalidActionInputError) do
      RecordingStudioMessages::Api::Errors.wrap do
        raise RecordingStudioMessages::Error, "write something"
      end
    end
    assert_equal "write something", domain.message

    missing_mount = assert_raises(ArgumentError) do
      RecordingStudioMessages::Api::Errors.wrap do
        RecordingStudioMessages.create_group(nil, actor: :missing)
      end
    end
    assert_equal "mount recording is required", missing_mount.message

    assert_raises(ArgumentError) do
      RecordingStudioMessages::Api::Errors.wrap { Integer("nope") }
    end
  end

  def test_target_recordable_fields_call_registration_serializers
    group = Struct.new(:title).new("Desk thread")
    mount = Struct.new(:key).new("support")
    group_recording = Struct.new(:recordable, :recordable_type).new(
      group, RecordingStudioMessages::MESSAGE_GROUP_TYPE
    )
    mount_recording = Struct.new(:recordable, :recordable_type).new(
      mount, RecordingStudioMessages::MESSAGE_MOUNT_TYPE
    )

    assert_equal({ title: "Desk thread" }, RecordingStudioMessages::Api::Registration.serialize_group(group))
    assert_equal(
      RecordingStudioMessages::Api::Registration.serialize_group(group),
      RecordingStudioMessages::Api::Target.recordable_fields(group_recording)
    )
    assert_equal({ key: "support" }, RecordingStudioMessages::Api::Registration.serialize_mount(mount))
    assert_equal(
      RecordingStudioMessages::Api::Registration.serialize_mount(mount),
      RecordingStudioMessages::Api::Target.recordable_fields(mount_recording)
    )
  end
end
