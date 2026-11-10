# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class MessageTimestampsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  SENT_CHECK_PATH = "M7.78 13.78a.75.75 0 01-1.06 0L3.22 10.28"

  setup do
    @previous_actor = Current.actor
    @previous_receipts = RecordingStudioMessages.configuration.read_receipts
    @previous_gap = RecordingStudioMessages.configuration.time_break_after
    RecordingStudioMessages.configuration.read_receipts = false
    RecordingStudioMessages.configuration.time_break_after = 15.minutes
    @owner = create_user("Ada Staff")
    @viewer = create_user("Casey Patron")
    Current.actor = @owner
    @mount = support_mount
  end

  teardown do
    RecordingStudioMessages.configuration.read_receipts = @previous_receipts
    RecordingStudioMessages.configuration.time_break_after = @previous_gap
    Current.actor = @previous_actor
  end

  test "keeps the bubble time in the DOM and omits the sent check" do
    group = open_conversation
    message = send_line(group, "Quiet crop is in.")
    stamp(message, Time.zone.parse("2026-11-10 14:30"))
    sign_in @viewer
    Current.actor = @viewer

    get recording_studio_messages.message_group_path(group)

    assert_response :success
    html = response.body
    assert_includes html, "Quiet crop is in."
    assert_includes html, "fp-chat-timestamp"
    assert_includes html, "fp-chat-timestamp-reveal"
    assert_includes html, "flat-pack--chat-timestamp-reveal"
    assert_includes html, "2:30 PM"
    timestamp = css_select(".fp-chat-timestamp").map(&:to_s).join
    assert_includes timestamp, "2:30 PM"
    refute_includes timestamp, "display:none"
    refute_includes timestamp, "aria-hidden"
    refute_includes html, SENT_CHECK_PATH
    assert_includes html, "Sent 2:30 PM"
    assert_includes html, "data-flat-pack-chat-group-status"
    refute_includes html, "data-messages-seen-for"
  end

  test "does not insert a time divider when the gap is 15 minutes or less" do
    group = open_conversation
    origin = Time.zone.parse("2026-11-10 10:00")
    first = send_line(group, "First close line")
    second = send_line(group, "Second close line")
    stamp(first, origin)
    stamp(second, origin + 15.minutes)
    sign_in @owner

    get recording_studio_messages.message_group_path(group)

    assert_response :success
    labels = css_select("[data-flat-pack-chat-group-break='true']").map { |node| node["aria-label"] }
    assert_equal [ "10 Nov 2026" ], labels
  end

  test "inserts a time divider when the gap is more than 15 minutes" do
    group = open_conversation
    origin = Time.zone.parse("2026-11-10 10:00")
    first = send_line(group, "First far line")
    second = send_line(group, "Second far line")
    stamp(first, origin)
    stamp(second, origin + 15.minutes + 1.second)
    sign_in @owner

    get recording_studio_messages.message_group_path(group)

    assert_response :success
    labels = css_select("[data-flat-pack-chat-group-break='true']").map { |node| node["aria-label"] }
    assert_equal [ "10 Nov 2026", "10:15 AM" ], labels
  end

  test "time_break_after overrides the default gap" do
    RecordingStudioMessages.configuration.time_break_after = 30
    group = open_conversation
    origin = Time.zone.parse("2026-11-10 10:00")
    first = send_line(group, "Override first")
    second = send_line(group, "Override second")
    stamp(first, origin)
    stamp(second, origin + 20.minutes)
    sign_in @owner

    get recording_studio_messages.message_group_path(group)

    assert_response :success
    labels = css_select("[data-flat-pack-chat-group-break='true']").map { |node| node["aria-label"] }
    assert_equal [ "10 Nov 2026" ], labels
  end

  test "keeps a day divider when consecutive messages fall on different days" do
    group = open_conversation
    first = send_line(group, "Monday line")
    second = send_line(group, "Tuesday line")
    stamp(first, Time.zone.parse("2026-11-10 23:50"))
    stamp(second, Time.zone.parse("2026-11-11 00:05"))
    sign_in @owner

    get recording_studio_messages.message_group_path(group)

    assert_response :success
    labels = css_select("[data-flat-pack-chat-group-break='true']").map { |node| node["aria-label"] }
    assert_equal [ "10 Nov 2026", "11 Nov 2026" ], labels
  end

  test "last-message status is SentAt until others have read it" do
    group = open_conversation
    message = send_line(group, "Waiting for a read")
    stamp(message, Time.zone.parse("2026-11-10 14:30"))
    RecordingStudioMessages.configuration.read_receipts = true
    sign_in @owner

    get recording_studio_messages.message_group_path(group)

    assert_response :success
    assert_includes response.body, "Sent 2:30 PM"
    refute_includes response.body, "data-messages-seen-for"

    pin_read(@viewer, group, message)
    get recording_studio_messages.message_group_path(group)

    assert_response :success
    refute_includes response.body, "Sent 2:30 PM"
    seen = css_select("[data-flat-pack-chat-group-status='true'] [data-messages-seen-for='#{message.id}']")
    assert_equal 1, seen.size
    assert_equal 1, css_select("[data-messages-seen-for]").size
  end

  test "gap dividers use the loaded thread and do not query per message" do
    group = open_conversation
    origin = Time.zone.parse("2026-11-10 09:00")
    messages = Array.new(6) { |index| send_line(group, "Gap #{index}") }
    messages.each_with_index { |message, index| stamp(message, origin + (index * 20).minutes) }
    loaded = RecordingStudioMessages.message_recordings(group).to_a
    helper = ApplicationController.new.view_context
    helper.extend(RecordingStudioMessages::PanelHelper)

    count = count_loads do
      previous = nil
      loaded.each do |message|
        helper.message_day_break?(previous, message)
        helper.message_time_break?(previous, message)
        helper.message_clock(message)
        previous = message
      end
    end

    assert_equal 6, loaded.size
    assert_equal 0, count
    assert helper.message_time_break?(loaded[0], loaded[1])
    refute helper.message_time_break?(loaded[0], loaded[0])
  end

  private

  def support_mount
    workspace = Workspace.create!(name: "Times #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @owner)
    raise result.error if result.failure?

    root.ensure_message_mount("support", actor: @owner)
  end

  def open_conversation
    group = RecordingStudioMessages.create_group(@mount, title: "Timed thread", actor: @owner)
    grant!(group, @viewer)
    group
  end

  def send_line(group, body)
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: body,
      actor: @owner,
      notify: false
    )
  end

  def stamp(recording, time)
    recording.update_columns(created_at: time, updated_at: time)
    RecordingStudioMessages::MessageGroup.unscoped.where(id: recording.parent_recording.recordable_id).update_all(
      last_message_at: time
    )
  end

  def pin_read(actor, group, message)
    RecordingStudioMessages::Services::MessageReads.new(actor: actor).upsert_cursor(
      group_recording: group,
      last_read_at: message.created_at,
      last_read_message_recording_id: message.id
    )
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

  def create_user(name)
    User.create!(
      email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: name
    )
  end

  def count_loads
    count = 0
    callback = lambda do |*_args, payload|
      name = payload[:name].to_s
      next unless name.end_with?(" Load")
      next if name.include?("SCHEMA")
      next if name == "CACHE"

      count += 1
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    count
  end
end
