# frozen_string_literal: true

require "test_helper"

class SendMessageTest < ActiveSupport::TestCase
  setup do
    @staff = User.create!(
      email: "staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Ada Staff"
    )
    @customer = User.create!(
      email: "customer-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Casey Patron"
    )
    @workspace = Workspace.create!(name: "Send #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @staff)
    @mount = @root.ensure_message_mount("support", actor: @staff)
    @group = RecordingStudioMessages.create_group(@mount, title: "Notify conversation", actor: @staff)
    result = RecordingStudioAccessible.grant_access(
      recording: @group,
      actor: @customer,
      role: :edit,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  end

  test "send_message records a message, attaches a file, and notifies other granted actors" do
    Current.actor = @staff

    message_recording = RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Here is the quieter crop.",
      actor: @staff,
      files: [{
        io: StringIO.new("not a real image"),
        filename: "note.txt",
        content_type: "text/plain",
        name: "Note"
      }],
      url: "/staff/desk"
    )

    assert_equal "Here is the quieter crop.", message_recording.recordable.body
    assert_equal @group, message_recording.parent_recording
    assert message_recording.has_attachments?

    notifications = RecordingStudioNotifications::Notification.where(notification_type: "message_received")
    assert_equal 1, notifications.count
    assert_equal @customer, notifications.first.recipient
    assert_equal @staff, notifications.first.actor
    assert_equal "/staff/desk", notifications.first.url
  end

  test "send_message refuses actors without an accessible grant" do
    stranger = User.create!(
      email: "no-access-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    assert_raises(RecordingStudioMessages::NotAuthorized) do
      RecordingStudioMessages.send_message(
        group_recording: @group,
        body: "Should not land",
        actor: stranger
      )
    end
  end

  test "ensure_message_mount rejects a key that is not enabled on the type" do
    error = assert_raises(RecordingStudioMessages::Error) do
      @root.ensure_message_mount("inbox", actor: @staff)
    end

    assert_match(/inbox/, error.message)
  end

  test "membership is accessible grants and does not add participant recordables" do
    actors = RecordingStudioMessages.granted_actors(@group).map(&:email)

    assert_includes actors, @staff.email
    assert_includes actors, @customer.email
    refute File.exist?(Rails.root.join("../../app/models/recording_studio_messages/participant.rb"))
  end
end
