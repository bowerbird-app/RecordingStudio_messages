# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class MembershipLockTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
    @original_options = RecordingStudio.capability_options(:messages, for: Workspace)
    RecordingStudioMessages::MembershipLock.install_authorizer_wrap!
  end

  teardown do
    restore_workspace_messages_options!
  end

  test "unlocked mount still shows plus access on an empty conversation" do
    sign_in @staff
    get recording_studio_messages.message_group_path(DummyCatalog.empty_group_recording)

    assert_response :success
    assert_includes response.body, "+ Access"
    refute RecordingStudioMessages.membership_locked?(DummyCatalog.support_mount_recording)
  end

  test "locked mount hides access UI and denies grant update revoke" do
    lock_support_mount!

    mount = DummyCatalog.support_mount_recording
    empty_group = DummyCatalog.empty_group_recording
    support_group = DummyCatalog.support_group_recording

    assert RecordingStudioMessages.membership_locked?(mount)
    assert RecordingStudioMessages.membership_locked_for_group?(empty_group)

    Current.actor = @staff
    empty_html = render_panel(empty_group)
    support_html = render_panel(support_group)

    refute_includes empty_html, "+ Access"
    refute_includes support_html, "Manage access"
    refute_match(/flat-pack--avatar/i, support_html)

    deny_grant = RecordingStudioAccessible.grant_access(
      recording: empty_group,
      actor: @customer,
      role: :view,
      manager_actor: @staff
    )
    assert deny_grant.failure?, "grant_access should fail on a locked mount"
    assert_match(/not authorized/i, deny_grant.error.to_s)

    existing = RecordingStudioAccessible.access_recordings_for(support_group).first
    assert existing

    deny_update = RecordingStudioAccessible::Services::UpdateRecordingAccess.call(
      recording: support_group,
      access_recording: existing,
      role: :view,
      manager_actor: @staff
    )
    assert deny_update.failure?

    deny_revoke = RecordingStudioAccessible::Services::RevokeRecordingAccess.call(
      recording: support_group,
      access_recording: existing,
      manager_actor: @staff
    )
    assert deny_revoke.failure?

    refute RecordingStudioAccessible::AccessManagementPolicy.allowed?(
      recording: empty_group,
      actor: @staff
    )
  end

  test "create_group owner grant still works on a locked mount" do
    lock_support_mount!
    mount = DummyCatalog.support_mount_recording

    group = RecordingStudioMessages.create_group(
      mount,
      title: "Locked desk #{SecureRandom.hex(3)}",
      actor: @staff
    )

    assert RecordingStudioAccessible.authorized?(
      actor: @staff,
      recording: group,
      role: :admin
    )
    assert_includes RecordingStudioMessages.granted_actors(group), @staff
  end

  test "allow_membership_change bypasses the lock for trusted grants" do
    lock_support_mount!
    group = DummyCatalog.empty_group_recording

    result = RecordingStudioMessages.allow_membership_change do
      RecordingStudioAccessible.grant_access(
        recording: group,
        actor: @customer,
        role: :view,
        manager_actor: @staff
      )
    end

    assert result.success?, result.error.to_s
    assert_includes RecordingStudioMessages.granted_actors(group).map(&:email), @customer.email
  end

  test "locked mount panel via show omits plus access" do
    lock_support_mount!
    sign_in @staff

    get recording_studio_messages.message_group_path(DummyCatalog.empty_group_recording)

    assert_response :success
    refute_includes response.body, "+ Access"
  end

  private

  def lock_support_mount!
    RecordingStudio.set_capability_options(
      :messages,
      on: Workspace,
      keys: [:support],
      membership_locked: [:support]
    )
  end

  def restore_workspace_messages_options!
    if @original_options
      RecordingStudio.set_capability_options(:messages, on: Workspace, **@original_options)
    else
      RecordingStudio.set_capability_options(:messages, on: Workspace, keys: [:support])
    end
  end

  def render_panel(group_recording)
    RecordingStudioMessages::MessageGroupsController.render(
      partial: "recording_studio_messages/message_groups/panel",
      locals: {
        group_recording: group_recording,
        message_recordings: RecordingStudioMessages.message_recordings(group_recording),
        current_actor: @staff
      }
    )
  end
end
