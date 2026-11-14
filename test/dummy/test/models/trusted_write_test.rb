# frozen_string_literal: true

require "test_helper"

class TrustedWriteTest < ActiveSupport::TestCase
  setup do
    @previous_actor = Current.actor
    @owner = User.create!(
      email: "trusted-owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Owner"
    )
    @editor = User.create!(
      email: "trusted-editor-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Editor"
    )
    @viewer = User.create!(
      email: "trusted-viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Viewer"
    )
    Current.actor = @owner
    @workspace = Workspace.create!(name: "Trusted #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    raise result.error if result.failure?

    @mount = @root.ensure_message_mount("support", actor: @owner)
    grant_root!(@editor, :edit)
    grant_root!(@viewer, :view)
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "create_group marks only the conversation write" do
    assert_nil RecordingStudioMessages.trusted_write_context
    captures = []

    group = with_write_policy(captures) do
      RecordingStudioMessages.create_group(@mount, title: "Desk notes", actor: @owner)
    end

    marked = message_writes(captures)
    assert_equal [["RecordingStudioMessages::MessageGroup", "created", :create_group, @mount]], marked
    assert_equal "Desk notes", group.recordable.title
    assert_nil RecordingStudioMessages.trusted_write_context
  end

  test "starting a conversation marks the group write and the first message separately" do
    captures = []

    with_write_policy(captures) do
      RecordingStudioMessages.create_group(
        @mount,
        actor: @owner,
        recipients: [@editor],
        body: "Can you look at this?"
      )
    end

    assert_equal [
      ["RecordingStudioMessages::MessageGroup", "created", :create_group],
      ["RecordingStudioMessages::Message", "created", :send_message]
    ], message_writes(captures).map { |type, write_action, action, _mount| [type, write_action, action] }
    message_writes(captures).each do |_type, _write_action, _action, mount|
      assert_equal @mount, mount
    end
    assert_nil RecordingStudioMessages.trusted_write_context
  end

  test "send_message marks the line and the conversation stamp" do
    group = RecordingStudioMessages.create_group(@mount, title: "Open thread", actor: @owner)
    captures = []
    stamped = []

    with_write_policy(captures) do
      subscribe_to_stamp(stamped) do
        RecordingStudioMessages.send_message(
          group_recording: group,
          body: "Hello",
          actor: @owner
        )
      end
    end

    assert_equal [["RecordingStudioMessages::Message", "created", :send_message, @mount]], message_writes(captures)
    assert_equal [:send_message], stamped.map { |context| context.action }
    assert_equal [@mount], stamped.map { |context| context.mount_recording }
    assert_predicate stamped.first, :frozen?
    assert_nil RecordingStudioMessages.trusted_write_context
    assert_equal group.reload.recordable.last_message_at, RecordingStudioMessages.message_recordings(group).last.created_at
  end

  test "rename_group marks the revise after the edit check" do
    group = RecordingStudioMessages.create_group(@mount, title: "Old name", actor: @owner)
    captures = []

    with_write_policy(captures) do
      RecordingStudioMessages.rename_group(group_recording: group, title: "New name", actor: @editor)
    end

    assert_equal [["RecordingStudioMessages::MessageGroup", "updated", :rename_group, @mount]], message_writes(captures)
    assert_nil RecordingStudioMessages.trusted_write_context
  end

  test "a failed rename check does not set the context" do
    group = RecordingStudioMessages.create_group(@mount, title: "Stay", actor: @owner)
    captures = []

    assert_nil RecordingStudioMessages.trusted_write_context
    with_write_policy(captures) do
      assert_raises(RecordingStudioMessages::NotAuthorized) do
        RecordingStudioMessages.rename_group(group_recording: group, title: "Nope", actor: @viewer)
      end
    end

    assert_empty message_writes(captures)
    assert_equal "Stay", group.reload.recordable.title
    assert_nil RecordingStudioMessages.trusted_write_context
  end

  test "a failed send check does not set the context" do
    group = RecordingStudioMessages.create_group(@mount, title: "Quiet", actor: @owner)
    captures = []

    with_write_policy(captures) do
      assert_raises(RecordingStudioMessages::NotAuthorized) do
        RecordingStudioMessages.send_message(group_recording: group, body: "Nope", actor: @viewer)
      end
    end

    assert_empty message_writes(captures)
    assert_nil RecordingStudioMessages.trusted_write_context
  end

  test "create_group does not set the context when the mount check fails" do
    captures = []

    with_write_policy(captures) do
      error = assert_raises(RecordingStudioMessages::Error) do
        RecordingStudioMessages.create_group(@root, title: "Nope", actor: @owner)
      end
      assert_equal "Groups must be created under a message mount", error.message
    end

    assert_empty message_writes(captures)
    assert_nil RecordingStudioMessages.trusted_write_context
  end

  test "a raised message write restores a nil context" do
    group = RecordingStudioMessages.create_group(@mount, title: "Boom", actor: @owner)
    during = nil
    config = RecordingStudio.configuration
    previous_authorizer = config.authorize_write
    previous_allow = config.allow_unauthorized_writes
    config.allow_unauthorized_writes = false
    config.authorize_write = lambda do |recordable:, **|
      next true unless recordable.is_a?(RecordingStudioMessages::Message)

      during = RecordingStudioMessages.trusted_write_context
      raise "write failed"
    end

    assert_raises(RuntimeError) do
      RecordingStudioMessages.send_message(group_recording: group, body: "Hello", actor: @owner)
    end

    assert_equal :send_message, during.action
    assert_equal @mount, during.mount_recording
    assert_nil RecordingStudioMessages.trusted_write_context
  ensure
    config.allow_unauthorized_writes = previous_allow
    config.authorize_write = previous_authorizer
  end

  test "ensure_mount does not set the trusted write context" do
    captures = []

    with_write_policy(captures) do
      fresh = Workspace.create!(name: "Mount #{SecureRandom.hex(4)}")
      root = RecordingStudio.root_recording_for(fresh)
      result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @owner)
      raise result.error if result.failure?

      root.ensure_message_mount("support", actor: @owner)
    end

    mounts = captures.select { |row| row[:type] == "RecordingStudioMessages::MessageMount" }
    assert_equal 1, mounts.size
    assert_nil mounts.first[:context]
    assert_nil RecordingStudioMessages.trusted_write_context
  end

  private

  def grant_root!(actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: @root,
      actor: actor,
      role: role,
      manager_actor: @owner
    )
    raise result.error if result.failure?
  end

  def with_write_policy(captures)
    config = RecordingStudio.configuration
    previous_authorizer = config.authorize_write
    previous_allow = config.allow_unauthorized_writes
    config.allow_unauthorized_writes = false
    config.authorize_write = lambda do |recordable:, action:, **|
      context = RecordingStudioMessages.trusted_write_context
      captures << {
        type: recordable.class.name,
        write_action: action,
        context_action: context&.action,
        mount: context&.mount_recording,
        context: context
      }
      true
    end
    yield
  ensure
    config.allow_unauthorized_writes = previous_allow
    config.authorize_write = previous_authorizer
  end

  def message_writes(captures)
    captures.filter_map do |row|
      next unless row[:type].start_with?("RecordingStudioMessages::Message")

      [row[:type], row[:write_action], row[:context_action], row[:mount]]
    end
  end

  def subscribe_to_stamp(stamped)
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql].to_s
      next unless sql.match?(/\AUPDATE/i) && sql.include?("last_message_at")

      stamped << RecordingStudioMessages.trusted_write_context
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
  end
end
