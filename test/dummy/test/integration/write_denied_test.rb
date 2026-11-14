# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

module WriteDenial
  def reject_message_writes
    config = RecordingStudio.configuration
    previous = config.authorize_write
    config.authorize_write = lambda do |recordable:, **|
      type = recordable.class.name
      type != "RecordingStudioMessages::Message" && type != "RecordingStudioMessages::MessageGroup"
    end
    yield
  ensure
    config.authorize_write = previous
  end
end

class WriteDeniedTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include WriteDenial

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
    @mount = DummyCatalog.support_mount_recording
    @group = DummyCatalog.support_group_recording
    @previous_actor = Current.actor
  end

  teardown do
    Current.actor = @previous_actor
  end

  test "services raise NotAuthorized when authorize_write rejects the write" do
    Current.actor = @staff

    create_error = assert_raises(RecordingStudioMessages::NotAuthorized) do
      reject_message_writes do
        RecordingStudioMessages.create_group(@mount, title: "Blocked desk", actor: @staff)
      end
    end
    assert_equal RecordingStudioMessages::Copy.t("errors.cannot_start"), create_error.message
    assert_nil RecordingStudioMessages.trusted_write_context
    refute RecordingStudioMessages::MessageGroup.exists?(title: "Blocked desk")

    send_error = assert_raises(RecordingStudioMessages::NotAuthorized) do
      reject_message_writes do
        RecordingStudioMessages.send_message(group_recording: @group, body: "Blocked line", actor: @staff)
      end
    end
    assert_equal RecordingStudioMessages::Copy.t("errors.cannot_send_conversation"), send_error.message
    assert_nil RecordingStudioMessages.trusted_write_context
    refute RecordingStudioMessages::Message.exists?(body: "Blocked line")

    rename_error = assert_raises(RecordingStudioMessages::NotAuthorized) do
      reject_message_writes do
        RecordingStudioMessages.rename_group(group_recording: @group, title: "Blocked name", actor: @staff)
      end
    end
    assert_equal RecordingStudioMessages::Copy.t("flashes.cannot_open"), rename_error.message
    assert_nil RecordingStudioMessages.trusted_write_context
    assert_equal "Studio help", @group.reload.recordable.title
  end

  test "html send shows the existing denial" do
    sign_in @staff
    assert_send_denied
  end

  test "turbo send shows the existing denial" do
    sign_in @staff
    assert_send_denied(as: :turbo_stream)
  end

  test "html create shows the existing denial" do
    sign_in @staff
    assert_create_denied
  end

  test "turbo create shows the existing denial" do
    sign_in @staff
    assert_create_denied(as: :turbo_stream)
  end

  test "html rename stays forbidden" do
    sign_in @staff
    assert_rename_forbidden
  end

  test "turbo rename stays forbidden" do
    sign_in @staff
    assert_rename_forbidden(as: :turbo_stream)
  end

  private

  def assert_send_denied(**format)
    assert_no_difference -> { RecordingStudioMessages::Message.count } do
      reject_message_writes do
        post recording_studio_messages.message_group_messages_path(@group),
             params: { message: { body: "Should not send" } },
             **format
      end
    end

    assert_redirected_to recording_studio_messages.message_group_path(@group)
    assert_equal RecordingStudioMessages::Copy.t("errors.cannot_send_conversation"), flash[:alert]
  end

  def assert_create_denied(**format)
    assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
      reject_message_writes do
        post recording_studio_messages.message_groups_path,
             params: {
               mount_id: @mount.id,
               body: "Should not start",
               recipients: [ "User:#{@customer.id}" ]
             },
             **format
      end
    end

    assert_redirected_to recording_studio_messages.message_groups_path(mount_id: @mount.id)
    assert_equal RecordingStudioMessages::Copy.t("errors.cannot_start"), flash[:alert]
  end

  def assert_rename_forbidden(**format)
    assert_no_difference -> { @group.events.count } do
      reject_message_writes do
        patch recording_studio_messages.rename_message_group_path(@group),
              params: { message_group: { title: "Should not rename" } },
              **format
      end
    end

    assert_response :forbidden
    assert_equal "Studio help", @group.reload.recordable.title
  end
end

class PublicContactWriteDeniedTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include WriteDenial

  setup do
    @staff = User.create!(
      email: "admin@admin.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Ada Staff",
      confirmed_at: Time.current
    )
    @workspace = Workspace.create!(name: "Denied contact #{SecureRandom.hex(4)}")
    @root = RecordingStudio.root_recording_for(@workspace)
    Current.actor = @staff
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @staff)
    mailbox = Mailbox.create!(name: "Denied mailbox #{SecureRandom.hex(4)}")
    mailbox_recording = RecordingStudio.record!(
      action: "created",
      recordable: mailbox,
      root_recording: @root,
      parent_recording: @root,
      actor: @staff
    ).recording
    @mount = mailbox_recording.ensure_message_mount("inbox", actor: @staff)
  end

  teardown do
    Current.actor = nil
  end

  test "html public contact shows the existing denial" do
    sign_in @staff
    assert_contact_denied
  end

  test "turbo public contact shows the existing denial" do
    sign_in @staff
    assert_contact_denied(
      params: { body: "Should not send", presentation: "modal" },
      headers: { "Turbo-Frame" => RecordingStudioMessages::PublicContactHelper::FRAME_ID }
    )
    assert_select "turbo-frame#public_contact"
  end

  private

  def assert_contact_denied(params: { body: "Should not send" }, headers: {})
    assert_no_difference -> { RecordingStudioMessages::Message.count } do
      assert_no_difference -> { RecordingStudioMessages::MessageGroup.count } do
        reject_message_writes do
          post recording_studio_messages.public_contact_path(mount_id: @mount.id),
               params: params,
               headers: headers
        end
      end
    end

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: RecordingStudioMessages::Copy.t("errors.cannot_send")
  end
end
