# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class TwoMountsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
  end

  test "dummy host enables two keyed mounts on different parents" do
    support_mount = DummyCatalog.support_mount_recording
    inbox_mount = DummyCatalog.inbox_mount_recording

    assert RecordingStudio.capability_enabled?(:messages, for: Workspace)
    assert RecordingStudio.capability_enabled?(:messages, for: Mailbox)
    assert_equal ["support"], Array(RecordingStudio.capability_options(:messages, for: Workspace)[:keys]).map(&:to_s)
    assert_equal ["inbox"], Array(RecordingStudio.capability_options(:messages, for: Mailbox)[:keys]).map(&:to_s)
    assert_equal "Workspace", support_mount.parent_recording.recordable_type
    assert_equal "Mailbox", inbox_mount.parent_recording.recordable_type
    refute_equal support_mount.parent_recording, inbox_mount.parent_recording
    assert_equal "support", support_mount.recordable.key
    assert_equal "inbox", inbox_mount.recordable.key
    assert_includes RecordingStudio.capability_child_recordables_for(:messages),
                    "RecordingStudioMessages::MessageMount"
  end

  test "staff desk and inbox land on the conversation list for each mount" do
    sign_in @staff
    get staff_desk_path

    assert_response :success
    assert_select "html[data-theme='rounded']", count: 1
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_includes response.body, "Studio help"
    assert_includes response.body, "Launch notes"
    assert_select "[data-controller='flat-pack--chat-layout']"
    assert_select "[data-controller='flat-pack--list-selectable']"
    assert_includes response.body, "flat-pack--chat-panel"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "recording-studio-root-switchable--root-switch-dropdown"

    sign_in @customer
    get inbox_path

    assert_response :success
    assert_select "html[data-theme='rounded']", count: 1
    assert_includes response.body, "Site inbox"
    assert_includes response.body, "They are in. I attached the first frame."
    assert_includes response.body, "flat-pack--chat-panel"
  end

  test "catalog keeps the seeded desks when another conversation reuses the title" do
    leftover_workspace = Workspace.create!(name: "Leftover #{SecureRandom.hex(4)}")
    leftover_root = RecordingStudio.root_recording_for(leftover_workspace)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: leftover_root, actor: @staff)
    leftover_mount = leftover_root.ensure_message_mount("support", actor: @staff)
    leftover_group = RecordingStudioMessages.create_group(
      leftover_mount,
      title: DummyCatalog::SUPPORT_TITLE,
      actor: @staff
    )

    refute_equal leftover_group, DummyCatalog.support_group_recording
    assert_equal DummyCatalog.support_mount_recording, DummyCatalog.support_group_recording.parent_recording
    assert RecordingStudioAccessible.authorized?(
      actor: @staff,
      recording: DummyCatalog.support_group_recording,
      role: :view
    )
  end

  test "empty conversation shows plus access when the grant list is empty" do
    sign_in @staff
    get recording_studio_messages.message_group_path(DummyCatalog.empty_group_recording)

    assert_response :success
    assert_includes response.body, "+ Access"
  end

  test "people without a grant cannot open the staff desk" do
    stranger = User.create!(
      email: "stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Stranger"
    )

    sign_in stranger
    get staff_desk_path

    assert_redirected_to root_path
  end
end
