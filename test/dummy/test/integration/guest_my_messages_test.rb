# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class GuestMyMessagesTest < ActionDispatch::IntegrationTest
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

  test "a guest opens the personal notice in my messages without host chrome" do
    sign_in @guest
    batch_calls, root_checks = count_root_lookups { get personal_notice.url }

    assert_response :success
    assert_equal 1, batch_calls
    assert_equal 0, root_checks
    assert_select "html[data-theme='rounded']", count: 1
    assert_select "link[rel='stylesheet'][href*='flat_pack/application']"
    assert_includes response.body, "My messages"
    assert_includes response.body, "Print pickup"
    assert_includes response.body, "The print is ready."
    assert_includes response.body, @workspace.name
    assert_select "form[action=?]", recording_studio_messages.message_group_messages_path(@group)
    assert_select ".flat-pack-page-nav", count: 0
    refute_includes response.body, "/staff/message_center"
    refute_includes response.body, "Attach a page"
    refute_includes response.body, "dummy-thread-status"
    refute_includes response.body, "Manage access"
    refute_includes response.body, "+ Access"
    refute_includes response.body, recording_studio_messages.message_groups_path(mount_id: @mount.id)

    post recording_studio_messages.message_group_messages_path(@group), params: {
      message: { body: "I can pick it up." },
      return_to: personal_notice.url
    }

    assert_redirected_to personal_notice.url
    follow_redirect!
    assert_response :success
    assert_includes response.body, "I can pick it up."
    assert_includes response.body, @workspace.name
    assert_select ".flat-pack-page-nav", count: 0
    refute_includes response.body, "Attach a page"
  end

  test "a member who can view the workspace keeps my messages chrome" do
    sign_in @staff
    get recording_studio_messages.my_message_path(@group)

    assert_response :success
    assert_select ".flat-pack-page-nav"
    assert_select "a[href=?]", recording_studio_messages.my_messages_path
    assert_includes response.body, @workspace.name
    assert_includes response.body, "Print pickup"
    assert_includes response.body, "dummy-thread-status"
    assert_includes response.body, "Attach a page"
    assert_includes response.body, "Manage access"
  end

  test "a person who is not in the conversation cannot open it" do
    sign_in @stranger
    get recording_studio_messages.my_message_path(@group)

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

  def count_root_lookups
    batch_calls = 0
    root_checks = 0
    original_ids = RecordingStudioAccessible.method(:authorized_root_recording_ids)
    original_authorized = RecordingStudioAccessible.method(:authorized?)
    RecordingStudioAccessible.stub(:authorized_root_recording_ids, lambda { |**kwargs|
      batch_calls += 1
      original_ids.call(**kwargs)
    }) do
      RecordingStudioAccessible.stub(:authorized?, lambda { |**kwargs|
        root_checks += 1 if kwargs[:recording] == @root
        original_authorized.call(**kwargs)
      }) do
        yield
      end
    end
    [batch_calls, root_checks]
  end
end
