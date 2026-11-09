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

  test "unranked grants stay off my messages and the index still renders" do
    Current.actor = @staff
    group = RecordingStudioMessages.create_group(
      DummyCatalog.support_mount_recording,
      title: "Download leak",
      actor: @staff
    )
    grant_view!(group, @customer)
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: "Secret preview",
      actor: @staff,
      notify: false
    )
    stamp_role!(group, @customer, "download")
    stamp_last_message_at!(group, 1.day.from_now)

    sign_in @customer
    get recording_studio_messages.my_messages_path

    assert_response :success
    assert_includes response.body, "My messages"
    assert_includes response.body, "Studio help"
    refute_includes response.body, "Download leak"
    refute_includes response.body, "Secret preview"
  end

  test "a foreign after_id is ignored and the first page still renders" do
    Current.actor = @staff
    foreign = RecordingStudioMessages.create_group(
      DummyCatalog.support_mount_recording,
      title: "Staff only cursor",
      actor: @staff
    )
    RecordingStudioMessages.send_message(
      group_recording: foreign,
      body: "Not in Casey inbox",
      actor: @staff,
      notify: false
    )
    root = RecordingStudio.root_recording_for(DummyCatalog.studio_workspace)

    sign_in @customer
    get recording_studio_messages.my_messages_path(after_id: foreign.id)
    assert_response :success
    assert_includes response.body, "Studio help"

    get recording_studio_messages.my_messages_path(after_id: root.id)
    assert_response :success
    assert_includes response.body, "Studio help"
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

  private

  def grant_view!(recording, actor)
    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :view,
      manager_actor: @staff
    )
    raise result.error if result.failure?
  end

  def stamp_role!(recording, actor, role)
    access_recording = RecordingStudioAccessible.access_recordings_for_actor(
      recording: recording,
      actor: actor
    ).first
    RecordingStudio::Access.unscoped.where(id: access_recording.recordable_id).update_all(role: role)
  end

  def stamp_last_message_at!(recording, time)
    RecordingStudioMessages::MessageGroup.unscoped.where(id: recording.recordable_id).update_all(
      last_message_at: time
    )
  end
end
