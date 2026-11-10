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

  test "unread filter keeps conversations the actor can view on that mount" do
    read = RecordingStudioMessages.create_group(@mount, title: "Already opened", actor: @owner)
    unread = RecordingStudioMessages.create_group(@mount, title: "Still unread", actor: @owner)
    hidden = RecordingStudioMessages.create_group(@other_mount, title: "Other unread", actor: @owner)
    grant!(read, @viewer)
    grant!(unread, @viewer)
    grant!(hidden, @viewer)
    send_line(read, "Read line")
    send_line(unread, "Unread line")
    send_line(hidden, "Hidden line")
    RecordingStudioMessages.mark_read(group_recording: read, actor: @viewer)

    recordings = listed(actor: @viewer, mount_recording: @mount, unread: true)

    assert_equal [ "Still unread" ], titles(recordings)
    refute_includes titles(recordings), "Already opened"
    refute_includes titles(recordings), "Other unread"
    refute_includes titles(recordings), "Alpha"
  end

  test "unread filter still requires an Accessible view grant" do
    unread = RecordingStudioMessages.create_group(@mount, title: "No grant unread", actor: @owner)
    send_line(unread, "Secret line")

    assert_equal [], titles(listed(actor: @viewer, mount_recording: @mount, unread: true))
    assert_equal [], titles(listed(actor: @stranger, mount_recording: @mount, unread: true))
  end

  test "unread filter keeps after_id paging" do
    groups = Array.new(3) do |index|
      group = RecordingStudioMessages.create_group(@mount, title: "U#{index}", actor: @owner)
      grant!(group, @viewer)
      send_line(group, "Line #{index}")
      stamp_last_message_at!(group, Time.zone.parse("2026-06-01 12:0#{index}:00"))
      group
    end
    RecordingStudioMessages.mark_read(group_recording: groups[1], actor: @viewer)

    page = listed(actor: @viewer, mount_recording: @mount, unread: true, limit: 1)
    rest = listed(actor: @viewer, mount_recording: @mount, unread: true, limit: 1, after: page.last)

    assert_equal [ "U2" ], titles(page)
    assert_equal [ "U0" ], titles(rest)
  end

  test "unread listing does not query each conversation's messages" do
    unread = RecordingStudioMessages.create_group(@mount, title: "Batch unread", actor: @owner)
    grant!(unread, @viewer)
    send_line(unread, "Stay unread")

    sql = []
    callback = lambda do |*_args, payload|
      query = payload[:sql].to_s
      next if payload[:name].to_s.include?("SCHEMA")
      next if payload[:name].to_s == "CACHE"

      sql << query
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      listed(actor: @viewer, mount_recording: @mount, unread: true)
    end

    refute sql.any? { |query| query.include?("recording_studio_messages") && query.include?("parent_recording_id") },
           sql.join("\n")
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

  def listed(actor:, mount_recording:, **options)
    RecordingStudioMessages.viewable_group_recordings(
      actor: actor,
      mount_recording: mount_recording,
      **options
    )
  end

  def send_line(group, body)
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: body,
      actor: @owner,
      notify: false
    )
  end

  def stamp_last_message_at!(recording, time)
    RecordingStudioMessages::MessageGroup.unscoped.where(id: recording.recordable_id).update_all(
      last_message_at: time
    )
    recording.recordable.reload
  end

  def titles(recordings)
    recordings.map { |recording| recording.recordable.title }
  end
end
