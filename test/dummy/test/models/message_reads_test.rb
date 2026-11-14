# frozen_string_literal: true

require "test_helper"

class MessageReadsTest < ActiveSupport::TestCase
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
    @other = User.create!(
      email: "other-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Other"
    )
    Current.actor = @owner
    @mount = support_mount
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "another actor's send is unread for the recipient and not for the sender" do
    group = open_conversation("Ping")
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: "Hello from owner",
      actor: @owner,
      notify: false
    )

    assert RecordingStudioMessages.unread?(group_recording: group, actor: @viewer)
    refute RecordingStudioMessages.unread?(group_recording: group, actor: @owner)
    assert_equal 1, RecordingStudioMessages.unread_count(actor: @viewer)
    assert_equal 0, RecordingStudioMessages.unread_count(actor: @owner)
  end

  test "mark_read is private to the actor and refuses a stranger" do
    group = open_conversation("Private cursor")
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: "Secret line",
      actor: @owner,
      notify: false
    )
    stranger = User.create!(
      email: "stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Stranger"
    )

    RecordingStudioMessages.mark_read(group_recording: group, actor: @viewer)

    refute RecordingStudioMessages.unread?(group_recording: group, actor: @viewer)
    assert RecordingStudioMessages.unread?(group_recording: group, actor: @other)
    refute RecordingStudioMessages.unread?(group_recording: group, actor: stranger)
    assert_raises(RecordingStudioMessages::NotAuthorized) do
      RecordingStudioMessages.mark_read(group_recording: group, actor: stranger)
    end
  end

  test "backfill marks existing membership as read" do
    group = open_conversation("Historic")
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: "Already here",
      actor: @owner,
      notify: false
    )
    RecordingStudioMessages::MessageRead.where(actor_id: @viewer.id).delete_all
    assert RecordingStudioMessages.unread?(group_recording: group, actor: @viewer)

    RecordingStudioMessages::Services::MessageReads.backfill_existing_as_read!

    refute RecordingStudioMessages.unread?(group_recording: group, actor: @viewer)
  end

  test "unread filter keeps keyset paging" do
    groups = Array.new(3) do |index|
      group = open_conversation("U#{index}")
      RecordingStudioMessages.send_message(
        group_recording: group,
        body: "Line #{index}",
        actor: @owner,
        notify: false
      )
      stamp_last_message_at!(group, Time.zone.parse("2026-06-01 12:0#{index}:00"))
      group
    end
    RecordingStudioMessages.mark_read(group_recording: groups[1], actor: @viewer)

    page = RecordingStudioMessages.my_group_recordings(actor: @viewer, unread: true, limit: 1)
    rest = RecordingStudioMessages.my_group_recordings(
      actor: @viewer,
      unread: true,
      limit: 1,
      after: page.last
    )

    assert_equal [ "U2" ], titles(page)
    assert_equal [ "U0" ], titles(rest)
    assert page.is_a?(ActiveRecord::Relation)
    assert rest.is_a?(ActiveRecord::Relation)
  end

  test "unread_count query count stays flat as the inbox grows" do
    2.times { |index| seed_unread("Small #{index}") }
    small = snapshot_unread_count_queries
    2.times { |index| seed_unread("Large #{index}") }
    large = snapshot_unread_count_queries

    assert_equal small, large
    assert_equal 4, RecordingStudioMessages.unread_count(actor: @viewer)
  end

  test "mark_read clears that conversation's message_received notices only" do
    kept = open_conversation("Keep bell")
    cleared = open_conversation("Clear bell")
    RecordingStudioMessages.send_message(
      group_recording: kept,
      body: "Stay unread in the bell",
      actor: @owner,
      url: "/kept"
    )
    RecordingStudioMessages.send_message(
      group_recording: cleared,
      body: "Open this one",
      actor: @owner,
      url: "/cleared"
    )

    RecordingStudioMessages.mark_read(group_recording: cleared, actor: @viewer)

    assert_not_nil notice_for(cleared, @viewer).read_at
    assert_nil notice_for(kept, @viewer).read_at
  end

  test "unread_ids_among skips a trashed conversation" do
    group = seed_unread("Trashed thread")

    assert_includes unread_ids(group), group.id

    group.update_columns(trashed_at: Time.current)

    refute_includes unread_ids(group), group.id
    assert_nil RecordingStudioMessages::Services::LiveRecording.find(group.id)
  end

  test "unread_ids_among runs when no kept filter is registered" do
    group = seed_unread("Unfiltered thread")
    group.update_columns(trashed_at: Time.current)
    RecordingStudio.unregister_recording_filter(:trashable)

    assert_equal "1=1", RecordingStudio.kept_sql
    assert_includes unread_ids(group), group.id
    assert_equal group.id, RecordingStudioMessages::Services::LiveRecording.find(group.id).id
  ensure
    DummyKeptFilter.register!
  end

  private

  def support_mount
    workspace = Workspace.create!(name: "Reads #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @owner)
    raise result.error if result.failure?

    root.ensure_message_mount("support", actor: @owner)
  end

  def open_conversation(title)
    group = RecordingStudioMessages.create_group(@mount, title: title, actor: @owner)
    grant!(group, @viewer)
    grant!(group, @other)
    group
  end

  def seed_unread(title)
    group = open_conversation(title)
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: "Unread #{title}",
      actor: @owner,
      notify: false
    )
    group
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

  def stamp_last_message_at!(recording, time)
    RecordingStudioMessages::MessageGroup.unscoped.where(id: recording.recordable_id).update_all(
      last_message_at: time
    )
    recording.recordable.reload
  end

  def unread_ids(group)
    RecordingStudioMessages::Services::MessageReads.unread_ids_among([group.id], actor: @viewer)
  end

  def titles(recordings)
    recordings.map { |recording| recording.recordable.title }
  end

  def notice_for(group, recipient)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received",
      recipient: recipient
    ).find { |note| note.metadata["message_group_id"] == group.id }
  end

  def snapshot_unread_count_queries
    count = 0
    callback = lambda do |*_args, payload|
      sql = payload[:sql].to_s
      next if payload[:name].to_s.include?("SCHEMA")
      next if payload[:name].to_s == "CACHE"
      next if sql.start_with?("TRANSACTION", "BEGIN", "COMMIT", "SAVEPOINT", "RELEASE")

      count += 1
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      RecordingStudioMessages.unread_count(actor: @viewer)
    end
    count
  end
end
