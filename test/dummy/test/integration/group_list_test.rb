# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class GroupListTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
  end

  test "staff desk lists conversations the actor can view through Accessible" do
    sign_in @staff
    get staff_desk_path

    assert_response :success
    assert_select "html[data-theme='rounded']", count: 1
    assert_select "body[data-recording-studio-default-layout='true']", count: 1
    assert_select "[data-controller='flat-pack--list-selectable']"
    assert_includes response.body, "Staff desk"
    assert_includes response.body, "Studio help"
    assert_includes response.body, "Launch notes"
    assert_includes response.body, "I will send a quieter line this evening."
    assert_select "a[href=?]", recording_studio_messages.message_group_path(DummyCatalog.support_group_recording)
    assert_select "a[href=?]", recording_studio_messages.message_group_path(DummyCatalog.launch_group_recording)
    refute_includes response.body, "Open conversation"
    refute_includes response.body, recording_studio_messages.message_group_path(DummyCatalog.empty_group_recording)
    refute_includes response.body, "flat-pack--chat-panel"
    refute_includes response.body, "Sign out"
    refute_includes response.body, "Pundit"
    refute_includes response.body, "CanCan"
  end

  test "staff can open a listed conversation into Chat::Panel" do
    sign_in @staff
    get staff_desk_path

    assert_response :success
    get recording_studio_messages.message_group_path(DummyCatalog.support_group_recording)

    assert_response :success
    assert_includes response.body, "flat-pack--chat-panel"
    assert_includes response.body, "The homepage hero feels a bit loud"
    assert_includes response.body, "Studio help"
  end

  test "engine index scopes to a mount and Accessible view grants" do
    sign_in @staff
    mount = DummyCatalog.support_mount_recording
    get recording_studio_messages.message_groups_path(mount_id: mount.id)

    assert_response :success
    assert_includes response.body, "Studio help"
    assert_includes response.body, "Launch notes"
    refute_includes response.body, "Open conversation"
    refute_includes response.body, "Site inbox"
    refute_includes response.body, "Did the press stills land?"
  end

  test "inbox still shows a one-row list for the mailbox mount" do
    sign_in @customer
    get inbox_path

    assert_response :success
    assert_select "[data-controller='flat-pack--list-selectable']"
    assert_includes response.body, "Site inbox"
    assert_includes response.body, "They are in. I attached the first frame."
    assert_select "a[href=?]", recording_studio_messages.message_group_path(DummyCatalog.inbox_group_recording)
    refute_includes response.body, "flat-pack--chat-panel"
    refute_includes response.body, "Studio help"
  end

  test "stranger without a grant does not see conversations on the staff desk" do
    stranger = User.create!(
      email: "list-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Stranger"
    )

    sign_in stranger
    get staff_desk_path

    assert_redirected_to root_path
  end
end
