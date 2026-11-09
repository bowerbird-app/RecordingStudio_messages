# frozen_string_literal: true

require "test_helper"

class MyGroupRecordingsTest < ActiveSupport::TestCase
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
    @heir = User.create!(
      email: "heir-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Heir"
    )
    Current.actor = @owner

    @mount = support_mount("Inbox")
    @other_mount = support_mount("Press")
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "direct grants across mounts appear and inherited-only access does not" do
    here = RecordingStudioMessages.create_group(@mount, title: "Here", actor: @owner)
    there = RecordingStudioMessages.create_group(@other_mount, title: "There", actor: @owner)
    hidden = RecordingStudioMessages.create_group(@mount, title: "Inherited only", actor: @owner)
    grant!(here, @viewer)
    grant!(there, @viewer)
    grant_root!(@heir, @mount.root_recording)

    inbox = titles(listed(actor: @viewer))
    heir_inbox = titles(listed(actor: @heir))
    mount_list = titles(
      RecordingStudioMessages.viewable_group_recordings(actor: @heir, mount_recording: @mount)
    )

    assert_equal [ "There", "Here" ].sort, inbox.sort
    assert_empty heir_inbox
    assert_includes mount_list, "Inherited only"
    assert_includes mount_list, "Here"
    refute_kind_of Array, listed(actor: @viewer)
  end

  test "trashed grants, trashed groups, and ineffective depends_on grants stay out" do
    kept = RecordingStudioMessages.create_group(@mount, title: "Kept", actor: @owner)
    trashed_group = RecordingStudioMessages.create_group(@mount, title: "Trashed group", actor: @owner)
    trashed_grant = RecordingStudioMessages.create_group(@mount, title: "Trashed grant", actor: @owner)
    dependent = RecordingStudioMessages.create_group(@mount, title: "Dependent", actor: @owner)
    grant!(kept, @viewer)
    grant!(trashed_group, @viewer)
    grant!(trashed_grant, @viewer)
    manager = RecordingStudioAccessible.access_recordings_for_actor(
      recording: dependent,
      actor: @owner
    ).first
    grant!(dependent, @viewer, depends_on: manager)

    trashed_group.update!(trashed_at: Time.current)
    access = RecordingStudioAccessible.access_recordings_for_actor(
      recording: trashed_grant,
      actor: @viewer
    ).first
    access.update!(trashed_at: Time.current)
    manager.update!(trashed_at: Time.current)

    assert_equal [ "Kept" ], titles(listed(actor: @viewer))
  end

  test "order follows last_message_at then recording id" do
    older = RecordingStudioMessages.create_group(@mount, title: "Older", actor: @owner)
    newer = RecordingStudioMessages.create_group(@other_mount, title: "Newer", actor: @owner)
    grant!(older, @viewer)
    grant!(newer, @viewer)

    first = RecordingStudioMessages.send_message(
      group_recording: older,
      body: "First line",
      actor: @owner,
      notify: false
    )
    second = RecordingStudioMessages.send_message(
      group_recording: newer,
      body: "Later line",
      actor: @owner,
      notify: false
    )
    stamp_last_message_at!(older, Time.zone.parse("2026-06-01 10:00:00"))
    stamp_last_message_at!(newer, Time.zone.parse("2026-06-01 12:00:00"))
    first.update!(created_at: Time.zone.parse("2026-06-01 10:00:00"))
    second.update!(created_at: Time.zone.parse("2026-06-01 12:00:00"))

    assert_equal [ "Newer", "Older" ], titles(listed(actor: @viewer))
  end

  test "keyset pagination walks last_message_at" do
    groups = Array.new(3) do |index|
      group = RecordingStudioMessages.create_group(@mount, title: "G#{index}", actor: @owner)
      grant!(group, @viewer)
      RecordingStudioMessages.send_message(
        group_recording: group,
        body: "Line #{index}",
        actor: @owner,
        notify: false
      )
      stamp_last_message_at!(group, Time.zone.parse("2026-06-01 12:0#{index}:00"))
      group
    end

    page = listed(actor: @viewer, limit: 2)
    rest = listed(actor: @viewer, limit: 2, after: page.last)

    assert_equal 2, page.length
    assert_equal [ "G2", "G1" ], titles(page)
    assert_equal [ "G0" ], titles(rest)
    assert page.is_a?(ActiveRecord::Relation)
    assert rest.is_a?(ActiveRecord::Relation)
  end

  test "send_message writes last_message_at and backfill fills a missing stamp" do
    group = RecordingStudioMessages.create_group(@mount, title: "Stamp", actor: @owner)
    grant!(group, @viewer)
    assert_nil group.recordable.last_message_at

    RecordingStudio.record!(
      action: "created",
      recordable: RecordingStudioMessages::Message.new(body: "Historic"),
      root_recording: group.root_recording,
      parent_recording: group,
      actor: @owner
    )
    RecordingStudioMessages::Services::MyGroupRecordings.backfill_last_message_at!
    group.recordable.reload
    historic_at = group.recordable.last_message_at
    assert_not_nil historic_at

    sent = RecordingStudioMessages.send_message(
      group_recording: group,
      body: "Fresh",
      actor: @owner,
      notify: false
    )
    group.recordable.reload
    assert_equal sent.created_at.to_i, group.recordable.last_message_at.to_i
    assert sent.created_at >= historic_at
  end

  test "a blank actor returns an empty relation" do
    relation = RecordingStudioMessages.my_group_recordings(actor: nil)

    assert_equal 0, relation.count
    assert relation.is_a?(ActiveRecord::Relation)
  end

  private

  def support_mount(prefix)
    workspace = Workspace.create!(name: "#{prefix} #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @owner)
    raise result.error if result.failure?

    root.ensure_message_mount("support", actor: @owner)
  end

  def grant!(recording, actor, depends_on: nil)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :view,
      manager_actor: @owner,
      depends_on: depends_on
    )
    raise result.error if result.failure?
  end

  def grant_root!(actor, root)
    result = RecordingStudioAccessible.grant_access(
      recording: root,
      actor: actor,
      role: :view,
      manager_actor: @owner
    )
    raise result.error if result.failure?
  end

  def stamp_last_message_at!(recording, time)
    RecordingStudioMessages::MessageGroup.unscoped.where(id: recording.recordable_id).update_all(
      last_message_at: time
    )
    recording.recordable.reload
  end

  def listed(actor:, after: nil, limit: nil)
    RecordingStudioMessages.my_group_recordings(actor: actor, after: after, limit: limit)
  end

  def titles(recordings)
    recordings.map { |recording| recording.recordable.title }
  end
end
