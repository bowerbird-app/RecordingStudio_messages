# frozen_string_literal: true

require "test_helper"

class ListGroupsTest < ActiveSupport::TestCase
  setup do
    @previous_actor = Current.actor
    @owner = User.create!(
      email: "owner-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Owner"
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

    @mount = support_mount("List")
    @other_mount = support_mount("Other")

    @alpha = RecordingStudioMessages.create_group(@mount, title: "Alpha", actor: @owner)
    RecordingStudioMessages.create_group(@mount, title: "No grant", actor: @owner)
    elsewhere = RecordingStudioMessages.create_group(@other_mount, title: "Other desk", actor: @owner)
    grant!(@alpha, @viewer)
    grant!(elsewhere, @viewer)
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "a granted actor sees conversations on that mount" do
    recordings = listed(actor: @viewer, mount_recording: @mount)
    from_service = RecordingStudioMessages::Services::ListGroups.call(actor: @viewer, mount_recording: @mount)

    assert_equal recordings.map(&:id), from_service.map(&:id)
    assert_equal [ "Alpha" ], titles(recordings)
  end

  test "a stranger with no grant gets an empty list" do
    assert_equal [], titles(listed(actor: @stranger, mount_recording: @mount))
  end

  test "a blank actor gets an empty list" do
    assert_equal [], RecordingStudioMessages.viewable_group_recordings(actor: nil, mount_recording: @mount)
  end

  test "a blank mount gets an empty list" do
    assert_equal [], RecordingStudioMessages.viewable_group_recordings(actor: @viewer, mount_recording: nil)
    assert_equal [], RecordingStudioMessages::Services::ListGroups.call(actor: @viewer, mount_recording: nil)
  end

  test "later message activity sorts ahead of title" do
    bravo = RecordingStudioMessages.create_group(@mount, title: "Bravo", actor: @owner)
    zebra = RecordingStudioMessages.create_group(@mount, title: "Zebra", actor: @owner)
    grant!(bravo, @viewer)
    grant!(zebra, @viewer)

    stamp = Time.zone.parse("2026-06-01 12:00:00")
    @alpha.update!(created_at: stamp, updated_at: stamp)
    bravo.update!(created_at: stamp, updated_at: stamp)
    message = RecordingStudioMessages.send_message(
      group_recording: zebra,
      body: "A later line",
      actor: @owner,
      notify: false
    )
    message.update!(created_at: stamp + 2.hours, updated_at: stamp + 2.hours)

    assert_equal [ "Zebra", "Alpha", "Bravo" ], titles(listed(actor: @viewer, mount_recording: @mount))
  end

  test "a trashed conversation stays off the list" do
    filed = RecordingStudioMessages.create_group(@mount, title: "Filed away", actor: @owner)
    grant!(filed, @viewer)
    filed.update!(trashed_at: Time.current)

    assert_equal [ "Alpha" ], titles(listed(actor: @viewer, mount_recording: @mount))
  end

  private

  def support_mount(prefix)
    workspace = Workspace.create!(name: "#{prefix} #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @owner)
    raise result.error if result.failure?

    root.ensure_message_mount("support", actor: @owner)
  end

  def grant!(recording, actor)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :view,
      manager_actor: @owner
    )
    raise result.error if result.failure?
  end

  def listed(actor:, mount_recording:)
    RecordingStudioMessages.viewable_group_recordings(actor: actor, mount_recording: mount_recording)
  end

  def titles(recordings)
    recordings.map { |recording| recording.recordable.title }
  end
end
