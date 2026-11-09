# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class MyMessagesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    load Rails.root.join("db/seeds.rb").to_s
    @staff = User.find_by!(email: "admin@admin.com")
    @customer = User.find_by!(email: "casey@example.com")
  end

  test "my messages lists direct grants across mounts with the desk name on each row" do
    sign_in @customer
    get recording_studio_messages.my_messages_path

    assert_response :success
    assert_select "[data-controller='flat-pack--chat-layout']"
    assert_includes response.body, "My messages"
    assert_includes response.body, "Studio help"
    assert_includes response.body, "Launch notes"
    assert_includes response.body, "Site inbox"
    assert_includes response.body, DummyCatalog.studio_workspace.name
    assert_includes response.body, DummyCatalog.mailbox.name
    assert_select "a[href=?][data-turbo-frame=?]",
                  recording_studio_messages.my_message_path(DummyCatalog.support_group_recording),
                  "messages-desk-panel"
    assert_select "a[href=?][data-turbo-frame=?]",
                  recording_studio_messages.my_message_path(DummyCatalog.inbox_group_recording),
                  "messages-desk-panel"
    refute_includes response.body, recording_studio_messages.message_group_path(DummyCatalog.empty_group_recording)
  end

  test "opening a conversation from my messages keeps the my messages sidebar and back link" do
    sign_in @customer
    group = DummyCatalog.inbox_group_recording
    get recording_studio_messages.my_message_path(group)

    assert_response :success
    assert_includes response.body, "My messages"
    assert_includes response.body, "Studio help"
    assert_includes response.body, "Site inbox"
    assert_includes response.body, "Did the press stills land?"
    assert_select "a[href=?]", recording_studio_messages.my_messages_path
    refute_includes response.body, recording_studio_messages.message_groups_path(
      mount_id: DummyCatalog.inbox_mount_recording.id
    )
  end

  test "a turbo frame open from my messages still authorizes the conversation" do
    sign_in @customer
    group = DummyCatalog.support_group_recording

    get recording_studio_messages.my_message_path(group),
        headers: { "Turbo-Frame" => "messages-desk-panel" }

    assert_response :success
    assert_select "turbo-frame#messages-desk-panel"
    assert_includes response.body, "The homepage hero feels a bit loud"
    refute_includes response.body, "flat-pack--chat-layout"
  end

  test "staff desk list is unchanged and still uses mount routes" do
    sign_in @staff
    get staff_desk_path

    assert_response :success
    assert_includes response.body, "Studio help"
    assert_includes response.body, "Launch notes"
    refute_includes response.body, "Site inbox"
    assert_select "a[href=?][data-turbo-frame=?]",
                  recording_studio_messages.message_group_path(DummyCatalog.support_group_recording),
                  "messages-desk-panel"
  end

  test "stranger cannot open a conversation from my messages" do
    stranger = User.create!(
      email: "my-stranger-#{SecureRandom.hex(4)}@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      name: "Pat Stranger",
      confirmed_at: Time.current
    )

    sign_in stranger
    get recording_studio_messages.my_message_path(DummyCatalog.support_group_recording)

    assert_redirected_to "/"
  end
end
