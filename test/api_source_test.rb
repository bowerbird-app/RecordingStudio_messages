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

    message = RecordingStudioApi.recordable_registration_for(
      RecordingStudioMessages::MESSAGE_TYPE
    )

    assert mount
    assert group
    assert message
    assert_equal %i[show], message.operations
    assert_equal [], mount.capability_actions
    assert_equal [], group.capability_actions
    assert_equal [], message.capability_actions
    assert_equal false, mount.auto_capability_actions
    assert_equal false, group.auto_capability_actions
    assert_equal false, message.auto_capability_actions
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
    assert_equal "message_centers/:id/conversations", list.path
    assert_equal "message_centers/:id/create_group", create_group.path
    assert_equal "List conversations on this message center.", list.openapi.fetch(:summary)
    assert_equal "Start a conversation on this message center.", create_group.openapi.fetch(:summary)
    assert_includes list.openapi.fetch(:description), "Needs view access to the message center."
    assert_includes create_group.openapi.fetch(:description), "On a members message center"
    refute send_message.input_contract.as_json.fetch(:reject_unknown)
  end

  def test_tool_descriptions_name_ids_and_keep_the_same_params
    tools = {
      messages_list_conversations: {
        path: "message_centers/:id/conversations", verb: :get, role: :view,
        fields: {
          unread: { type: :boolean, required: false },
          after_id: { type: :string, required: false, allow_blank: true },
          limit: { type: :integer, required: false }
        }
      },
      messages_create_group: {
        path: "message_centers/:id/create_group", verb: :post, role: :edit,
        fields: {
          title: { type: :string, required: false, allow_blank: true },
          body: { type: :string, required: false, allow_blank: true },
          recipients: { type: :array, required: false }
        }
      },
      messages_unread_count: {
        path: "unread_count", verb: :get, role: :view, fields: {}
      },
      messages_send_message: {
        path: "conversations/:id/send_message", verb: :post, role: :edit,
        fields: {
          body: { type: :string, required: false, allow_blank: true },
          references: { type: :array, required: false }
        }
      },
      messages_read_thread: {
        path: "conversations/:id/messages", verb: :get, role: :view, fields: {}
      },
      messages_rename_group: {
        path: "conversations/:id/rename_group", verb: :post, role: :edit,
        fields: {
          title: { type: :string, required: true, allow_blank: false }
        }
      },
      messages_mark_read: {
        path: "conversations/:id/mark_read", verb: :post, role: :view, fields: {}
      }
    }
    catalog_names = RecordingStudioMessages::Api::MountCatalog::ENDPOINTS.keys +
                    RecordingStudioMessages::Api::GroupCatalog::ACTIONS.keys

    assert_equal tools.keys.sort, catalog_names.sort

    tools.each do |name, expected|
      endpoint = RecordingStudioApi.registered_endpoint(name)
      description = endpoint.openapi.fetch(:description).to_s
      fields = endpoint.input_contract.as_json.fetch(:fields)

      assert description.present?, name.to_s
      assert_includes description, "Returns", name.to_s
      refute_includes description, "Calls RecordingStudioMessages", name.to_s
      refute_includes description, "Path parameter", name.to_s
      assert_equal expected[:path], endpoint.path, name.to_s
      assert_equal expected[:verb], endpoint.http_verb, name.to_s
      assert_equal expected[:role], endpoint.required_role, name.to_s
      assert_equal false, endpoint.input_contract.as_json.fetch(:reject_unknown), name.to_s
      assert_equal expected[:fields].keys, fields.keys, name.to_s

      expected[:fields].each do |field, rules|
        text = fields.fetch(field).fetch(:description).to_s

        assert_equal rules, fields.fetch(field).except(:description), "#{name} #{field}"
        refute_equal "Path parameter id.", text, "#{name} #{field}"
        assert text.present?, "#{name} #{field}"
      end

      endpoint.openapi_path_parameters.each do |param|
        text = param.fetch(:description).to_s

        refute_equal "Path parameter id.", text, name.to_s
        refute_equal "Path parameter #{param[:name]}.", text, name.to_s
        assert_match(/\AThe (message center|conversation) id\b/, text, name.to_s)
      end
    end

    assert_empty RecordingStudioApi.registered_endpoint(:messages_unread_count).openapi_path_parameters
    assert_includes endpoint_description(:messages_list_conversations), "message center"
    assert_includes endpoint_description(:messages_list_conversations), "after_id"
    assert_includes endpoint_description(:messages_create_group), "admin"
    assert_includes endpoint_description(:messages_send_message), "recording_id"
    assert_includes endpoint_description(:messages_read_thread), "records"
    assert_includes endpoint_description(:messages_rename_group), "120"
    assert_includes endpoint_description(:messages_mark_read), "read cursor"
    assert_includes endpoint_description(:messages_unread_count), "unread_count"
  end

  def test_endpoints_declare_recordable_type_and_required_role
    group = RecordingStudioMessages::MESSAGE_GROUP_TYPE
    mount = RecordingStudioMessages::MESSAGE_MOUNT_TYPE
    scoped = {
      messages_send_message: [group, :edit],
      messages_read_thread: [group, :view],
      messages_rename_group: [group, :edit],
      messages_mark_read: [group, :view],
      messages_list_conversations: [mount, :view],
      messages_create_group: [mount, :edit]
    }

    scoped.each do |name, (type, role)|
      endpoint = RecordingStudioApi.registered_endpoint(name)

      assert_equal type, endpoint.recordable_type, name.to_s
      assert_equal role, endpoint.required_role, name.to_s
      assert endpoint.scopes_recording?, name.to_s
      refute endpoint.owns_scoping?, name.to_s
    end

    unread = RecordingStudioApi.registered_endpoint(:messages_unread_count)
    assert_nil unread.recordable_type
    assert_equal :view, unread.required_role
    refute unread.scopes_recording?
    refute unread.owns_scoping?
  end

  def endpoint_description(name)
    RecordingStudioApi.registered_endpoint(name).openapi.fetch(:description)
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
    group = Struct.new(:title).new("Message center thread")
    mount = Struct.new(:key).new("support")
    group_recording = Struct.new(:recordable, :recordable_type).new(
      group, RecordingStudioMessages::MESSAGE_GROUP_TYPE
    )
    mount_recording = Struct.new(:recordable, :recordable_type).new(
      mount, RecordingStudioMessages::MESSAGE_MOUNT_TYPE
    )

    assert_equal({ title: "Message center thread" }, RecordingStudioMessages::Api::Registration.serialize_group(group))
    assert_equal(
      RecordingStudioMessages::Api::Registration.serialize_group(group),
      RecordingStudioMessages::Api::Target.recordable_fields(group_recording)
    )
    assert_equal({ key: "support" }, RecordingStudioMessages::Api::Registration.serialize_mount(mount))
    assert_equal(
      RecordingStudioMessages::Api::Registration.serialize_mount(mount),
      RecordingStudioMessages::Api::Target.recordable_fields(mount_recording)
    )

    message = Struct.new(:body).new("Hello from the message center.")
    message_recording = Struct.new(:recordable, :recordable_type).new(
      message, RecordingStudioMessages::MESSAGE_TYPE
    )
    assert_equal(
      { body: "Hello from the message center." },
      RecordingStudioMessages::Api::Registration.serialize_message(message)
    )
    assert_equal(
      RecordingStudioMessages::Api::Registration.serialize_message(message),
      RecordingStudioMessages::Api::Target.recordable_fields(message_recording)
    )
  end
end
