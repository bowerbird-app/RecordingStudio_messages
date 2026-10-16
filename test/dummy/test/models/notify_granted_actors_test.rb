# frozen_string_literal: true

require "test_helper"

class NotifyGrantedActorsTest < ActiveSupport::TestCase
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
    @workspace = Workspace.create!(name: "Notify #{SecureRandom.hex(4)}")
    @ticket_root = RecordingStudio.root_recording_for(@workspace)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @ticket_root, actor: @staff)
    @mount = @ticket_root.ensure_message_mount("support", actor: @staff)
    @group = RecordingStudioMessages.create_group(@mount, title: "Root filing", actor: @staff)
    result = RecordingStudioAccessible.grant_access(
      recording: @group,
      actor: @customer,
      role: :edit,
      manager_actor: @staff
    )
    raise result.error if result.failure?

    @admin_root_recordable = AdminRoot.create!(name: "Notify Admin #{SecureRandom.hex(4)}")
    @admin_root = RecordingStudio.root_recording_for(@admin_root_recordable)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @admin_root, actor: @staff)
  end

  teardown do
    RecordingStudioMessages.configuration.admin_notification_root = nil
  end

  test "default files every recipient under the ticket root" do
    RecordingStudioMessages.configuration.admin_notification_root = nil

    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Default filing stays on the ticket.",
      actor: @customer,
      url: "/staff/desk"
    )

    staff_note = last_message_received_for(@staff)
    assert_equal @ticket_root.id, staff_note.root_recording_id
    assert_equal @staff, staff_note.recipient
    assert_equal RecordingStudioMessages::MESSAGE_TYPE, staff_note.recording.recordable_type
  end

  test "opted-in staff recipient is filed under the admin root" do
    RecordingStudioMessages.configuration.admin_notification_root = @admin_root

    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Staff should see this in Admin.",
      actor: @customer,
      url: "/admin/support/messages?group_id=#{@group.id}"
    )

    staff_note = last_message_received_for(@staff)
    assert_equal @admin_root.id, staff_note.root_recording_id
    assert_nil staff_note.recording_id
    assert_equal @group.id, staff_note.metadata["message_group_id"]
    assert_equal @ticket_root, @group.root_recording
  end

  test "ticket owner stays on the ticket root when admin filing is on" do
    RecordingStudioMessages.configuration.admin_notification_root = @admin_root

    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Casey keeps the workspace inbox.",
      actor: @staff,
      url: "/inbox"
    )

    customer_note = last_message_received_for(@customer)
    assert_equal @customer, customer_note.recipient
    assert_equal @ticket_root.id, customer_note.root_recording_id
    refute_equal @admin_root.id, customer_note.root_recording_id
  end

  test "callable admin_notification_root files staff under the returned recording" do
    RecordingStudioMessages.configuration.admin_notification_root = -> { @admin_root }

    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "Resolver points at Admin.",
      actor: @customer
    )

    staff_note = last_message_received_for(@staff)
    assert_equal @admin_root.id, staff_note.root_recording_id
  end

  private

  def last_message_received_for(recipient)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received",
      recipient: recipient
    ).order(:created_at).last
  end
end
