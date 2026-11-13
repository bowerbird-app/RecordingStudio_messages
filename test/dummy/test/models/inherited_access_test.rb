# frozen_string_literal: true

require "test_helper"

class InheritedAccessTest < ActiveSupport::TestCase
  setup do
    @previous_actor = Current.actor
    @owner = User.create!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Owner"
    )
    @editor = User.create!(
      email: "editor-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Editor"
    )
    @viewer = User.create!(
      email: "viewer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Viewer"
    )
    @stranger = User.create!(
      email: "stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Stranger"
    )
    Current.actor = @owner

    @workspace = Workspace.create!(name: "Inherited #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @owner)
    raise result.error if result.failure?

    mailbox = Mailbox.create!(name: "Inherited mailbox #{SecureRandom.hex(4)}")
    mailbox_recording = RecordingStudio.record!(
      action: "created",
      recordable: mailbox,
      root_recording: @root,
      parent_recording: @root,
      actor: @owner
    ).recording
    @mount = mailbox_recording.ensure_message_mount("inbox", actor: @owner)
    @members_mount = @root.ensure_message_mount("support", actor: @owner)

    grant_root!(@editor, :edit)
    grant_root!(@viewer, :view)
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "inherited create_group writes no direct grants" do
    group = RecordingStudioMessages.create_group(@mount, title: "Quiet thread", actor: @owner)

    assert_equal [], RecordingStudioMessages.granted_actors(group)
    assert RecordingStudioAccessible.authorized?(actor: @owner, recording: group, role: :admin)
    refute RecordingStudioAccessible.authorized?(actor: @stranger, recording: group, role: :view)
  end

  test "inherited create_group ignores admin:" do
    group = RecordingStudioMessages.create_group(
      @mount, title: "No staff grant", actor: @owner, admin: @editor
    )

    assert_equal [], RecordingStudioMessages.granted_actors(group)
  end

  test "members create_group still grants the creator, or admin: when passed" do
    created = RecordingStudioMessages.create_group(@members_mount, title: "Members thread", actor: @owner)
    assert_includes RecordingStudioMessages.granted_actors(created).map(&:id), @owner.id

    passed = RecordingStudioMessages.create_group(
      @members_mount, title: "Passed admin", actor: @owner, admin: @editor
    )
    granted_ids = RecordingStudioMessages.granted_actors(passed).map(&:id)
    assert_includes granted_ids, @editor.id
    refute_includes granted_ids, @owner.id
  end

  test "inherited team member with view reads and cannot reply" do
    group = RecordingStudioMessages.create_group(@mount, title: "Read only", actor: @owner)

    assert RecordingStudioAccessible.authorized?(actor: @viewer, recording: group, role: :view)
    refute RecordingStudioAccessible.authorized?(actor: @viewer, recording: group, role: :edit)

    error = assert_raises(RecordingStudioMessages::NotAuthorized) do
      RecordingStudioMessages.send_message(group_recording: group, body: "Nope", actor: @viewer, notify: false)
    end
    assert_equal RecordingStudioMessages::Copy.t("errors.cannot_send_conversation"), error.message
    refute_includes listed_titles(actor: @viewer), "Read only"
  end

  test "inherited team member with edit replies and stays off my messages" do
    group = RecordingStudioMessages.create_group(@mount, title: "Team reply", actor: @owner)

    assert RecordingStudioAccessible.authorized?(actor: @editor, recording: group, role: :edit)
    message = RecordingStudioMessages.send_message(
      group_recording: group, body: "On it.", actor: @editor, notify: false
    )

    assert_equal "On it.", message.recordable.body
    assert_includes titles(viewable(actor: @editor)), "Team reply"
    refute_includes listed_titles(actor: @editor), "Team reply"
    refute_includes listed_titles(actor: @owner), "Team reply"
  end

  test "unknown access mode is rejected at the mount" do
    RecordingStudio.set_capability_options(
      :messages,
      on: Mailbox,
      keys: [:inbox],
      public_contact: [:inbox],
      access: :party,
      contacts: DummyCatalog::CONTACTS
    )

    error = assert_raises(RecordingStudioMessages::Error) do
      RecordingStudioMessages::MountAccess.mode(@mount)
    end
    assert_equal "Messages access must be :members or :inherited", error.message
  ensure
    RecordingStudio.set_capability_options(
      :messages,
      on: Mailbox,
      keys: [:inbox],
      public_contact: [:inbox],
      access: :inherited,
      contacts: DummyCatalog::CONTACTS
    )
  end

  test "inherited send notifies actors granted only on the mount or root and skips the sender" do
    mount_only = User.create!(
      email: "mount-only-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Mount Only"
    )
    RecordingStudio.enable_capability(:accessible, on: RecordingStudioMessages::MessageMount)
    grant_recording!(@mount, mount_only, :edit)
    grant_recording!(@mount, @editor, :view)
    group = RecordingStudioMessages.create_group(@mount, title: "Inherited notice", actor: @owner)

    assert_equal [], RecordingStudioMessages.granted_actors(group)

    RecordingStudioMessages.send_message(
      group_recording: group, body: "The team should hear this.", actor: @owner
    )

    assert_notified mount_only
    assert_notified @editor
    assert_equal 1, message_received_count(@editor)
    assert_notified @viewer
    refute_notified @owner
    refute_notified @stranger
  end

  test "members send still notifies only direct grants" do
    group = RecordingStudioMessages.create_group(@members_mount, title: "Members notice", actor: @owner)
    customer = User.create!(
      email: "member-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Member"
    )
    grant_group!(group, customer, :edit)

    RecordingStudioMessages.send_message(
      group_recording: group, body: "Direct grants only.", actor: @owner
    )

    assert_notified customer
    refute_notified @editor
    refute_notified @viewer
    refute_notified @owner
  end

  test "explicit recipients still win on an inherited mount" do
    group = RecordingStudioMessages.create_group(@mount, title: "Resolver list", actor: @owner)
    message = RecordingStudioMessages.send_message(
      group_recording: group, body: "Held.", actor: @owner, notify: false
    )

    RecordingStudioMessages::Services::NotifyGrantedActors.call(
      group_recording: group,
      message_recording: message,
      actor: @owner,
      body: "Held.",
      url: "/inbox",
      recipients: [@editor]
    )

    assert_notified @editor
    refute_notified @viewer
    refute_notified @owner
  end

  test "explicit panel grant still appears in my messages" do
    group = RecordingStudioMessages.create_group(@mount, title: "Invited", actor: @owner)
    grant_group!(group, @editor, :edit)

    assert_includes listed_titles(actor: @editor), "Invited"
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

  def grant_group!(group, actor, role)
    grant_recording!(group, actor, role)
  end

  def grant_recording!(recording, actor, role)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: role,
      manager_actor: @owner
    )
    raise result.error if result.failure?
  end

  def assert_notified(actor)
    assert message_received_for(actor), "#{actor.name} should be notified"
  end

  def refute_notified(actor)
    assert_nil message_received_for(actor), "#{actor.name} should not be notified"
  end

  def message_received_for(actor)
    RecordingStudioNotifications::Notification.find_by(
      notification_type: "message_received",
      recipient: actor
    )
  end

  def message_received_count(actor)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received",
      recipient: actor
    ).count
  end

  def viewable(actor:)
    RecordingStudioMessages.viewable_group_recordings(actor: actor, mount_recording: @mount)
  end

  def listed_titles(actor:)
    titles(RecordingStudioMessages.my_group_recordings(actor: actor))
  end

  def titles(recordings)
    recordings.map { |recording| recording.recordable.title }
  end
end
