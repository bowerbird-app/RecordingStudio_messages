# frozen_string_literal: true

require "test_helper"
require "recording_studio_api"

class ApiSourceTest < Minitest::Test
  def test_place_is_idempotent_and_the_engine_does_not_register
    at = unique_at
    place_support(at)
    place_support(at)

    endpoint = RecordingStudioApi.registered_endpoint(:"#{at}_open_request")
    assert_equal "Open request", endpoint.openapi.fetch(:title)
    assert_equal ["Support"], endpoint.openapi_tags

    engine = File.read(File.expand_path("../lib/recording_studio_messages/engine.rb", __dir__))
    refute_includes engine, "Api.register!"
    refute RecordingStudioApi.registered_endpoint(:messages_send_message)
  end

  def test_place_registers_message_types_as_show_only
    at = unique_at
    place_support(at)
    place_support(at)

    [
      RecordingStudioMessages::MESSAGE_TYPE,
      RecordingStudioMessages::MESSAGE_GROUP_TYPE,
      RecordingStudioMessages::MESSAGE_MOUNT_TYPE
    ].each do |type|
      registration = RecordingStudioApi.recordable_registration_for(type)
      assert_equal %i[show], registration.operations
      %i[create update destroy].each do |operation|
        refute registration.supports_operation?(operation), "#{type} #{operation}"
      end
    end
  end

  def test_support_preset_chooses_actions_names_descriptions_and_paths
    at = unique_at
    place_support(at)

    reply = RecordingStudioApi.registered_endpoint(:"#{at}_reply")
    listed = RecordingStudioApi.registered_endpoint(:"#{at}_list_requests")
    counted = RecordingStudioApi.registered_endpoint(:"#{at}_unread_count")

    assert_equal "POST", reply.http_verb.to_s.upcase
    assert_equal "#{at}/conversations/:id/send_message", reply.path
    assert_equal "RecordingStudioMessages::MessageGroup", reply.recordable_type
    assert_equal :edit, reply.required_role
    assert_equal "Reply", reply.openapi.fetch(:summary)
    assert_nil reply.openapi[:tag]
    assert_includes reply.openapi.fetch(:description), "Reply"
    assert_equal %w[body references], reply.input_contract.as_json.fetch(:fields).keys.map(&:to_s)
    refute reply.input_contract.as_json.fetch(:reject_unknown)
    assert reply.scopes_recording?
    refute reply.owns_scoping?

    assert_equal "#{at}/conversations", listed.path
    assert_equal :get, listed.http_verb
    assert_nil listed.recordable_type
    refute listed.scopes_recording?
    assert_equal "#{at}/unread_count", counted.path
    assert_nil counted.recordable_type
    assert_nil RecordingStudioApi.registered_endpoint(:"#{at}_rename_conversation")
  end

  def test_press_center_preset_scopes_the_parent_and_takes_a_conversation_id
    at = unique_at
    RecordingStudioMessages::Api.place(
      api: :public,
      at:,
      mount: { recordable_type: "Mailbox", key: :inbox },
      preset: :press_center
    )

    listed = RecordingStudioApi.registered_endpoint(:"#{at}_list_conversations")
    started = RecordingStudioApi.registered_endpoint(:"#{at}_start_conversation")
    read = RecordingStudioApi.registered_endpoint(:"#{at}_read_messages")
    renamed = RecordingStudioApi.registered_endpoint(:"#{at}_rename_conversation")

    marked = RecordingStudioApi.registered_endpoint(:"#{at}_mark_read")
    counted = RecordingStudioApi.registered_endpoint(:"#{at}_unread_count")

    assert_equal "#{at}/:id/conversations", listed.path
    assert_equal "Mailbox", listed.recordable_type
    assert_equal :view, listed.required_role
    assert_equal ["Press Center Messages"], listed.openapi_tags
    assert_equal({ group: "Press Center" }, listed.openapi[:tag])
    assert_equal "List conversations", listed.openapi.fetch(:title)
    assert_equal ["Press Center Messages"], marked.openapi_tags
    assert_equal "Mark conversation read", marked.openapi.fetch(:title)
    assert_equal ["Press Center Messages"], counted.openapi_tags
    assert_equal "Count unread conversations", counted.openapi.fetch(:title)
    assert_equal :post, started.http_verb
    assert_equal "#{at}/:id/conversations", started.path
    assert_equal "#{at}/:id/messages", read.path
    assert_equal ["conversation_id"], read.input_contract.as_json.fetch(:fields).keys.map(&:to_s)
    assert_equal "#{at}/:id/rename_group", renamed.path
    assert_includes renamed.input_contract.as_json.fetch(:fields).keys.map(&:to_s), "conversation_id"
    assert_includes renamed.input_contract.as_json.fetch(:fields).keys.map(&:to_s), "title"
  end

  def test_default_placement_uses_the_message_center_group_and_action_titles
    at = unique_at
    RecordingStudioMessages::Api.place(
      api: :public,
      at:,
      mount: -> {},
      actions: %i[mark_read unread_count]
    )

    marked = RecordingStudioApi.registered_endpoint(:"#{at}_mark_read")
    counted = RecordingStudioApi.registered_endpoint(:"#{at}_unread_count")

    assert_equal ["Message Center"], marked.openapi_tags
    assert_equal "Mark conversation read", marked.openapi.fetch(:title)
    assert_equal ["Message Center"], counted.openapi_tags
    assert_equal "Count unread conversations", counted.openapi.fetch(:title)
  end

  def test_explicit_tags_replace_the_press_center_group
    at = unique_at
    RecordingStudioMessages::Api.place(
      api: :public,
      at:,
      mount: { recordable_type: "Mailbox", key: :inbox },
      preset: :press_center,
      tags: ["Desk"]
    )

    listed = RecordingStudioApi.registered_endpoint(:"#{at}_list_conversations")
    marked = RecordingStudioApi.registered_endpoint(:"#{at}_mark_read")

    assert_equal ["Desk"], listed.openapi_tags
    assert_equal ["Desk"], marked.openapi_tags
    assert_nil listed.openapi[:tag]
    assert_equal "Mark conversation read", marked.openapi.fetch(:title)
  end

  def test_host_can_filter_actions_and_override_names_descriptions_and_tags
    at = unique_at
    RecordingStudioMessages::Api.place(
      api: :public,
      at:,
      mount: -> {},
      preset: :support,
      actions: %i[list_conversations unread_count],
      names: { list_conversations: :"#{at}_requests" },
      descriptions: { unread_count: "How many requests are still unread." },
      tags: ["Help"]
    )

    listed = RecordingStudioApi.registered_endpoint(:"#{at}_requests")
    counted = RecordingStudioApi.registered_endpoint(:"#{at}_unread_count")

    assert_equal ["Help"], listed.openapi_tags
    assert_equal "List my requests", listed.openapi.fetch(:title)
    assert_equal "How many requests are still unread.", counted.openapi.fetch(:description)
    assert_nil RecordingStudioApi.registered_endpoint(:"#{at}_reply")
    assert_nil RecordingStudioApi.registered_endpoint(:"#{at}_list_requests")
  end

  def test_at_cannot_be_a_recordable_resource_name
    at = unique_at
    RecordingStudioApi.stub(:recordable_type_for_resource, "Mailbox") do
      error = assert_raises(RecordingStudioApi::ConfigurationError) do
        RecordingStudioMessages::Api.place(api: :public, at:, mount: :support, actions: %i[list_conversations])
      end
      assert_includes error.message, "API resource for Mailbox"
    end
    assert_nil RecordingStudioApi.registered_endpoint(:"#{at}_list_conversations")
  end

  def test_unknown_actions_reserved_names_and_collisions_raise
    at = unique_at
    error = assert_raises(RecordingStudioApi::ConfigurationError) do
      RecordingStudioMessages::Api.place(api: :public, at:, mount: :support, actions: %i[explode])
    end
    assert_includes error.message, "Unknown messages API actions: explode"
    assert_nil RecordingStudioApi.registered_endpoint(:"#{at}_explode")

    reserved = assert_raises(RecordingStudioApi::ConfigurationError) do
      RecordingStudioMessages::Api.place(
        api: :public, at: "#{at}r", mount: :support,
        actions: %i[list_conversations], names: { list_conversations: :list }
      )
    end
    assert_includes reserved.message, "reserved"

    RecordingStudioMessages::Api.place(
      api: :public, at: "#{at}a", mount: :support, actions: %i[list_conversations],
      names: { list_conversations: :"#{at}_shared" }
    )
    collision = assert_raises(RecordingStudioApi::ConfigurationError) do
      RecordingStudioMessages::Api.place(
        api: :public, at: "#{at}b", mount: :support, actions: %i[unread_count],
        names: { unread_count: :"#{at}_shared" }
      )
    end
    assert_includes collision.message, "already registered"

    RecordingStudioMessages::Api.place(api: :public, at: "#{at}c", mount: :support, preset: :support)
    path_collision = assert_raises(RecordingStudioApi::ConfigurationError) do
      RecordingStudioMessages::Api.place(
        api: :public, at: "#{at}c", mount: :support, actions: %i[list_conversations],
        names: { list_conversations: :"#{at}_other_list" }
      )
    end
    assert_includes path_collision.message, "already registered"

    preset = assert_raises(RecordingStudioApi::ConfigurationError) do
      RecordingStudioMessages::Api.place(api: :public, at: "#{at}d", mount: :support, preset: :nope)
    end
    assert_includes preset.message, "Unknown messages API preset"
  end

  def test_target_recordable_fields
    group = Struct.new(:title).new("Message center thread")
    mount = Struct.new(:key).new("support")
    message = Struct.new(:body).new("Hello from the message center.")
    group_recording = Struct.new(:recordable, :recordable_type).new(group, RecordingStudioMessages::MESSAGE_GROUP_TYPE)
    mount_recording = Struct.new(:recordable, :recordable_type).new(mount, RecordingStudioMessages::MESSAGE_MOUNT_TYPE)
    message_recording = Struct.new(:recordable, :recordable_type).new(message, RecordingStudioMessages::MESSAGE_TYPE)

    assert_equal({ title: "Message center thread" }, RecordingStudioMessages::Api::Target.recordable_fields(group_recording))
    assert_equal({ key: "support" }, RecordingStudioMessages::Api::Target.recordable_fields(mount_recording))
    assert_equal({ body: "Hello from the message center." }, RecordingStudioMessages::Api::Target.recordable_fields(message_recording))
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

    assert_raises(ArgumentError) do
      RecordingStudioMessages::Api::Errors.wrap { Integer("nope") }
    end
  end

  def test_my_messages_preset_uses_fixed_names_and_rejects_a_mount
    RecordingStudioMessages::Api.place(api: :public, at: :my_messages, preset: :my_messages)
    RecordingStudioMessages::Api.place(api: :public, at: :my_messages, preset: :my_messages)

    listed = RecordingStudioApi.registered_endpoint(:list_my_messages)
    read = RecordingStudioApi.registered_endpoint(:read_my_messages)
    sent = RecordingStudioApi.registered_endpoint(:send_my_message)
    marked = RecordingStudioApi.registered_endpoint(:mark_my_message_read)
    counted = RecordingStudioApi.registered_endpoint(:count_unread_my_messages)

    assert_equal "my_messages/conversations", listed.path
    assert_equal :get, listed.http_verb
    assert_equal :view, listed.required_role
    assert_nil listed.recordable_type
    assert_equal ["My Messages"], listed.openapi_tags
    assert_equal({ group: "My Messages" }, listed.openapi[:tag])
    assert_equal "List my messages", listed.openapi.fetch(:title)
    assert_includes listed.openapi.fetch(:description), "Needs view access"

    assert_equal "my_messages/conversations/:id/messages", read.path
    assert_equal RecordingStudioMessages::MESSAGE_GROUP_TYPE, read.recordable_type
    assert_equal :view, read.required_role
    assert_equal "my_messages/conversations/:id/send_message", sent.path
    assert_equal :edit, sent.required_role
    assert_equal "my_messages/conversations/:id/mark_read", marked.path
    assert_equal :view, marked.required_role
    assert_equal "my_messages/unread_count", counted.path
    assert_nil counted.recordable_type
    assert_equal :view, counted.required_role

    mount = assert_raises(RecordingStudioApi::ConfigurationError) do
      RecordingStudioMessages::Api.place(
        api: :public, at: :my_messages, mount: :support, preset: :my_messages
      )
    end
    assert_includes mount.message, "does not take a mount"

    missing = assert_raises(RecordingStudioApi::ConfigurationError) do
      RecordingStudioMessages::Api.place(api: :public, at: unique_at, preset: :support)
    end
    assert_includes missing.message, "mount is required"

    foreign = assert_raises(RecordingStudioApi::ConfigurationError) do
      RecordingStudioMessages::Api.place(
        api: :public, at: unique_at, preset: :my_messages, actions: %i[list_conversations]
      )
    end
    assert_includes foreign.message, "list_conversations"
  end

  private

  def place_support(at)
    RecordingStudioMessages::Api.place(api: :public, at:, mount: -> {}, preset: :support)
  end

  def unique_at
    "t#{SecureRandom.hex(4)}"
  end
end
