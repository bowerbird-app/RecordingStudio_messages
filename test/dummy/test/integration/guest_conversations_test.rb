# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class GuestConversationsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @staff = user("Ada Staff")
    @guest = user("Casey Patron")
    @stranger = user("Pat Stranger")
    @workspace = Workspace.create!(name: "Hidden Studio #{SecureRandom.hex(4)}")
    @root = RecordingStudio.create_root_recording!(@workspace, actor: @staff)
    RecordingStudioAccessible.bootstrap_owner_access!(recording: @root, actor: @staff)
    @mount = @root.ensure_message_mount("support", actor: @staff)
    @group = RecordingStudioMessages.create_group(@mount, title: "Print pickup", actor: @staff)
    grant!(@guest)
    Current.actor = @staff
    RecordingStudioMessages.send_message(
      group_recording: @group,
      body: "The print is ready.",
      actor: @staff,
      url: "/staff/message_center"
    )
  end

  teardown do
    Current.actor = nil
  end

  test "a guest opens the conversation from the personal notice and can reply" do
    sign_in @guest
    get personal_notice.url

    assert_response :success
    assert_select "html[data-theme='rounded']", count: 1
    assert_select "link[rel='stylesheet'][href*='flat_pack/application']"
    assert_includes response.body, "Print pickup"
    assert_includes response.body, "The print is ready."
    assert_select "form[action=?]", recording_studio_messages.message_group_messages_path(@group)
    refute_includes response.body, @workspace.name
    refute_includes response.body, "/staff/message_center"
    refute_includes response.body, "Attach a page"
    refute_includes response.body, "dummy-thread-status"

    post recording_studio_messages.message_group_messages_path(@group), params: {
      message: { body: "I can pick it up." },
      return_to: personal_notice.url
    }

    assert_redirected_to personal_notice.url
    follow_redirect!
    assert_response :success
    assert_includes response.body, "I can pick it up."
    refute_includes response.body, @workspace.name
  end

  test "a person who is not in the conversation cannot open it" do
    sign_in @stranger
    get personal_notice.url

    assert_redirected_to "/"
    refute_includes response.body, "The print is ready."
    refute_includes response.body, @workspace.name
  end

  private

  def user(name)
    User.create!(
      email: "#{name.parameterize}-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: name,
      confirmed_at: Time.current
    )
  end

  def grant!(actor)
    result = RecordingStudioAccessible.grant_access(
      recording: @group,
      actor: actor,
      role: :edit,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  end

  def personal_notice
    RecordingStudioNotifications::Notification.find_by!(
      notification_type: "message_received_personal",
      recipient: @guest
    )
  end
end
