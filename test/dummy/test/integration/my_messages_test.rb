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

  test "index auto-select does not mark the first conversation read" do
    Current.actor = @staff
    first = seeded_unread_conversation("First unread")
    stamp_last_message_at!(first, 2.minutes.from_now)
    second = seeded_unread_conversation("Second unread")
    stamp_last_message_at!(second, 3.minutes.from_now)

    sign_in @customer
    get recording_studio_messages.my_messages_path

    assert_response :success
    refute_includes response.body, ">All<"
    refute_includes response.body, ">Unread<"
    refute_select ".fp-tabular-nums", text: "1"
    assert RecordingStudioMessages.unread?(group_recording: first, actor: @customer)
    assert RecordingStudioMessages.unread?(group_recording: second, actor: @customer)
    assert_select "a[href=?][aria-label=?][title=?]",
                  recording_studio_messages.my_messages_path(unread: 1),
                  "Show unread only",
                  "Show unread only"
    assert_select "[data-unread=true]", minimum: 2
    refute_select "a[aria-current=page][aria-label=?]", "Show unread only"
  end

  test "explicit show marks read and clears that conversation's notices" do
    Current.actor = @staff
    kept = seeded_unread_conversation("Keep notice", notify: true)
    opened = seeded_unread_conversation("Open notice", notify: true)

    sign_in @customer
    get recording_studio_messages.my_message_path(opened)

    assert_response :success
    refute RecordingStudioMessages.unread?(group_recording: opened, actor: @customer)
    assert RecordingStudioMessages.unread?(group_recording: kept, actor: @customer)
    assert_not_nil notice_for(opened).read_at
    assert_nil notice_for(kept).read_at
  end

  test "unread filter lists only unread conversations" do
    Current.actor = @staff
    unread = seeded_unread_conversation("Still unread")
    read = seeded_unread_conversation("Already opened")
    RecordingStudioMessages.mark_read(group_recording: read, actor: @customer)

    sign_in @customer
    get recording_studio_messages.my_messages_path(unread: 1)

    assert_response :success
    assert_includes response.body, "Still unread"
    refute_includes response.body, "Already opened"
    assert_select "a[href=?]", recording_studio_messages.my_message_path(unread)
    assert_select "a[href=?][aria-label=?][title=?][aria-current=page]",
                  recording_studio_messages.my_messages_path,
                  "Show all",
                  "Show all"
    assert_select "[data-unread=true]", minimum: 1
    refute_select ".fp-tabular-nums", text: "1"
  end

  test "unread filter toggle drops after_id and keeps other query params" do
    sign_in @customer
    get recording_studio_messages.my_messages_path(
      after_id: DummyCatalog.support_group_recording.id,
      foo: "1"
    )

    assert_response :success
    assert_select "a[aria-label=?][href*='unread=1']", "Show unread only"
    assert_select "a[aria-label=?][href*='foo=1']", "Show unread only"
    refute_select "a[aria-label=?][href*='after_id']", "Show unread only"
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

  def seeded_unread_conversation(title, notify: false)
    group = RecordingStudioMessages.create_group(
      DummyCatalog.support_mount_recording,
      title: title,
      actor: @staff
    )
    grant_view!(group, @customer)
    RecordingStudioMessages.send_message(
      group_recording: group,
      body: "#{title} body",
      actor: @staff,
      notify: notify,
      url: "/my_messages"
    )
    group
  end

  def notice_for(group)
    RecordingStudioNotifications::Notification.where(
      notification_type: "message_received",
      recipient: @customer
    ).find { |note| note.metadata["message_group_id"] == group.id }
  end

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
