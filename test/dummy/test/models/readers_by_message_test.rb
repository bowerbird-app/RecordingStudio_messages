# frozen_string_literal: true

require "test_helper"

class ReadersByMessageTest < ActiveSupport::TestCase
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
    group, first, _second = conversation_with_two_lines
    pin_read(@other, group, first)

    assert_equal({}, RecordingStudioMessages.readers_by_message(group_recording: group, viewer: @viewer))
  end

  test "places each remaining viewer under the message they last read" do
    RecordingStudioMessages.configuration.read_receipts = true
    group, first, second = conversation_with_two_lines
    late = create_user("Late")
    grant!(group, late)
    pin_read(@other, group, first)
    pin_read(late, group, second)
    pin_read(@viewer, group, second)

    result = RecordingStudioMessages.readers_by_message(group_recording: group, viewer: @viewer)

    assert_equal [ @other.id ], result.fetch(first.id).map(&:id)
    assert_equal [ late.id, @owner.id ], result.fetch(second.id).map(&:id)
    refute_includes result.values.flatten.map(&:id), @viewer.id
  end

  test "hides a reader after their conversation grant is trashed" do
    RecordingStudioMessages.configuration.read_receipts = true
    group, first, _second = conversation_with_two_lines
    pin_read(@other, group, first)
    trash_grant!(group, @other)

    result = RecordingStudioMessages.readers_by_message(group_recording: group, viewer: @viewer)
    remaining = result.values.flatten.map(&:id)

    refute_includes remaining, @other.id
    refute_includes remaining, @viewer.id
  end

  test "query count stays flat as more readers join" do
    RecordingStudioMessages.configuration.read_receipts = true
    group, first, second = conversation_with_two_lines
    2.times { |index| add_reader(group, first, "Early #{index}") }
    small = snapshot_reader_queries(group)
    2.times { |index| add_reader(group, second, "Late #{index}") }
    large = snapshot_reader_queries(group)
    result = RecordingStudioMessages.readers_by_message(group_recording: group, viewer: @viewer)

    assert_equal small, large
    assert_equal 2, result.fetch(first.id).count { |actor| actor.name.start_with?("Early") }
    assert_equal 2, result.fetch(second.id).count { |actor| actor.name.start_with?("Late") }
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
      RecordingStudioMessages.readers_by_message(group_recording: group, viewer: @viewer)
    end
    count
  end
end
