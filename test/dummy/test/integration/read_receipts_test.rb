# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ReadReceiptsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  SENT_CHECK_PATH = "M7.78 13.78a.75.75 0 01-1.06 0L3.22 10.28"

  setup do
    @previous_actor = Current.actor
    @previous_receipts = RecordingStudioMessages.configuration.read_receipts
    RecordingStudioMessages.configuration.read_receipts = false
    @owner = create_user("Ada Staff")
    @viewer = create_user("Casey Patron")
    Current.actor = @owner
    @mount = support_mount
  end

  teardown do
    RecordingStudioMessages.configuration.read_receipts = @previous_receipts
    Current.actor = @previous_actor
  end

  test "conversation show keeps the time and omits the sent check" do
    group = open_conversation
    send_line(group, "Quiet crop is in.")
    sign_in @viewer
    Current.actor = @viewer

    get recording_studio_messages.message_group_path(group)

    assert_response :success
    assert_includes response.body, "Quiet crop is in."
    refute_includes response.body, SENT_CHECK_PATH
    refute_includes response.body, "data-messages-seen-for"
  end

  test "seen faces stay off until the host turns read receipts on" do
    group, first, second = conversation_with_staggered_reads
    sign_in @viewer
    Current.actor = @viewer

    get recording_studio_messages.message_group_path(group)

    assert_response :success
    refute_includes response.body, "data-messages-seen-for"
    refute_includes response.body, "Seen by"

    RecordingStudioMessages.configuration.read_receipts = true
    get recording_studio_messages.message_group_path(group)

    assert_response :success
    first_seen = css_select("[data-messages-seen-for='#{first.id}']").to_s
    second_seen = css_select("[data-messages-seen-for='#{second.id}']").to_s
    assert_includes first_seen, "Jules"
    assert_includes second_seen, "+1"
    refute_includes first_seen, "Casey Patron"
    refute_includes second_seen, "Casey Patron"
    assert_includes response.body, "Seen by"
    refute_includes response.body, SENT_CHECK_PATH
  end

  private

  def support_mount
    workspace = Workspace.create!(name: "Seen #{SecureRandom.hex(4)}")
    root = RecordingStudio.root_recording_for(workspace)
    result = RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: @owner)
    raise result.error if result.failure?

    root.ensure_message_mount("support", actor: @owner)
  end

  def open_conversation
    group = RecordingStudioMessages.create_group(@mount, title: "Seen thread", actor: @owner)
    grant!(group, @viewer)
    group
  end

  def conversation_with_staggered_reads
    group = open_conversation
    first = send_line(group, "First seen line")
    second = send_line(group, "Latest seen line")
    pin_read(@owner, group, second)
    jules = create_user("Jules")
    grant!(group, jules)
    pin_read(jules, group, first)
    %w[Ann Bea Cy].each do |name|
      actor = create_user(name)
      grant!(group, actor)
      pin_read(actor, group, second)
    end
    pin_read(@viewer, group, second)
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
end
