# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class InheritedContactAccessTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @otp_was = RecordingStudioUser.config.otp_enabled
    RecordingStudioUser.config.otp_enabled = true
    RecordingStudioUser::Engine.apply_otp_setup!(User)

    @staff = User.create!(
      email: "staff-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Ada Staff",
      confirmed_at: Time.current
    )
    @sender = User.create!(
      email: "sender-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Casey Patron",
      confirmed_at: Time.current
    )
    @workspace = Workspace.create!(name: "Contact access #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    Current.actor = @staff
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @staff)
    mailbox = Mailbox.create!(name: "Contact mailbox #{SecureRandom.hex(4)}")
    mailbox_recording = RecordingStudio.record!(
      action: "created",
      recordable: mailbox,
      root_recording: @root,
      parent_recording: @root,
      actor: @staff
    ).recording
    @inherited_mount = mailbox_recording.ensure_message_mount("inbox", actor: @staff)
    @members_mount = @root.ensure_message_mount("support", actor: @staff)
    @original_mailbox = RecordingStudio.capability_options(:messages, for: Mailbox)
    @original_workspace = RecordingStudio.capability_options(:messages, for: Workspace)
  end

  teardown do
    Current.actor = nil
    RecordingStudioUser.config.otp_enabled = @otp_was
    restore_options!(Mailbox, @original_mailbox, keys: [:inbox], public_contact: [:inbox], access: :inherited)
    restore_options!(Workspace, @original_workspace, keys: [:support])
  end

  test "inherited public contact grants the sender edit and skips an empty resolver" do
    with_contact_config(public_contact_recipient_resolver: ->(**) { [] }) do
      outcome = RecordingStudioMessages.begin_public_contact(
        mount_recording: @inherited_mount,
        name: "Casey Patron",
        email: @sender.email,
        body: "Did the stills land?",
        current_actor: @sender,
        request: nil,
        session: {}
      )

      group = outcome.group_recording
      granted_ids = RecordingStudioMessages.granted_actors(group).map(&:id)
      assert_includes granted_ids, @sender.id
      refute_includes granted_ids, @staff.id
      assert_equal :edit, RecordingStudioAccessible.role_for(actor: @sender, recording: group)
      assert RecordingStudioAccessible.authorized?(actor: @staff, recording: group, role: :view)
      titles = RecordingStudioMessages.my_group_recordings(actor: @sender).map { |row| row.recordable.title }
      staff_titles = RecordingStudioMessages.my_group_recordings(actor: @staff).map { |row| row.recordable.title }
      assert_includes titles, group.recordable.title
      refute_includes staff_titles, group.recordable.title
      assert_equal 0, message_received_count
    end
  end

  test "members public contact still fails without an opener" do
    RecordingStudio.set_capability_options(
      :messages,
      on: Workspace,
      keys: [:support],
      public_contact: [:support],
      access: :members
    )

    with_contact_config(public_contact_recipient_resolver: ->(**) { [] }) do
      error = assert_raises(RecordingStudioMessages::Error) do
        RecordingStudioMessages.begin_public_contact(
          mount_recording: @members_mount,
          name: "Casey Patron",
          email: @sender.email,
          body: "Is anyone there?",
          current_actor: @sender,
          request: nil,
          session: {}
        )
      end

      assert_equal RecordingStudioMessages::Copy.t("errors.no_recipient"), error.message
      assert_equal 0, RecordingStudio::Recording.where(
        parent_recording_id: @members_mount.id,
        recordable_type: "RecordingStudioMessages::MessageGroup"
      ).count
    end
  end

  test "members public contact still fails when no resolver recipient is an admin" do
    RecordingStudio.set_capability_options(
      :messages,
      on: Workspace,
      keys: [:support],
      public_contact: [:support],
      access: :members
    )

    with_contact_config(public_contact_recipient_resolver: ->(**) { [@sender] }) do
      error = assert_raises(RecordingStudioMessages::Error) do
        RecordingStudioMessages.begin_public_contact(
          mount_recording: @members_mount,
          name: "Casey Patron",
          email: @sender.email,
          body: "Is anyone there?",
          current_actor: @sender,
          request: nil,
          session: {}
        )
      end

      assert_equal RecordingStudioMessages::Copy.t("errors.no_recipient"), error.message
    end
  end

  private

  def restore_options!(type, original, **fallback)
    if original
      RecordingStudio.set_capability_options(:messages, on: type, **original)
    else
      RecordingStudio.set_capability_options(:messages, on: type, **fallback)
    end
  end

  def with_contact_config(**values)
    config = RecordingStudioMessages.configuration
    previous = values.keys.to_h { |key| [key, config.public_send(key)] }
    values.each { |key, value| config.public_send("#{key}=", value) }
    yield
  ensure
    previous&.each { |key, value| config.public_send("#{key}=", value) }
  end

  def message_received_count
    RecordingStudioNotifications::Notification.where(notification_type: "message_received").count
  end
end
