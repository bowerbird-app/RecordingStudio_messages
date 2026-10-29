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

  test "create_group with tags writes rows and tagged_group_recordings finds them" do
    group = RecordingStudioMessages.create_group(
      @mount,
      title: "Center desk",
      actor: @owner,
      tags: { "press_center" => @press_center, "press_kit" => @press_kit }
    )
    again = RecordingStudioMessages.create_group(
      @mount,
      title: "Second desk",
      actor: @owner,
      tags: { "press_center" => @press_center, "press_kit" => @press_kit }
    )

    rows = RecordingStudioMessages::MessageGroupTag.where(message_group_recording_id: group.id)
    assert_equal 2, rows.count
    assert_equal @press_center.id, rows.find_by!(key: "press_center").tagged_recording_id
    assert_equal @press_kit.id, rows.find_by!(key: "press_kit").tagged_recording_id

    found = RecordingStudioMessages.tagged_group_recordings(
      mount_recording: @mount,
      tags: { "press_center" => @press_center, "press_kit" => @press_kit }
    )
    assert_kind_of ActiveRecord::Relation, found
    assert_equal [group.id, again.id].sort, found.map(&:id).sort
  end

  test "create_group without tags writes no tag rows" do
    plain = RecordingStudioMessages.create_group(@mount, title: "Plain", actor: @owner)
    empty = RecordingStudioMessages.create_group(@mount, title: "Empty", actor: @owner, tags: {})

    assert_equal 0, RecordingStudioMessages::MessageGroupTag.where(message_group_recording_id: plain.id).count
    assert_equal 0, RecordingStudioMessages::MessageGroupTag.where(message_group_recording_id: empty.id).count
  end

  test "create_group rejects a repeated key and tags that are not recordings" do
    groups_before = RecordingStudioMessages::MessageGroup.count

    repeated = assert_raises(ArgumentError) do
      RecordingStudioMessages.create_group(
        @mount,
        title: "Clash",
        actor: @owner,
        tags: { press_center: @press_center, "press_center" => @press_kit }
      )
    end
    assert_equal "tag key is repeated", repeated.message

    assert_raises(ArgumentError) do
      RecordingStudioMessages.create_group(@mount, title: "Bad", actor: @owner, tags: "press_center")
    end
    assert_raises(ArgumentError) do
      RecordingStudioMessages.create_group(
        @mount, title: "Bad", actor: @owner, tags: { "press_center" => "nope" }
      )
    end

    assert_equal groups_before, RecordingStudioMessages::MessageGroup.count
  end

  test "the same normalized key and recording writes one tag row" do
    group = RecordingStudioMessages.create_group(
      @mount,
      title: "Once",
      actor: @owner,
      tags: { press_center: @press_center, "press_center" => @press_center }
    )

    rows = RecordingStudioMessages::MessageGroupTag.where(message_group_recording_id: group.id)
    assert_equal ["press_center"], rows.map(&:key)
    assert_equal @press_center.id, rows.first.tagged_recording_id
  end

  test "tagged_group_recordings requires a mount and rejects a non-mount" do
    assert_raises(ArgumentError) do
      RecordingStudioMessages.tagged_group_recordings(mount_recording: nil, tags: {})
    end

    error = assert_raises(RecordingStudioMessages::Error) do
      RecordingStudioMessages.tagged_group_recordings(mount_recording: @press_center, tags: {})
    end
    assert_equal "mount recording must be a message mount", error.message
  end

  test "tagged_group_recordings ignores grants and excludes other mounts, trash, and partial tags" do
    both = RecordingStudioMessages.create_group(
      @mount,
      title: "Both",
      actor: @owner,
      tags: { "press_center" => @press_center, "press_kit" => @press_kit }
    )
    center = RecordingStudioMessages.create_group(
      @mount,
      title: "Center only",
      actor: @owner,
      tags: { "press_center" => @press_center }
    )
    other_mount = support_mount("Elsewhere")
    elsewhere = RecordingStudioMessages.create_group(
      other_mount,
      title: "Elsewhere",
      actor: @owner,
      tags: { "press_center" => @press_center, "press_kit" => @press_kit }
    )
    trashed = RecordingStudioMessages.create_group(
      @mount,
      title: "Gone",
      actor: @owner,
      tags: { "press_center" => @press_center, "press_kit" => @press_kit }
    )
    trashed.update!(trashed_at: Time.current)

    Current.actor = @stranger
    found = RecordingStudioMessages.tagged_group_recordings(
      mount_recording: @mount,
      tags: { "press_center" => @press_center, "press_kit" => @press_kit }
    )

    assert_equal [both.id], found.map(&:id)
    refute_includes found.map(&:id), center.id
    refute_includes found.map(&:id), elsewhere.id
    refute_includes found.map(&:id), trashed.id
    refute_includes found.map(&:id), @alpha.id
  end

  test "empty tags on tagged_group_recordings return every kept group on the mount" do
    other_mount = support_mount("Elsewhere")
    elsewhere = RecordingStudioMessages.create_group(other_mount, title: "Elsewhere", actor: @owner)
    trashed = RecordingStudioMessages.create_group(@mount, title: "Gone", actor: @owner)
    trashed.update!(trashed_at: Time.current)

    found = RecordingStudioMessages.tagged_group_recordings(mount_recording: @mount, tags: {})
    unfiltered = RecordingStudioMessages.tagged_group_recordings(mount_recording: @mount, tags: nil)

    assert_equal [@alpha.id, @bravo.id].sort, found.map(&:id).sort
    assert_equal found.map(&:id).sort, unfiltered.map(&:id).sort
    refute_includes found.map(&:id), elsewhere.id
    refute_includes found.map(&:id), trashed.id
  end

  test "a failed owner grant leaves no conversation and no tag rows" do
    configuration = RecordingStudioAccessible.configuration
    previous = configuration.access_actor_types
    configuration.access_actor_types = ["Agent"]
    groups_before = RecordingStudioMessages::MessageGroup.count
    tags_before = RecordingStudioMessages::MessageGroupTag.count

    error = assert_raises(RecordingStudioMessages::Error) do
      RecordingStudioMessages.create_group(
        @mount,
        title: "Rolled back",
        actor: @owner,
        tags: { "press_center" => @press_center }
      )
    end

    assert_equal "Actor type is not allowed for access", error.message
    assert_equal groups_before, RecordingStudioMessages::MessageGroup.count
    assert_equal tags_before, RecordingStudioMessages::MessageGroupTag.count
    refute RecordingStudioMessages::MessageGroup.exists?(title: "Rolled back")
  ensure
    configuration.access_actor_types = previous
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
