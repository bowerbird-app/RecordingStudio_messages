# frozen_string_literal: true

require "test_helper"

class SeenByTest < ActiveSupport::TestCase
  setup do
    @previous_actor = Current.actor
    @previous_receipts = RecordingStudioMessages.configuration.read_receipts
    RecordingStudioMessages.configuration.read_receipts = false
    @owner = create_user("Owner")
    @viewer = create_user("Viewer")
    @other = create_user("Other")
    Current.actor = @owner
    @mount = support_mount
  end

  teardown do
    RecordingStudioMessages.configuration.read_receipts = @previous_receipts
    Current.actor = @previous_actor
  end

  test "returns no readers when the host leaves read receipts off" do
    group, _first, second = conversation_with_two_lines
    pin_read(@other, group, second)

    assert_equal [], RecordingStudioMessages.seen_by(group_recording: group, viewer: @viewer)
  end

  test "returns people whose cursor has reached the latest message" do
    RecordingStudioMessages.configuration.read_receipts = true
    group, first, second = conversation_with_two_lines
    late = create_user("Late")
    grant!(group, late)
    pin_read(@other, group, first)
    pin_read(late, group, second)
    pin_read(@viewer, group, second)

    result = RecordingStudioMessages.seen_by(group_recording: group, viewer: @viewer)

    assert_equal [ late.id, @owner.id ], result.map(&:id)
    refute_includes result.map(&:id), @other.id
    refute_includes result.map(&:id), @viewer.id
  end

  test "counts a cursor that matches the latest id or is at least as new as that line" do
    RecordingStudioMessages.configuration.read_receipts = true
    group, _first, second = conversation_with_two_lines
    by_id = create_user("By Id")
    by_time = create_user("By Time")
    grant!(group, by_id)
    grant!(group, by_time)
    RecordingStudioMessages::Services::MessageReads.new(actor: by_id).upsert_cursor(
      group_recording: group,
      last_read_at: second.created_at - 1.minute,
      last_read_message_recording_id: second.id
    )
    RecordingStudioMessages::Services::MessageReads.new(actor: by_time).upsert_cursor(
      group_recording: group,
      last_read_at: second.created_at + 1.minute,
      last_read_message_recording_id: nil
    )

    result = RecordingStudioMessages.seen_by(group_recording: group, viewer: @viewer)

    assert_includes result.map(&:id), by_id.id
    assert_includes result.map(&:id), by_time.id
  end

  test "hides a reader after their conversation grant is trashed" do
    RecordingStudioMessages.configuration.read_receipts = true
    group, _first, second = conversation_with_two_lines
    pin_read(@other, group, second)
    trash_grant!(group, @other)

    result = RecordingStudioMessages.seen_by(group_recording: group, viewer: @viewer)

    refute_includes result.map(&:id), @other.id
    refute_includes result.map(&:id), @viewer.id
  end

  test "query count stays flat as more readers join" do
    RecordingStudioMessages.configuration.read_receipts = true
    group, _first, second = conversation_with_two_lines
    2.times { |index| add_reader(group, second, "Caught #{index}") }
    small = snapshot_reader_queries(group)
    2.times { |index| add_reader(group, second, "Later #{index}") }
    large = snapshot_reader_queries(group)
    result = RecordingStudioMessages.seen_by(group_recording: group, viewer: @viewer)

    assert_equal small, large
    assert_equal 2, result.count { |actor| actor.name.start_with?("Caught") }
    assert_equal 2, result.count { |actor| actor.name.start_with?("Later") }
  end

  private

  def support_mount
    workspace = Workspace.create!(name: "Receipts #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @owner)
    raise result.error if result.failure?

    root.ensure_message_mount("support", actor: @owner)
  end

  def conversation_with_two_lines
    group = RecordingStudioMessages.create_group(@mount, title: "Receipts", actor: @owner)
    grant!(group, @viewer)
    grant!(group, @other)
    first = send_line(group, "First line")
    second = send_line(group, "Second line")
    pin_read(@owner, group, second)
    [ group, first, second ]
  end

  def send_line(group, body)
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: body,
      actor: @owner,
      notify: false
    )
  end

  def pin_read(actor, group, message)
    RecordingStudioMessages::Services::MessageReads.new(actor: actor).upsert_cursor(
      group_recording: group,
      last_read_at: message.created_at,
      last_read_message_recording_id: message.id
    )
  end

  def add_reader(group, message, name)
    actor = create_user(name)
    grant!(group, actor)
    pin_read(actor, group, message)
    actor
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

  def trash_grant!(recording, actor)
    access_recording = RecordingStudioAccessible.access_recordings_for_actor(
      recording: recording,
      actor: actor
    ).first
    access_recording.update_column(:trashed_at, Time.current)
  end

  def create_user(name)
    User.create!(
      email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: name
    )
  end

  def snapshot_reader_queries(group)
    count = 0
    callback = lambda do |*_args, payload|
      sql = payload[:sql].to_s
      next if payload[:name].to_s.include?("SCHEMA")
      next if payload[:name].to_s == "CACHE"
      next if sql.start_with?("TRANSACTION", "BEGIN", "COMMIT", "SAVEPOINT", "RELEASE")

      count += 1
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      RecordingStudioMessages.seen_by(group_recording: group, viewer: @viewer)
    end
    count
  end
end
