# frozen_string_literal: true

require "test_helper"

class MessageGroupTagsTest < ActiveSupport::TestCase
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

    @mount = support_mount("Tags")
    @press_center = host_recording("Press center")
    @press_kit = host_recording("Press kit")
    @other_center = host_recording("Other center")

    @alpha = RecordingStudioMessages.create_group(@mount, title: "Alpha", actor: @owner)
    @bravo = RecordingStudioMessages.create_group(@mount, title: "Bravo", actor: @owner)
    grant!(@alpha, @viewer)
    grant!(@bravo, @viewer)
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "one group can hold press_center and press_kit tags" do
    RecordingStudioMessages.tag(@alpha, key: "press_center", recording: @press_center)
    RecordingStudioMessages.tag(@alpha, key: "press_kit", recording: @press_kit)

    rows = RecordingStudioMessages::MessageGroupTag.where(message_group_recording_id: @alpha.id)
    assert_equal 2, rows.count
    assert_equal @press_center.id, rows.find_by!(key: "press_center").tagged_recording_id
    assert_equal @press_kit.id, rows.find_by!(key: "press_kit").tagged_recording_id
  end

  test "tag is idempotent for the same group key and recording" do
    first = RecordingStudioMessages.tag(@alpha, key: "press_center", recording: @press_center)
    second = RecordingStudioMessages.tag(@alpha, key: "press_center", recording: @press_center)

    assert_equal first.id, second.id
    assert_equal 1, RecordingStudioMessages::MessageGroupTag.where(
      message_group_recording_id: @alpha.id,
      key: "press_center"
    ).count
  end

  test "tag retargets the same key to another recording" do
    RecordingStudioMessages.tag(@alpha, key: "press_center", recording: @press_center)
    RecordingStudioMessages.tag(@alpha, key: "press_center", recording: @other_center)

    row = RecordingStudioMessages::MessageGroupTag.find_by!(
      message_group_recording_id: @alpha.id,
      key: "press_center"
    )
    assert_equal @other_center.id, row.tagged_recording_id
  end

  test "untag removes a key and can require the tagged recording" do
    RecordingStudioMessages.tag(@alpha, key: "press_center", recording: @press_center)
    RecordingStudioMessages.untag(@alpha, key: "press_center", recording: @other_center)
    assert_equal 1, RecordingStudioMessages::MessageGroupTag.where(message_group_recording_id: @alpha.id).count

    RecordingStudioMessages.untag(@alpha, key: "press_center", recording: @press_center)
    assert_equal 0, RecordingStudioMessages::MessageGroupTag.where(message_group_recording_id: @alpha.id).count
  end

  test "list filters by required tags under recordings_for" do
    RecordingStudioMessages.tag(@alpha, key: "press_center", recording: @press_center)
    RecordingStudioMessages.tag(@alpha, key: "press_kit", recording: @press_kit)
    RecordingStudioMessages.tag(@bravo, key: "press_center", recording: @press_center)

    both = titles(
      listed(tags: { "press_center" => @press_center, "press_kit" => @press_kit })
    )
    center_only = titles(listed(tags: { "press_center" => @press_center }))
    kit_only = titles(listed(tags: { "press_kit" => @press_kit }))
    other_center = titles(listed(tags: { "press_center" => @other_center }))

    assert_equal [ "Alpha" ], both
    assert_equal [ "Alpha", "Bravo" ], center_only.sort
    assert_equal [ "Alpha" ], kit_only
    assert_equal [], other_center
  end

  test "tags do not grant view to a stranger" do
    RecordingStudioMessages.tag(@alpha, key: "press_center", recording: @press_center)

    assert_equal [], titles(
      RecordingStudioMessages.viewable_group_recordings(
        actor: @stranger,
        mount_recording: @mount,
        tags: { "press_center" => @press_center }
      )
    )
  end

  test "a blank tags hash lists the same as no tags" do
    RecordingStudioMessages.tag(@alpha, key: "press_center", recording: @press_center)

    assert_equal titles(listed(tags: nil)).sort, titles(listed(tags: {})).sort
    assert_equal [ "Alpha", "Bravo" ], titles(listed(tags: {})).sort
  end

  test "tag rejects a blank key and a non-group recording" do
    assert_raises(ArgumentError) do
      RecordingStudioMessages.tag(@alpha, key: "  ", recording: @press_center)
    end
    assert_raises(RecordingStudioMessages::Error) do
      RecordingStudioMessages.tag(@mount, key: "press_center", recording: @press_center)
    end
  end

  private

  def support_mount(prefix)
    workspace = Workspace.create!(name: "#{prefix} #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @owner)
    raise result.error if result.failure?

    root.ensure_message_mount("support", actor: @owner)
  end

  def host_recording(name)
    workspace = Workspace.create!(name: "#{name} #{SecureRandom.hex(4)}")
    RecordingStudio.root_recording_for(workspace)
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

  def listed(tags:)
    RecordingStudioMessages.viewable_group_recordings(
      actor: @viewer,
      mount_recording: @mount,
      tags: tags
    )
  end

  def titles(recordings)
    recordings.map { |recording| recording.recordable.title }
  end
end
